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
#include "MarkerLease.mqh"
#include "PersistenceTypes.mqh"

//+------------------------------------------------------------------+
//| Shared persistence type models (SPEC-05 data model section).     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| \brief ENUM_POSITION_STATE - v1 position lifecycle states.       |
//|        Values 0-4 (UNKNOWN..HALT) defined by IPLAN-05.          |
//|        PENDING_ENTRY=5 and PENDING_CANCEL=6 are added by        |
//|        IPLAN-04; all existing values remain stable.             |
//+------------------------------------------------------------------+
enum ENUM_POSITION_STATE
  {
   POSITION_STATE_UNKNOWN       = 0, //!< State not yet determined.
   POSITION_STATE_IDLE          = 1, //!< No active position; waiting for signal (FLAT).
   POSITION_STATE_ACTIVE        = 2, //!< Position open and managed.
   POSITION_STATE_PENDING_EXIT  = 3, //!< Exit order submitted; awaiting fill.
   POSITION_STATE_HALT           = 4, //!< HALT: operator action required.
   POSITION_STATE_PENDING_ENTRY  = 5, //!< Entry order submitted; awaiting fill. @iplan: IPLAN-04
   POSITION_STATE_PENDING_CANCEL = 6  //!< Cancel submitted; awaiting confirmation. @iplan: IPLAN-04
  };

//+------------------------------------------------------------------+
//| \brief ENUM_STORE_READ_RESULT - distinguishes absence, valid     |
//|        committed state, corruption, and storage failure.         |
//+------------------------------------------------------------------+
enum ENUM_STORE_READ_RESULT
  {
   STORE_READ_ABSENT  = 0, //!< No committed lifecycle snapshot exists.
   STORE_READ_VALID   = 1, //!< Snapshot generation and checksum are valid.
   STORE_READ_CORRUPT = 2, //!< Snapshot exists but is internally contradictory.
   STORE_READ_ERROR   = 3  //!< Storage/key access failed.
  };

//+------------------------------------------------------------------+
//| \brief ENUM_CANCEL_ORIGIN - identifies the owner of cancellation |
//|        evidence retained across restart and ambiguous outcomes.  |
//+------------------------------------------------------------------+
enum ENUM_CANCEL_ORIGIN
  {
   CANCEL_ORIGIN_NONE              = 0, //!< No cancellation requested.
   CANCEL_ORIGIN_FRAMEWORK_TIMEOUT = 1, //!< Framework fill timeout requested cancellation.
   CANCEL_ORIGIN_DAY_TRADE         = 2  //!< Day-trade close policy requested cancellation.
  };

//+------------------------------------------------------------------+
//| \brief PendingOrderEvidence - durable pending/cancel evidence.   |
//+------------------------------------------------------------------+
struct PendingOrderEvidence
  {
   ulong              ticket;              //!< Broker order ticket.
   datetime           submitted_ts;        //!< Original order submission timestamp.
   datetime           cancel_requested_ts; //!< Zero until a cancel request is accepted.
   ENUM_CANCEL_ORIGIN cancel_origin;       //!< Cancellation owner/reason.
  };

//+------------------------------------------------------------------+
//| \brief LifecycleSnapshot - one logically committed lifecycle     |
//|        aggregate. It is published by generation after checksum.  |
//|                                                                  |
//| Invariants: committed snapshots never contain UNKNOWN; IDLE has  |
//| no broker evidence; ACTIVE/PENDING_EXIT have one complete        |
//| position identity; PENDING_ENTRY/PENDING_CANCEL have one complete|
//| order record; HALT retains at most one of those complete shapes. |
//| Generation zero is only an uncommitted caller/legacy sentinel.   |
//|                                                                  |
//| Commit protocol: write the inactive slot payload and checksum,   |
//| read it back and validate it, then publish life_commit last. A   |
//| failed replacement therefore leaves the prior generation valid. |
//+------------------------------------------------------------------+
struct LifecycleSnapshot
  {
   ENUM_POSITION_STATE state;           //!< Lifecycle state.
   ulong               position_ticket; //!< Owned broker position ticket, or zero.
   ulong               position_identifier; //!< Stable POSITION_IDENTIFIER for history recovery.
   PendingOrderEvidence pending;         //!< Pending/cancel evidence, or zero ticket.
   bool                 halted;          //!< Persistent circuit-breaker state.
   long                 generation;      //!< Positive committed generation.
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
   string              symbol;           //!< Optional HALT symbol; empty when caller lacks context.
   ulong               magic;            //!< Optional strategy magic; 0 when caller lacks context.
   ulong               ticket;           //!< Optional position/order ticket; 0 when none is known.
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
   //--- \brief Commit a complete lifecycle aggregate using commit-last semantics.
   //--- \param snapshot Aggregate to publish; generation is assigned by the store.
   //--- \return true only after read-back verification and commit publication.
   bool WriteLifecycleSnapshot(const LifecycleSnapshot &snapshot);

   //--- \brief Read and validate the currently committed lifecycle aggregate.
   //--- \param snapshot [out] Valid aggregate when STORE_READ_VALID is returned.
   //--- \return Detailed absence/corruption/error result.
   ENUM_STORE_READ_RESULT ReadLifecycleSnapshot(LifecycleSnapshot &snapshot);

   //--- \brief Report whether this store uses a non-live runtime namespace.
   //--- \return true when a runtime namespace prefixes every generated key.
   bool IsRuntimeIsolated();

   //--- \brief Write a scalar double under the named scope slot.
   //--- \param scope Logical state scope.
   //--- \param value Scalar value to store.
   //--- \return true when the GV write succeeds.
   bool WriteScalar(string scope, double value);

   //--- \brief Read back the scalar stored under the named scope slot.
   //--- \param value  [out] Stored value (unchanged if key absent).
   //--- \return false if the GV does not exist or a build error occurred.
   bool ReadScalar(string scope, double &value);

   //--- \brief Mark an order intent as already-seen (duplicate guard).
   //--- \param intent_id_hash  Short string hash of the intent identifier.
   bool SetDuplicate(string intent_id_hash);

   //--- \brief Check whether an intent has already been processed.
   //--- \param intent_id_hash Short string hash of the intent identifier.
   //--- \return true when the duplicate marker exists.
   bool IsDuplicate(string intent_id_hash);

   //--- \brief Set the HALT flag GV and write HaltEvidence to a file.
   //---        Returns false if the GV write or any file write step fails.
   //---        The HALT flag GV remains set even on file failure.
   bool SetHalt(const HaltEvidence &ev);

   //--- \brief Append HALT evidence without changing lifecycle or HALT flags.
   //---        Used when a stale lease owner must fail closed locally without
   //---        mutating the current owner's shared lifecycle state.
   //--- \param ev HALT evidence record to append to the durable audit file.
   //--- \return true when every audit line is written.
   bool AppendHaltEvidence(const HaltEvidence &ev);

   //--- \brief Check whether the HALT flag GV is set.
   //--- \return true when the current identity is halted.
   bool IsHalted();

   //--- \brief Append recovery evidence and clear the HALT flag last.
   //--- \return true only when the audit append and flag clear succeed.
   bool ClearHalt();

   //--- \brief Store a ulong ticket losslessly as two 32-bit GV slots.
   //--- \param ticket Broker ticket/deal/order identifier.
   //--- \return true when both split GV writes succeed.
   bool WriteTicket(ulong ticket);

   //--- \brief Reassemble the ulong ticket from two 32-bit GV slots.
   //--- \param ticket [out] Reassembled ticket value.
   //--- \return true when both split GV slots exist and decode.
   bool ReadTicket(ulong &ticket);

   //--- \brief Store a pending-entry order ticket and submission timestamp.
   //--- \param ticket Pending-entry order ticket.
   //--- \param submitted_ts Submission timestamp.
   //--- \return true when ticket and timestamp persist.
   bool WritePendingOrder(ulong ticket, datetime submitted_ts);

   //--- \brief Read the persisted pending-entry order ticket and submission timestamp.
   //--- \param ticket [out] Pending-entry order ticket.
   //--- \param submitted_ts [out] Submission timestamp.
   //--- \return true when pending order evidence exists and decodes.
   bool ReadPendingOrder(ulong &ticket, datetime &submitted_ts);

   //--- \brief Clear persisted pending-entry order evidence.
   //--- \return true when the store is initialized and cleanup was attempted.
   bool ClearPendingOrder();

   //--- \brief Claim or reclaim the duplicate marker lease using a token-fenced owner GV.
   //--- \param now Current timestamp.
   //--- \param lease_secs Stale-owner threshold in seconds.
   //--- \param out_token [out] Positive owner token on successful claim/reclaim.
   //--- \param status [out] Claim result classification.
   //--- \return true when the claim attempt was handled; status reports conflict/reclaim/active.
   bool MarkerClaimOrReclaim(datetime now,
                             int lease_secs,
                             long &out_token,
                             ENUM_DUPLICATE_MARKER_STATUS &status);

   //--- \brief Refresh the marker lease only if \p token is the current owner token.
   //--- \param token [in,out] Current owner token; advanced on success.
   //--- \param now Current timestamp.
   //--- \return true when owner token advances and heartbeat timestamp is written.
   bool MarkerHeartbeat(long &token, datetime now);

   //--- \brief Verify that token is still the published positive owner.
   //--- \param token Expected owner token.
   //--- \return true only when the owner GV exactly matches token.
   bool MarkerIsOwner(long token);

   //--- \brief Release the marker lease only if \p token is the current owner token.
   //--- \param token Current owner token.
   //--- \return true when owner GV is changed to -token.
   bool MarkerRelease(long token);

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
//| \note  Account-symbol-magic duplicate *ownership* detection is  |
//|        implemented here as an IPLAN-04 additive contract using  |
//|        a token-fenced owner GV plus explicit heartbeat GV.       |
//+------------------------------------------------------------------+
class CStateStore : public IStateStore
  {
  private:
   CKeyBuilder*       m_kb;
   CanonicalIdentity  m_id;
   string             m_runtime_namespace;
   bool               m_initialized;
   CTerminalMarkerBackend m_terminal_marker_backend;
   CMarkerLease       m_marker_lease;

   //--- \brief Build a GV key by overwriting the scope field of m_id.
   //--- \param scope Logical state scope.
   //--- \param key [out] Terminal GV key.
   //--- \return true when CKeyBuilder builds a valid key.
   bool               _key(string scope, string &key);

   //--- \brief Wraps GlobalVariableSet with error logging.
   //--- \param key    Terminal GV key.
   //--- \param value  Scalar double to store.
   //--- \return true if GlobalVariableSet succeeded (non-zero); false on failure.
   bool               _setGV(string key, double value);

   //--- \brief Store and read lossless ulong values under prefixed hi/lo scopes.
   //--- \param scope_hi Logical scope for upper 32 bits.
   //--- \param scope_lo Logical scope for lower 32 bits.
   //--- \param value Ulong identifier to persist.
   //--- \return true when both GV writes succeed.
   bool               _WriteSplitId(string scope_hi, string scope_lo, ulong value);
   //--- \brief Read a lossless ulong value from prefixed hi/lo scopes.
   //--- \param scope_hi Logical scope for upper 32 bits.
   //--- \param scope_lo Logical scope for lower 32 bits.
   //--- \param value [out] Reassembled ulong identifier.
   //--- \return true when both GV slots exist and decode.
   bool               _ReadSplitId(string scope_hi, string scope_lo, ulong &value);

   //--- \brief Compute a deterministic exact-double-safe snapshot checksum.
   double             _SnapshotChecksum(const LifecycleSnapshot &snapshot);
   //--- \brief Validate lifecycle invariants before publication and after readback.
   bool               _SnapshotIsConsistent(const LifecycleSnapshot &snapshot);
   //--- \brief Write one inactive snapshot slot without publishing it.
   bool               _WriteSnapshotSlot(int slot, const LifecycleSnapshot &snapshot);
   //--- \brief Read and validate one snapshot slot.
   ENUM_STORE_READ_RESULT _ReadSnapshotSlot(int slot, long generation, LifecycleSnapshot &snapshot);

   //--- \brief Build the exclusive first-use marker bootstrap mutex filename.
   string             _MarkerLockFileName(void);

   //--- \brief Build the HALT evidence filename for the current identity.
   //--- \return File-relative HALT evidence path.
   string             _HaltFileName(void);

   //--- \brief Append the common seven-line HALT audit record.
   bool               _AppendHaltEvidence(const HaltEvidence &ev);

   //--- Replaces filesystem-special characters (/\:*?"<>|\n\r) with '_' in a filename component.
   //--- \param s Raw filename component.
   //--- \return Sanitized filename component.
   static string      _SanitizePath(const string s);

   //--- Replaces \n and \r with a space in a HALT evidence payload value to prevent line injection.
   //--- \param s Raw payload value.
   //--- \return Single-line payload value.
   static string      _StripNewlines(const string s);

  public:
                      CStateStore(void) : m_kb(NULL), m_runtime_namespace(""), m_initialized(false) {}

   //--- \brief Initialize the store with the strategy identity and key builder.
   //---        Writes an identity fingerprint GV on first call; verifies it on
   //---        subsequent calls. Creates the TradeSpine files folder.
   //--- \param id  Canonical identity (scope field is overwritten internally).
   //--- \param kb  Non-null key builder (caller owns lifetime).
   //--- \return false if fingerprint mismatch (StateCorruption) or build error.
   //--- \param runtime_namespace Optional isolated tester/pass namespace; live uses empty.
   bool               Init(const CanonicalIdentity &id,
                           CKeyBuilder* kb,
                           string runtime_namespace = "",
                           IMarkerBackend* marker_backend = NULL);

   //--- \brief Publish a checked double-buffered lifecycle snapshot.
   //--- \param snapshot Aggregate to publish; generation is assigned by the store.
   //--- \return true only after read-back verification and commit publication.
   bool               WriteLifecycleSnapshot(const LifecycleSnapshot &snapshot) override;
   //--- \brief Read the current checked lifecycle snapshot.
   //--- \param snapshot [out] Current aggregate when STORE_READ_VALID is returned.
   //--- \return Detailed snapshot read result.
   ENUM_STORE_READ_RESULT ReadLifecycleSnapshot(LifecycleSnapshot &snapshot) override;
   //--- \brief Report whether this store uses a non-live runtime namespace.
   //--- \return true when a runtime namespace prefixes every generated key.
   bool               IsRuntimeIsolated() override { return(m_runtime_namespace != ""); }

   //--- \brief Write a scalar double under the named scope slot.
   bool               WriteScalar(string scope, double value) override;
   //--- \brief Read back the scalar stored under the named scope slot.
   bool               ReadScalar(string scope, double &value) override;
   //--- \brief Mark an order intent as already-seen.
   bool               SetDuplicate(string intent_id_hash) override;
   //--- \brief Check whether an intent has already been processed.
   bool               IsDuplicate(string intent_id_hash) override;
   //--- \brief Set HALT flag and write HALT evidence file.
   bool               SetHalt(const HaltEvidence &ev) override;
   //--- \brief Append HALT audit evidence without changing shared flags.
   //--- \param ev HALT evidence record to append.
   //--- \return true when every audit line is written.
   bool               AppendHaltEvidence(const HaltEvidence &ev) override;
   //--- \brief Check whether HALT flag is set.
   bool               IsHalted() override;
   //--- \brief Append recovery evidence, then clear the HALT flag last.
   bool               ClearHalt() override;
   //--- \brief Store a ulong ticket losslessly.
   bool               WriteTicket(ulong ticket) override;
   //--- \brief Read a stored ulong ticket.
   bool               ReadTicket(ulong &ticket) override;
   //--- \brief Store pending-entry order evidence.
   bool               WritePendingOrder(ulong ticket, datetime submitted_ts) override;
   //--- \brief Read pending-entry order evidence.
   bool               ReadPendingOrder(ulong &ticket, datetime &submitted_ts) override;
   //--- \brief Clear pending-entry order evidence.
   bool               ClearPendingOrder() override;
   //--- \brief Claim or reclaim token-fenced duplicate marker lease.
   bool               MarkerClaimOrReclaim(datetime now,
                                           int lease_secs,
                                           long &out_token,
                                           ENUM_DUPLICATE_MARKER_STATUS &status) override;
   //--- \brief Refresh marker lease if token is still current.
   bool               MarkerHeartbeat(long &token, datetime now) override;
   //--- \brief Check the current marker owner fence.
   bool               MarkerIsOwner(long token) override;
   //--- \brief Release marker lease if token is still current.
   bool               MarkerRelease(long token) override;
   //--- \brief Verify stored identity fingerprint.
   bool               Verify() override;
  };

//+------------------------------------------------------------------+
bool CStateStore::_key(string scope, string &key)
  {
   CanonicalIdentity id = m_id;
   id.scope = (m_runtime_namespace == "" ? scope : m_runtime_namespace + "_" + scope);
   return(m_kb.Build(id, key));
  }

//+------------------------------------------------------------------+
bool CStateStore::_setGV(string key, double value)
  {
   ResetLastError();
   if(GlobalVariableSet(key, value) != 0)
      return(true);

   PrintFormat("[TS_STORE_WRITE_FAIL] key='%s' value=%.17g error=%d",
              key, value, GetLastError());
   return(false);
  }

//+------------------------------------------------------------------+
bool CStateStore::_WriteSplitId(string scope_hi, string scope_lo, ulong value)
  {
   string key_hi, key_lo;
   if(!_key(scope_hi, key_hi)) return(false);
   if(!_key(scope_lo, key_lo)) return(false);
//--- Split into two 32-bit halves; both are ≤ 2^32-1 < 2^53 (exact in double).
//--- Restore the prior high half if the low-half publication fails. This
//--- prevents legacy ticket readers from assembling an identifier that never
//--- existed; snapshots add a separate checksum and commit-last fence.
   double hi = (double)(long)(value >> 32);
   double lo = (double)(long)(value & (ulong)0xFFFFFFFF);
   bool had_prev_hi = GlobalVariableCheck(key_hi);
   double prev_hi = (had_prev_hi ? GlobalVariableGet(key_hi) : 0.0);
   if(!_setGV(key_hi, hi))
      return(false);
   if(!_setGV(key_lo, lo))
     {
      if(had_prev_hi)
         _setGV(key_hi, prev_hi);
      else if(GlobalVariableCheck(key_hi))
         GlobalVariableDel(key_hi);
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
bool CStateStore::_ReadSplitId(string scope_hi, string scope_lo, ulong &value)
  {
   string key_hi, key_lo;
   if(!_key(scope_hi, key_hi)) return(false);
   if(!_key(scope_lo, key_lo)) return(false);
   if(!GlobalVariableCheck(key_hi) || !GlobalVariableCheck(key_lo)) return(false);

   double gv_hi = GlobalVariableGet(key_hi);
   double gv_lo = GlobalVariableGet(key_lo);
   const double max32 = 4294967295.0; // 2^32 - 1; still exact in double.
   if(gv_hi < 0.0 || gv_hi > max32 || MathFloor(gv_hi) != gv_hi)
      return(false);
   if(gv_lo < 0.0 || gv_lo > max32 || MathFloor(gv_lo) != gv_lo)
      return(false);

   ulong hi = (ulong)(long)gv_hi;
   ulong lo = (ulong)(long)gv_lo;
   value = (hi << 32) | lo;
   return(true);
  }

//+------------------------------------------------------------------+
double CStateStore::_SnapshotChecksum(const LifecycleSnapshot &snapshot)
  {
   string payload = IntegerToString((int)snapshot.state) + "|"
                  + StringFormat("%I64u", snapshot.position_ticket) + "|"
                  + StringFormat("%I64u", snapshot.position_identifier) + "|"
                  + StringFormat("%I64u", snapshot.pending.ticket) + "|"
                  + IntegerToString((long)snapshot.pending.submitted_ts) + "|"
                  + IntegerToString((long)snapshot.pending.cancel_requested_ts) + "|"
                  + IntegerToString((int)snapshot.pending.cancel_origin) + "|"
                  + IntegerToString(snapshot.halted ? 1 : 0) + "|"
                  + IntegerToString(snapshot.generation);
   const ulong basis_hi = (ulong)0xcbf29ce4;
   const ulong basis_lo = (ulong)0x84222325;
   const ulong prime_hi = (ulong)0x00000100;
   const ulong prime_lo = (ulong)0x000001b3;
   const ulong mask     = (ulong)0x001FFFFFFFFFFFFF;
   ulong hash  = (basis_hi << 32) | basis_lo;
   ulong prime = (prime_hi << 32) | prime_lo;
   for(int i = 0; i < StringLen(payload); i++)
     {
      hash ^= (ulong)StringGetCharacter(payload, i);
      hash *= prime;
     }
   return((double)(long)(hash & mask));
  }

//+------------------------------------------------------------------+
bool CStateStore::_SnapshotIsConsistent(const LifecycleSnapshot &snapshot)
  {
   if(snapshot.state < POSITION_STATE_IDLE || snapshot.state > POSITION_STATE_PENDING_CANCEL)
      return(false);
   if(snapshot.halted != (snapshot.state == POSITION_STATE_HALT))
      return(false);
   if(snapshot.pending.cancel_origin < CANCEL_ORIGIN_NONE
      || snapshot.pending.cancel_origin > CANCEL_ORIGIN_DAY_TRADE)
      return(false);

   if(snapshot.state == POSITION_STATE_IDLE)
      return(snapshot.position_ticket == 0 && snapshot.position_identifier == 0
             && snapshot.pending.ticket == 0 && snapshot.pending.submitted_ts == 0
             && snapshot.pending.cancel_requested_ts == 0
             && snapshot.pending.cancel_origin == CANCEL_ORIGIN_NONE);

   if(snapshot.state == POSITION_STATE_ACTIVE || snapshot.state == POSITION_STATE_PENDING_EXIT)
      return(snapshot.position_ticket != 0 && snapshot.position_identifier != 0
             && snapshot.pending.ticket == 0 && snapshot.pending.submitted_ts == 0
             && snapshot.pending.cancel_requested_ts == 0
             && snapshot.pending.cancel_origin == CANCEL_ORIGIN_NONE);

   if(snapshot.state == POSITION_STATE_PENDING_ENTRY)
      return(snapshot.position_ticket == 0 && snapshot.position_identifier == 0
             && snapshot.pending.ticket != 0 && snapshot.pending.submitted_ts > 0
             && snapshot.pending.cancel_requested_ts == 0
             && snapshot.pending.cancel_origin == CANCEL_ORIGIN_NONE);

   if(snapshot.state == POSITION_STATE_PENDING_CANCEL)
      return(snapshot.position_ticket == 0 && snapshot.position_identifier == 0
             && snapshot.pending.ticket != 0 && snapshot.pending.submitted_ts > 0
             && snapshot.pending.cancel_requested_ts > 0
             && snapshot.pending.cancel_origin != CANCEL_ORIGIN_NONE);

//--- HALT may retain one prior lifecycle shape, but never contradictory
//--- position and order ownership or half-populated evidence.
   bool no_position = (snapshot.position_ticket == 0 && snapshot.position_identifier == 0);
   bool has_position = (snapshot.position_ticket != 0 && snapshot.position_identifier != 0);
   if(!no_position && !has_position) return(false);

   bool no_pending = (snapshot.pending.ticket == 0
                      && snapshot.pending.submitted_ts == 0
                      && snapshot.pending.cancel_requested_ts == 0
                      && snapshot.pending.cancel_origin == CANCEL_ORIGIN_NONE);
   bool entry_pending = (snapshot.pending.ticket != 0
                         && snapshot.pending.submitted_ts > 0
                         && snapshot.pending.cancel_requested_ts == 0
                         && snapshot.pending.cancel_origin == CANCEL_ORIGIN_NONE);
   bool cancel_pending = (snapshot.pending.ticket != 0
                          && snapshot.pending.submitted_ts > 0
                          && snapshot.pending.cancel_requested_ts > 0
                          && snapshot.pending.cancel_origin != CANCEL_ORIGIN_NONE);
   if(!no_pending && !entry_pending && !cancel_pending) return(false);
   return(!(has_position && !no_pending));
  }

//+------------------------------------------------------------------+
bool CStateStore::_WriteSnapshotSlot(int slot, const LifecycleSnapshot &snapshot)
  {
   string p = (slot == 0 ? "life0_" : "life1_");
   if(!_WriteSplitId(p + "pos_hi", p + "pos_lo", snapshot.position_ticket)) return(false);
   if(!_WriteSplitId(p + "pid_hi", p + "pid_lo", snapshot.position_identifier)) return(false);
   if(!_WriteSplitId(p + "pend_hi", p + "pend_lo", snapshot.pending.ticket)) return(false);
   if(!WriteScalar(p + "state", (double)snapshot.state)) return(false);
   if(!WriteScalar(p + "sub_ts", (double)snapshot.pending.submitted_ts)) return(false);
   if(!WriteScalar(p + "cancel_ts", (double)snapshot.pending.cancel_requested_ts)) return(false);
   if(!WriteScalar(p + "cancel_origin", (double)snapshot.pending.cancel_origin)) return(false);
   if(!WriteScalar(p + "halted", (snapshot.halted ? 1.0 : 0.0))) return(false);
   if(!WriteScalar(p + "generation", (double)snapshot.generation)) return(false);
   return(WriteScalar(p + "checksum", _SnapshotChecksum(snapshot)));
  }

//+------------------------------------------------------------------+
ENUM_STORE_READ_RESULT CStateStore::_ReadSnapshotSlot(int slot,
                                                       long generation,
                                                       LifecycleSnapshot &snapshot)
  {
   string p = (slot == 0 ? "life0_" : "life1_");
   double state_value = 0.0, sub_ts = 0.0, cancel_ts = 0.0;
   double cancel_origin = 0.0, halted = 0.0, stored_generation = 0.0, checksum = 0.0;
   ulong pos_ticket = 0, position_identifier = 0, pending_ticket = 0;
   if(!_ReadSplitId(p + "pos_hi", p + "pos_lo", pos_ticket)
      || !_ReadSplitId(p + "pid_hi", p + "pid_lo", position_identifier)
      || !_ReadSplitId(p + "pend_hi", p + "pend_lo", pending_ticket)
      || !ReadScalar(p + "state", state_value)
      || !ReadScalar(p + "sub_ts", sub_ts)
      || !ReadScalar(p + "cancel_ts", cancel_ts)
      || !ReadScalar(p + "cancel_origin", cancel_origin)
      || !ReadScalar(p + "halted", halted)
      || !ReadScalar(p + "generation", stored_generation)
      || !ReadScalar(p + "checksum", checksum))
      return(STORE_READ_CORRUPT);

   if(MathFloor(state_value) != state_value
      || MathFloor(sub_ts) != sub_ts
      || MathFloor(cancel_ts) != cancel_ts
      || MathFloor(cancel_origin) != cancel_origin
      || MathFloor(stored_generation) != stored_generation
      || (halted != 0.0 && halted != 1.0)
      || (long)stored_generation != generation)
      return(STORE_READ_CORRUPT);

   snapshot.state = (ENUM_POSITION_STATE)(int)state_value;
   snapshot.position_ticket = pos_ticket;
   snapshot.position_identifier = position_identifier;
   snapshot.pending.ticket = pending_ticket;
   snapshot.pending.submitted_ts = (datetime)(long)sub_ts;
   snapshot.pending.cancel_requested_ts = (datetime)(long)cancel_ts;
   snapshot.pending.cancel_origin = (ENUM_CANCEL_ORIGIN)(int)cancel_origin;
   snapshot.halted = (halted >= 0.5);
   snapshot.generation = generation;

   if(checksum != _SnapshotChecksum(snapshot))
      return(STORE_READ_CORRUPT);
   if(!_SnapshotIsConsistent(snapshot))
      return(STORE_READ_CORRUPT);
   return(STORE_READ_VALID);
  }

//+------------------------------------------------------------------+
string CStateStore::_HaltFileName(void)
  {
   return("TradeSpine/Halt_" + StringFormat("%I64u", m_id.magic)
          + "_" + _SanitizePath(m_id.symbol) + ".txt");
  }

//+------------------------------------------------------------------+
string CStateStore::_MarkerLockFileName(void)
  {
   string lock_key = "";
   CanonicalIdentity lock_id = m_id;
   lock_id.scope = (m_runtime_namespace == ""
                    ? "marker_bootstrap_lock"
                    : m_runtime_namespace + "_marker_bootstrap_lock");
   if(m_kb == NULL || !m_kb.Build(lock_id, lock_key))
      return("");
   return("TradeSpine/Lease_" + lock_key + ".lck");
  }

//+------------------------------------------------------------------+
bool CStateStore::Init(const CanonicalIdentity &id,
                       CKeyBuilder* kb,
                       string runtime_namespace,
                       IMarkerBackend* marker_backend)
  {
   if(kb == NULL || StringFind(runtime_namespace, "|") >= 0)
      return(false);
   m_kb          = kb;
   m_id          = id;
   m_runtime_namespace = runtime_namespace;
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

//--- Bind the extracted token/heartbeat protocol after all identity-derived
//--- names are available. The backend remains injectable for interleaving tests.
   string owner_key, heartbeat_key;
   if(!_key("marker_owner", owner_key) || !_key("marker_hb_ts", heartbeat_key))
      return(false);
   IMarkerBackend* effective_backend = (marker_backend != NULL
                                        ? marker_backend
                                        : &m_terminal_marker_backend);
   if(!m_marker_lease.Init(owner_key,
                           heartbeat_key,
                           _MarkerLockFileName(),
                           effective_backend))
      return(false);

   m_initialized = true;
   return(true);
  }

//+------------------------------------------------------------------+
bool CStateStore::WriteLifecycleSnapshot(const LifecycleSnapshot &snapshot)
  {
   if(!m_initialized) return(false);
   if(!_SnapshotIsConsistent(snapshot))
     {
      Print("[TS_STORE_SNAPSHOT_REJECTED] lifecycle invariants failed before publication");
      return(false);
     }
   string commit_key;
   if(!_key("life_commit", commit_key)) return(false);

   long current_generation = 0;
   if(GlobalVariableCheck(commit_key))
     {
      double current = GlobalVariableGet(commit_key);
      if(current < 1.0 || MathFloor(current) != current || current >= 9007199254740991.0)
         return(false);
      current_generation = (long)current;
     }

   LifecycleSnapshot candidate = snapshot;
   candidate.generation = current_generation + 1;
   int slot = (int)(candidate.generation % 2);
   if(!_WriteSnapshotSlot(slot, candidate))
      return(false);

   LifecycleSnapshot verified;
   if(_ReadSnapshotSlot(slot, candidate.generation, verified) != STORE_READ_VALID)
      return(false);
   if(!_setGV(commit_key, (double)candidate.generation))
      return(false);
   return(GlobalVariableCheck(commit_key)
          && GlobalVariableGet(commit_key) == (double)candidate.generation);
  }

//+------------------------------------------------------------------+
ENUM_STORE_READ_RESULT CStateStore::ReadLifecycleSnapshot(LifecycleSnapshot &snapshot)
  {
   if(!m_initialized) return(STORE_READ_ERROR);
   string commit_key;
   if(!_key("life_commit", commit_key)) return(STORE_READ_ERROR);
   if(!GlobalVariableCheck(commit_key)) return(STORE_READ_ABSENT);
   double committed = GlobalVariableGet(commit_key);
   if(committed < 1.0 || MathFloor(committed) != committed || committed > 9007199254740991.0)
      return(STORE_READ_CORRUPT);
   long generation = (long)committed;
   ENUM_STORE_READ_RESULT result = _ReadSnapshotSlot((int)(generation % 2), generation, snapshot);
   if(result == STORE_READ_CORRUPT)
      PrintFormat("[TS_STORE_SNAPSHOT_CORRUPT] generation=%I64d", generation);
   return(result);
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

//--- 2. Append the string payload to a durable audit file (GVs store scalars only).
   return(_AppendHaltEvidence(ev));
  }

//+------------------------------------------------------------------+
bool CStateStore::AppendHaltEvidence(const HaltEvidence &ev)
  {
   if(!m_initialized) return(false);
   return(_AppendHaltEvidence(ev));
  }

//+------------------------------------------------------------------+
bool CStateStore::_AppendHaltEvidence(const HaltEvidence &ev)
  {
   string fname = _HaltFileName();
   int fh = FileOpen(fname, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(fh == INVALID_HANDLE && !FileIsExist(fname))
      fh = FileOpen(fname, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(fh == INVALID_HANDLE)
      return(false);

   FileSeek(fh, 0, SEEK_END);
   bool ok = true;
   ok &= (FileWriteString(fh,
                         "halt_at=" + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "\n") > 0);
   ok &= (FileWriteString(fh, "reason=" + _StripNewlines(ev.reason) + "\n") > 0);
   ok &= (FileWriteString(fh, "last_known_state=" + IntegerToString(ev.last_known_state) + "\n") > 0);
   ok &= (FileWriteString(fh, "operator_action=" + _StripNewlines(ev.operator_action) + "\n") > 0);
   ok &= (FileWriteString(fh, "symbol=" + _StripNewlines(ev.symbol) + "\n") > 0);
   ok &= (FileWriteString(fh, "magic=" + StringFormat("%I64u", ev.magic) + "\n") > 0);
   ok &= (FileWriteString(fh, "ticket=" + StringFormat("%I64u", ev.ticket) + "\n") > 0);
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
bool CStateStore::ClearHalt()
  {
   if(!m_initialized) return(false);
   string key;
   if(!_key("halt_flag", key)) return(false);
//--- Preserve evidence and append the recovery event before clearing the flag.
//--- A failed archive append leaves HALT absorbing.
   string fname = _HaltFileName();
   int fh = FileOpen(fname, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(fh == INVALID_HANDLE)
      return(false);
   FileSeek(fh, 0, SEEK_END);
   bool archived = (FileWriteString(fh,
                      "cleared_at=" + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "\n") > 0);
   FileFlush(fh);
   FileClose(fh);
   if(!archived)
      return(false);
   if(!GlobalVariableCheck(key))
      return(true);
   return(GlobalVariableDel(key));
  }

//+------------------------------------------------------------------+
bool CStateStore::WriteTicket(ulong ticket)
  {
   if(!m_initialized) return(false);
   return(_WriteSplitId("tkt_hi", "tkt_lo", ticket));
  }

//+------------------------------------------------------------------+
bool CStateStore::ReadTicket(ulong &ticket)
  {
   if(!m_initialized) return(false);
   return(_ReadSplitId("tkt_hi", "tkt_lo", ticket));
  }

//+------------------------------------------------------------------+
bool CStateStore::WritePendingOrder(ulong ticket, datetime submitted_ts)
  {
   if(!m_initialized) return(false);
   string key_hi, key_lo, key_ts;
   if(!_key("pend_ord_hi", key_hi) || !_key("pend_ord_lo", key_lo)
      || !_key("pend_ord_ts", key_ts)) return(false);
   bool had_hi = GlobalVariableCheck(key_hi);
   bool had_lo = GlobalVariableCheck(key_lo);
   bool had_ts = GlobalVariableCheck(key_ts);
   double prev_hi = (had_hi ? GlobalVariableGet(key_hi) : 0.0);
   double prev_lo = (had_lo ? GlobalVariableGet(key_lo) : 0.0);
   double prev_ts = (had_ts ? GlobalVariableGet(key_ts) : 0.0);
   if(!_WriteSplitId("pend_ord_hi", "pend_ord_lo", ticket))
      return(false);
   if(!_setGV(key_ts, (double)submitted_ts))
     {
      bool restored = true;
      if(had_hi) restored = _setGV(key_hi, prev_hi) && restored;
      else if(GlobalVariableCheck(key_hi)) restored = GlobalVariableDel(key_hi) && restored;
      if(had_lo) restored = _setGV(key_lo, prev_lo) && restored;
      else if(GlobalVariableCheck(key_lo)) restored = GlobalVariableDel(key_lo) && restored;
      if(had_ts) restored = _setGV(key_ts, prev_ts) && restored;
      else if(GlobalVariableCheck(key_ts)) restored = GlobalVariableDel(key_ts) && restored;
      if(!restored)
         Print("[TS_STORE_PENDING_RESTORE_FAIL] prior pending evidence could not be fully restored");
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
bool CStateStore::ReadPendingOrder(ulong &ticket, datetime &submitted_ts)
  {
   if(!m_initialized) return(false);
   string key_ts;
   if(!_key("pend_ord_ts", key_ts)) return(false);
   if(!GlobalVariableCheck(key_ts)) return(false);
   if(!_ReadSplitId("pend_ord_hi", "pend_ord_lo", ticket))
      return(false);
   submitted_ts = (datetime)(long)GlobalVariableGet(key_ts);
   return(true);
  }

//+------------------------------------------------------------------+
bool CStateStore::ClearPendingOrder()
  {
   if(!m_initialized) return(false);
   string key_hi, key_lo, key_ts;
   if(!_key("pend_ord_hi", key_hi)) return(false);
   if(!_key("pend_ord_lo", key_lo)) return(false);
   if(!_key("pend_ord_ts", key_ts)) return(false);
   bool ok = true;
   if(GlobalVariableCheck(key_hi)) ok = GlobalVariableDel(key_hi) && ok;
   if(GlobalVariableCheck(key_lo)) ok = GlobalVariableDel(key_lo) && ok;
   if(GlobalVariableCheck(key_ts)) ok = GlobalVariableDel(key_ts) && ok;
   return(ok);
  }

//+------------------------------------------------------------------+
bool CStateStore::MarkerClaimOrReclaim(datetime now,
                                       int lease_secs,
                                       long &out_token,
                                       ENUM_DUPLICATE_MARKER_STATUS &status)
  {
   if(!m_initialized)
     {
      out_token = 0;
      status = DUPLICATE_MARKER_CONFLICT;
      return(false);
     }
   return(m_marker_lease.ClaimOrReclaim(now, lease_secs, out_token, status));
  }

//+------------------------------------------------------------------+
bool CStateStore::MarkerHeartbeat(long &token, datetime now)
  {
   return(m_initialized && m_marker_lease.Heartbeat(token, now));
  }

//+------------------------------------------------------------------+
bool CStateStore::MarkerIsOwner(long token)
  {
   return(m_initialized && m_marker_lease.IsOwner(token));
  }

//+------------------------------------------------------------------+
bool CStateStore::MarkerRelease(long token)
  {
   return(m_initialized && m_marker_lease.Release(token));
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
