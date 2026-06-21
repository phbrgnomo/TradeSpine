//+------------------------------------------------------------------+
//|                                                  StateStore.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Persistence/StateStore.mqh                        |
//| @spec: SPEC-05  @tdd: TDD.05.04.e64a  @iplan: IPLAN-05           |
//|                                                                  |
//| Defines the shared persistence type models (enums and structs)  |
//| mandated by SPEC-05, the IStateStore pure interface (deferred    |
//| from IPLAN-09 per Include/Core/Interfaces.mqh:18), and the GV-  |
//| backed CStateStore implementation.                               |
//|                                                                  |
//| Key constraints honored:                                         |
//|   - Only scalar double-compatible values stored in GVs.          |
//|   - Lossless ulong identifiers split into two 32-bit GV slots.  |
//|   - String payloads (HaltEvidence) written to files, not GVs.   |
//|   - Raw identity never stored; fingerprint = lower 53 bits of   |
//|     FNV-1a hash of "<account>|<symbol>|<magic>" (exact double). |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_PERSISTENCE_STATESTORE_MQH
#define TRADESPINE_PERSISTENCE_STATESTORE_MQH

#include "KeyBuilder.mqh"
#include "PersistenceTypes.mqh"

//+------------------------------------------------------------------+
//| Shared persistence type models (SPEC-05 data model section).     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| \brief ENUM_POSITION_STATE - v1 position lifecycle states.       |
//|        Defined here (IPLAN-05) and extended by IPLAN-04 with     |
//|        PENDING_ENTRY. Existing numeric values 0-4 are stable.   |
//+------------------------------------------------------------------+
enum ENUM_POSITION_STATE
  {
   POSITION_STATE_UNKNOWN       = 0, //!< State not yet determined.
   POSITION_STATE_IDLE          = 1, //!< No active position; waiting for signal (FLAT).
   POSITION_STATE_ACTIVE        = 2, //!< Position open and managed.
   POSITION_STATE_PENDING_EXIT  = 3, //!< Exit order submitted; awaiting fill.
   POSITION_STATE_HALT          = 4, //!< HALT: operator action required.
   POSITION_STATE_PENDING_ENTRY = 5  //!< Entry order submitted; awaiting fill. (@iplan: IPLAN-04)
  };

//+------------------------------------------------------------------+
//| \brief ENUM_GV_VALUE_ENCODING - documents how a scalar double    |
//|        stored in a terminal Global Variable should be decoded.   |
//+------------------------------------------------------------------+
enum ENUM_GV_VALUE_ENCODING
  {
   GV_ENC_FLAG        = 0, //!< Boolean: 0.0 = false, 1.0 = true.
   GV_ENC_TIMESTAMP   = 1, //!< datetime cast to double (exact for values < 2^53).
   GV_ENC_VOLUME      = 2, //!< Lot volume (≤ 2^53 safe range).
   GV_ENC_HASH_FRAG   = 3, //!< Lower 53 bits of FNV-1a hash (identity fingerprint).
   GV_ENC_SPLIT_ID_HI = 4, //!< Upper 32 bits of a ulong ticket/deal/order ID.
   GV_ENC_SPLIT_ID_LO = 5  //!< Lower 32 bits of a ulong ticket/deal/order ID.
  };

//+------------------------------------------------------------------+
//| \brief HaltEvidence - structured payload written to the halt     |
//|        evidence file when CStateStore::SetHalt() is called.     |
//|        The corresponding GV holds only a 1.0 flag.              |
//+------------------------------------------------------------------+
struct HaltEvidence
  {
   string              reason;           //!< Human-readable HALT reason.
   ENUM_POSITION_STATE last_known_state; //!< Preserved lifecycle state at HALT time.
   string              operator_action;  //!< Recovery instruction shown to operator.
  };

//+------------------------------------------------------------------+
//| \brief GlobalVariableScalarState - one GV slot evidence record.  |
//+------------------------------------------------------------------+
struct GlobalVariableScalarState
  {
   string                 key;      //!< Deterministic hashed terminal GV key (≤63 chars).
   double                 value;    //!< Scalar value stored in the terminal GV.
   ENUM_GV_VALUE_ENCODING encoding; //!< Decoding hint for the value field.
  };

//+------------------------------------------------------------------+
//| \brief IStateStore - pure persistence seam (SPEC-05).            |
//|        Concrete implementation: CStateStore (GV-backed).         |
//|        All methods return false on error; callers decide policy. |
//+------------------------------------------------------------------+
interface IStateStore
  {
   //--- \brief Write a scalar double under the named scope slot.
   bool WriteScalar(string scope, double value);

   //--- \brief Read back the scalar stored under the named scope slot.
   //--- \param value  [out] Stored value (unchanged if key absent).
   //--- \return false if the GV does not exist or a build error occurred.
   bool ReadScalar(string scope, double &value);

   //--- \brief Mark an order intent as already-seen (duplicate guard).
   //--- \param intent_id_hash  Short string hash of the intent identifier.
   bool SetDuplicate(string intent_id_hash);

   //--- \brief Check whether an intent has already been processed.
   bool IsDuplicate(string intent_id_hash);

   //--- \brief Set the HALT flag GV and write HaltEvidence to a file.
   //---        Returns false if the GV write or any file write step fails.
   //---        The HALT flag GV remains set even on file failure.
   bool SetHalt(const HaltEvidence &ev);

   //--- \brief Check whether the HALT flag GV is set.
   bool IsHalted();

   //--- \brief Store a ulong ticket losslessly as two 32-bit GV slots.
   bool WriteTicket(ulong ticket);

   //--- \brief Reassemble the ulong ticket from two 32-bit GV slots.
   bool ReadTicket(ulong &ticket);

   //--- \brief Verify the stored identity fingerprint matches the init identity.
   //--- \return false on fingerprint mismatch (StateCorruption).
   bool Verify();
  };

//+------------------------------------------------------------------+
//| \brief CStateStore - GV-backed implementation of IStateStore.    |
//|        Call Init() once before any other method. All GV keys are |
//|        built via the injected CKeyBuilder; raw identity fields   |
//|        never appear in GV names or values.                       |
//|                                                                  |
//| \note  Account-symbol-magic duplicate *ownership* detection —   |
//|        heartbeat GV via GlobalVariableSetOnCondition(), stale   |
//|        recovery, and owner diagnostics (PRD AC-39/AC-42) — is  |
//|        IPLAN-04 scope. CStateStore provides the primitive GV    |
//|        write infrastructure that IPLAN-04 will consume; it does |
//|        not implement the ownership protocol itself.             |
//+------------------------------------------------------------------+
class CStateStore : public IStateStore
  {
  private:
   CKeyBuilder*       m_kb;
   CanonicalIdentity  m_id;
   bool               m_initialized;

   //--- Builds a GV key by overwriting the scope field of m_id.
   bool               _key(string scope, string &key);

   //--- \brief Wraps GlobalVariableSet with error logging.
   //--- \param key    Terminal GV key.
   //--- \param value  Scalar double to store.
   //--- \return true if GlobalVariableSet succeeded (non-zero); false on failure.
   bool               _setGV(string key, double value);

   //--- Replaces filesystem-special characters (/\:*?"<>|\n\r) with '_' in a filename component.
   static string      _SanitizePath(const string s);

   //--- Replaces \n and \r with a space in a HALT evidence payload value to prevent line injection.
   static string      _StripNewlines(const string s);

  public:
                      CStateStore(void) : m_kb(NULL), m_initialized(false) {}

   //--- \brief Initialize the store with the strategy identity and key builder.
   //---        Writes an identity fingerprint GV on first call; verifies it on
   //---        subsequent calls. Creates the TradeSpine files folder.
   //--- \param id  Canonical identity (scope field is overwritten internally).
   //--- \param kb  Non-null key builder (caller owns lifetime).
   //--- \return false if fingerprint mismatch (StateCorruption) or build error.
   bool               Init(const CanonicalIdentity &id, CKeyBuilder* kb);

   // IStateStore implementation
   bool               WriteScalar(string scope, double value) override;
   bool               ReadScalar(string scope, double &value) override;
   bool               SetDuplicate(string intent_id_hash) override;
   bool               IsDuplicate(string intent_id_hash) override;
   bool               SetHalt(const HaltEvidence &ev) override;
   bool               IsHalted() override;
   bool               WriteTicket(ulong ticket) override;
   bool               ReadTicket(ulong &ticket) override;
   bool               Verify() override;
  };

//+------------------------------------------------------------------+
bool CStateStore::_key(string scope, string &key)
  {
   CanonicalIdentity id = m_id;
   id.scope = scope;
   return(m_kb.Build(id, key));
  }

//+------------------------------------------------------------------+
bool CStateStore::_setGV(string key, double value)
  {
   ResetLastError();
   if(GlobalVariableSet(key, value) != 0)
      return(true);

   PrintFormat("CStateStore::_setGV failed: key='%s' value=%.17g error=%d",
              key, value, GetLastError());
   return(false);
  }

//+------------------------------------------------------------------+
bool CStateStore::Init(const CanonicalIdentity &id, CKeyBuilder* kb)
  {
   if(kb == NULL)
      return(false);
   m_kb          = kb;
   m_id          = id;
   m_initialized = false;

//--- Ensure the TradeSpine files folder exists for halt evidence.
   FolderCreate("TradeSpine");

//--- Build fingerprint GV key (scope="fp").
   string fp_key;
   if(!_key("fp", fp_key))
      return(false);

   double computed = m_kb.Fingerprint(m_id);

   if(GlobalVariableCheck(fp_key))
     {
      //--- GV exists from a prior session: verify identity matches.
      double stored = GlobalVariableGet(fp_key);
      if(stored != computed)
         return(false); // StateCorruption: fingerprint mismatch
     }
   else
     {
      //--- First initialisation: write fingerprint.
      if(!_setGV(fp_key, computed))
         return(false);
     }

   m_initialized = true;
   return(true);
  }

//+------------------------------------------------------------------+
bool CStateStore::WriteScalar(string scope, double value)
  {
   if(!m_initialized) return(false);
   string key;
   if(!_key(scope, key)) return(false);
   return(_setGV(key, value));
  }

//+------------------------------------------------------------------+
bool CStateStore::ReadScalar(string scope, double &value)
  {
   if(!m_initialized) return(false);
   string key;
   if(!_key(scope, key)) return(false);
   if(!GlobalVariableCheck(key)) return(false);
   value = GlobalVariableGet(key);
   return(true);
  }

//+------------------------------------------------------------------+
bool CStateStore::SetDuplicate(string intent_id_hash)
  {
   if(!m_initialized) return(false);
   string key;
   if(!_key("dup_" + intent_id_hash, key)) return(false);
   return(_setGV(key, 1.0));
  }

//+------------------------------------------------------------------+
bool CStateStore::IsDuplicate(string intent_id_hash)
  {
   if(!m_initialized) return(false);
   string key;
   if(!_key("dup_" + intent_id_hash, key)) return(false);
   return(GlobalVariableCheck(key));
  }

//+------------------------------------------------------------------+
bool CStateStore::SetHalt(const HaltEvidence &ev)
  {
   if(!m_initialized) return(false);

//--- 1. Set the HALT flag GV (the critical safety signal).
   string flag_key;
   if(!_key("halt_flag", flag_key)) return(false);
   if(!_setGV(flag_key, 1.0)) return(false);

//--- 2. Write the string payload to a file (GVs store scalars only).
//---    File write is mandatory: HALT flag is already set above, so the
//---    EA is safe, but incomplete evidence would leave the operator without
//---    a recovery action. Return false if any write step fails.
   string fname = "TradeSpine/Halt_" + StringFormat("%I64u", m_id.magic)
                + "_" + _SanitizePath(m_id.symbol) + ".txt";
   int fh = FileOpen(fname, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(fh == INVALID_HANDLE)
      return(false);

   bool ok = true;
   ok &= (FileWriteString(fh, "reason=" + _StripNewlines(ev.reason) + "\n") > 0);
   ok &= (FileWriteString(fh, "last_known_state=" + IntegerToString(ev.last_known_state) + "\n") > 0);
   ok &= (FileWriteString(fh, "operator_action=" + _StripNewlines(ev.operator_action) + "\n") > 0);
   FileFlush(fh);
   FileClose(fh);
   return(ok);
  }

//+------------------------------------------------------------------+
bool CStateStore::IsHalted()
  {
   if(!m_initialized) return(false);
   string key;
   if(!_key("halt_flag", key)) return(false);
   return(GlobalVariableCheck(key) && GlobalVariableGet(key) >= 0.5);
  }

//+------------------------------------------------------------------+
bool CStateStore::WriteTicket(ulong ticket)
  {
   if(!m_initialized) return(false);
   string key_hi, key_lo;
   if(!_key("tkt_hi", key_hi)) return(false);
   if(!_key("tkt_lo", key_lo)) return(false);
//--- Split into two 32-bit halves; both are ≤ 2^32-1 < 2^53 (exact in double).
   double hi = (double)(long)(ticket >> 32);
   double lo = (double)(long)(ticket & (ulong)0xFFFFFFFF);
   if(!_setGV(key_hi, hi))
     {
      GlobalVariableDel(key_hi);
      GlobalVariableDel(key_lo);
      return(false);
     }
   if(!_setGV(key_lo, lo))
     {
      GlobalVariableDel(key_hi);
      GlobalVariableDel(key_lo);
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
bool CStateStore::ReadTicket(ulong &ticket)
  {
   if(!m_initialized) return(false);
   string key_hi, key_lo;
   if(!_key("tkt_hi", key_hi)) return(false);
   if(!_key("tkt_lo", key_lo)) return(false);
   if(!GlobalVariableCheck(key_hi) || !GlobalVariableCheck(key_lo)) return(false);
   ulong hi = (ulong)(long)GlobalVariableGet(key_hi);
   ulong lo = (ulong)(long)GlobalVariableGet(key_lo);
   ticket = (hi << 32) | lo;
   return(true);
  }

//+------------------------------------------------------------------+
bool CStateStore::Verify()
  {
   if(!m_initialized || m_kb == NULL) return(false);
   string fp_key;
   if(!_key("fp", fp_key)) return(false);
   if(!GlobalVariableCheck(fp_key)) return(false);
   double stored   = GlobalVariableGet(fp_key);
   double expected = m_kb.Fingerprint(m_id);
   return(stored == expected);
  }

//+------------------------------------------------------------------+
static string CStateStore::_SanitizePath(const string s)
  {
   string r = s;
   StringReplace(r, "/",  "_");
   StringReplace(r, "\\", "_");
   StringReplace(r, ":",  "_");
   StringReplace(r, "*",  "_");
   StringReplace(r, "?",  "_");
   StringReplace(r, "\"", "_");
   StringReplace(r, "<",  "_");
   StringReplace(r, ">",  "_");
   StringReplace(r, "|",  "_");
   StringReplace(r, "\n", "_");
   StringReplace(r, "\r", "_");
   return(r);
  }

//+------------------------------------------------------------------+
static string CStateStore::_StripNewlines(const string s)
  {
   string r = s;
   StringReplace(r, "\n", " ");
   StringReplace(r, "\r", " ");
   return(r);
  }

#endif // TRADESPINE_PERSISTENCE_STATESTORE_MQH
//+------------------------------------------------------------------+
