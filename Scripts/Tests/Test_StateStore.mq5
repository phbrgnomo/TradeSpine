//+------------------------------------------------------------------+
//|                                            Test_StateStore.mq5   |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_StateStore.mq5                        |
//| @tdd: TDD.05.04.e64a  @spec: SPEC-05  @iplan: IPLAN-05           |
//|                                                                  |
//| Tier-1 unit tests for CKeyBuilder and CStateStore:              |
//|   - Key determinism, bounds, and no raw identity leakage.        |
//|   - GV read/write round-trip, duplicate markers, HALT flag,      |
//|     lossless ulong ticket split, and identity fingerprint.       |
//| Uses real terminal GVs under a reserved test identity            |
//| (account=0, symbol="TSTEST", magic=99905). GVs are cleaned up   |
//| after every test to leave no trace in the MT5 terminal.         |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-05 - KeyBuilder and StateStore unit tests"

#include "../../Include/Testing/Assert.mqh"
#include "../../Include/Persistence/KeyBuilder.mqh"
#include "../../Include/Persistence/StateStore.mqh"

//--- Reserved test identity — unlikely to collide with live strategy GVs.
#define TEST_ACCOUNT  ((long)0)
#define TEST_SYMBOL   "TSTEST"
#define TEST_MAGIC    ((ulong)99905)

/** \brief One in-memory marker slot key/value pair. */
struct DeterministicMarkerSlot
  {
   string key;
   double value;
  };

/** \brief Deterministic marker backend with a controllable CAS-to-heartbeat theft hook. */
class DeterministicMarkerBackend : public IMarkerBackend
  {
  private:
   DeterministicMarkerSlot m_slots[];
   bool m_locked;
   string m_owner_key;
   string m_hb_key;
   bool m_heartbeat_mismatch_pending;
   int _Find(string key)
     {
      for(int i = 0; i < ArraySize(m_slots); i++)
         if(m_slots[i].key == key) return(i);
      return(-1);
     }
   bool _Put(string key, double value)
     {
      int i = _Find(key);
      if(i < 0)
        {
         i = ArraySize(m_slots);
         ArrayResize(m_slots, i + 1);
         m_slots[i].key = key;
        }
      m_slots[i].value = value;
      return(true);
     }
  public:
   bool steal_after_heartbeat;
   bool transient_heartbeat_read_mismatch;
   DeterministicMarkerBackend(void) : m_locked(false), m_owner_key(""), m_hb_key(""),
                                      m_heartbeat_mismatch_pending(false),
                                      steal_after_heartbeat(false),
                                      transient_heartbeat_read_mismatch(false) {}
   bool Exists(string key) override { return(_Find(key) >= 0); }
   double Get(string key) override
     {
      int i = _Find(key);
      if(key == m_hb_key && m_heartbeat_mismatch_pending)
        {
         m_heartbeat_mismatch_pending = false;
         return(i >= 0 ? m_slots[i].value - 1.0 : 0.0);
        }
      return(i >= 0 ? m_slots[i].value : 0.0);
     }
   bool Set(string key, double value) override
     {
      if(m_owner_key == "") m_owner_key = key;
      else if(m_hb_key == "" && key != m_owner_key) m_hb_key = key;
      _Put(key, value);
      if(transient_heartbeat_read_mismatch && key == m_hb_key && value > 0.0)
        {
         m_heartbeat_mismatch_pending = true;
         transient_heartbeat_read_mismatch = false;
        }
      if(steal_after_heartbeat && key == m_hb_key && value > 0.0)
        {
         _Put(m_owner_key, Get(m_owner_key) + 100.0);
         steal_after_heartbeat = false;
        }
      return(true);
     }
   bool CompareExchange(string key, double value, double expected) override
     {
      if(!Exists(key) || Get(key) != expected) return(false);
      return(_Put(key, value));
     }
   int AcquireExclusive(string lock_name) override
     {
      if(m_locked) return(INVALID_HANDLE);
      m_locked = true;
      return(1);
     }
   void ReleaseExclusive(int handle) override { m_locked = false; }
  };

/** \brief Build a test CanonicalIdentity with the given scope. */
CanonicalIdentity MakeTestId(string scope)
  {
   CanonicalIdentity id;
   id.account = TEST_ACCOUNT;
   id.symbol  = TEST_SYMBOL;
   id.magic   = TEST_MAGIC;
   id.scope   = scope;
   return(id);
  }

/** \brief Delete test GVs and halt evidence file created during a test; ignores missing keys. */
void CleanupGVs(CKeyBuilder &kb)
  {
   string scopes[] =
     {
      "fp", "halt_flag", "tkt_hi", "tkt_lo",
      "pend_ord_hi", "pend_ord_lo", "pend_ord_ts",
      "marker_owner", "marker_hb_ts", "life_commit",
      "life0_pos_hi", "life0_pos_lo", "life0_pend_hi", "life0_pend_lo",
      "life0_pid_hi", "life0_pid_lo",
      "life0_state", "life0_sub_ts", "life0_cancel_ts", "life0_cancel_origin",
      "life0_halted", "life0_generation", "life0_checksum",
      "life1_pos_hi", "life1_pos_lo", "life1_pend_hi", "life1_pend_lo",
      "life1_pid_hi", "life1_pid_lo",
      "life1_state", "life1_sub_ts", "life1_cancel_ts", "life1_cancel_origin",
      "life1_halted", "life1_generation", "life1_checksum",
      "test_scalar", "dup_intentA", "dup_intentB", "dup_xyz"
     };
   for(int i = 0; i < ArraySize(scopes); i++)
     {
      string key;
      if(kb.Build(MakeTestId(scopes[i]), key))
         GlobalVariableDel(key);
     }
//--- Also delete any halt evidence file.
   FileDelete("TradeSpine/Halt_" + StringFormat("%I64u", TEST_MAGIC) + "_" + TEST_SYMBOL + ".txt");
  }

/**
 * \brief Create and initialize a fresh CStateStore for tests.
 * \param store  Output: the store to initialize.
 * \param kb     Key builder to use.
 * \return true when Init() succeeds.
 */
bool MakeStore(CStateStore &store, CKeyBuilder &kb)
  {
   CanonicalIdentity base = MakeTestId(""); // scope overwritten internally
   return(store.Init(base, &kb));
  }

//--- ----------------------------------------------------------------+
//--- KeyBuilder tests                                                |
//--- ----------------------------------------------------------------+

/** \brief Verify CKeyBuilder produces deterministic, bounded keys that hide raw identity. */
bool Test_KeyBuilder_Determinism(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;

   CanonicalIdentity id;
   id.account = 123;
   id.symbol  = "WINM26";
   id.magic   = 42;
   id.scope   = "halt";

   string key1, key2;
   ok &= a.TS_CHECK(kb.Build(id, key1), "Build returns true");
   ok &= a.TS_CHECK(kb.Build(id, key2), "Second Build returns true");
   ok &= a.TS_CHECK_EQ_STR(key1, key2, "Same inputs produce same key (deterministic)");
   ok &= a.TS_CHECK(StringLen(key1) <= 63, "Key fits MT5 GV name limit (≤63 chars)");
   ok &= a.TS_CHECK(StringLen(key1) == 19, "Key is exactly 19 chars (ts_ + 16 hex)");

//--- Raw identity MUST NOT appear in the key.
   ok &= a.TS_CHECK(StringFind(key1, "123")   < 0, "Account not in key");
   ok &= a.TS_CHECK(StringFind(key1, "WINM26") < 0, "Symbol not in key");
   ok &= a.TS_CHECK(StringFind(key1, "42")    < 0, "Magic not in key");

   return(ok);
  }

/** \brief Verify different scopes produce different CKeyBuilder keys. */
bool Test_KeyBuilder_ScopeIsolation(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   string key_halt, key_fp, key_tkt_hi;
   kb.Build(MakeTestId("halt"),   key_halt);
   kb.Build(MakeTestId("fp"),     key_fp);
   kb.Build(MakeTestId("tkt_hi"), key_tkt_hi);
   ok &= a.TS_CHECK(key_halt   != key_fp,     "halt and fp keys differ");
   ok &= a.TS_CHECK(key_halt   != key_tkt_hi, "halt and tkt_hi keys differ");
   ok &= a.TS_CHECK(key_fp     != key_tkt_hi, "fp and tkt_hi keys differ");
   return(ok);
  }

/** \brief Verify CKeyBuilder.Verify() detects identity mismatches (KeyCollision path). */
bool Test_KeyBuilder_Verify(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;

   CanonicalIdentity id_a, id_b;
   id_a.account = 123; id_a.symbol = "WINM26"; id_a.magic = 42; id_a.scope = "halt";
   id_b.account = 456; id_b.symbol = "WINM26"; id_b.magic = 42; id_b.scope = "halt";

   string key_a;
   kb.Build(id_a, key_a);

   ok &= a.TS_CHECK(kb.Verify(key_a, id_a), "Verify passes for same identity");
   ok &= a.TS_CHECK(!kb.Verify(key_a, id_b), "Verify fails for different account (KeyCollision)");
   return(ok);
  }

/** \brief Verify CKeyBuilder.Fingerprint() returns an exact double in [0, 2^53-1]. */
bool Test_KeyBuilder_Fingerprint(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;

   CanonicalIdentity id = MakeTestId("any");
   double fp = kb.Fingerprint(id);
   ok &= a.TS_CHECK(fp >= 0.0,                   "Fingerprint is non-negative");
   ok &= a.TS_CHECK(fp <= 9007199254740991.0,     "Fingerprint ≤ 2^53-1 (exact double range)");
   ok &= a.TS_CHECK(fp == (double)(long)fp,       "Fingerprint is exact integer as double");

//--- Fingerprint ignores scope: same raw identity → same fingerprint.
   CanonicalIdentity id2 = MakeTestId("different_scope");
   ok &= a.TS_CHECK_EQ_D(fp, kb.Fingerprint(id2), 0.0,
                         "Fingerprint is scope-independent (same account/symbol/magic)");
   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- StateStore tests (use real terminal GVs; cleaned up after)      |
//--- ----------------------------------------------------------------+

/** \brief Verify CStateStore.Init() writes a fingerprint and tolerates reinit with the same identity. */
bool Test_StateStore_Init(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb); // start clean

   CStateStore store;
   ok &= a.TS_CHECK(MakeStore(store, kb), "Init() succeeds on first call");
   ok &= a.TS_CHECK(store.Verify(),       "Verify() passes after Init()");

//--- Second Init with same identity: finds matching fingerprint, succeeds.
   CStateStore store2;
   ok &= a.TS_CHECK(MakeStore(store2, kb), "Re-Init with same identity succeeds");

   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify CStateStore scalar read/write round-trip. */
bool Test_StateStore_Scalar(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);

   ok &= a.TS_CHECK(store.WriteScalar("test_scalar", 3.14), "WriteScalar returns true");
   double v = -1.0;
   ok &= a.TS_CHECK(store.ReadScalar("test_scalar", v), "ReadScalar returns true");
   ok &= a.TS_CHECK_EQ_D(v, 3.14, 1e-12, "Read-back value matches written value");

//--- Reading a non-existent scope returns false and leaves v unchanged.
   double v2 = 42.0;
   ok &= a.TS_CHECK(!store.ReadScalar("nonexistent", v2), "ReadScalar returns false for absent key");
   ok &= a.TS_CHECK_EQ_D(v2, 42.0, 0.0, "Sentinel unchanged on missing read");

   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify CStateStore duplicate markers guard against double-processing. */
bool Test_StateStore_Duplicate(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);

   ok &= a.TS_CHECK(!store.IsDuplicate("intentA"), "No duplicate before SetDuplicate");
   ok &= a.TS_CHECK(store.SetDuplicate("intentA"), "SetDuplicate returns true");
   ok &= a.TS_CHECK(store.IsDuplicate("intentA"),  "IsDuplicate true after SetDuplicate");
   ok &= a.TS_CHECK(!store.IsDuplicate("intentB"), "Different hash is not a duplicate");

   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify CStateStore HALT flag round-trip and file evidence creation. */
bool Test_StateStore_Halt(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);

   ok &= a.TS_CHECK(!store.IsHalted(), "Not halted before SetHalt");

   HaltEvidence ev;
   ev.reason           = "Test HALT reason";
   ev.last_known_state = POSITION_STATE_ACTIVE;
   ev.operator_action  = "Restart and verify position";
   ev.symbol           = TEST_SYMBOL;
   ev.magic            = TEST_MAGIC;
   ev.ticket           = (ulong)123456;

   ok &= a.TS_CHECK(store.SetHalt(ev), "SetHalt returns true");
   ok &= a.TS_CHECK(store.IsHalted(),  "IsHalted true after SetHalt");

   string halt_file = "TradeSpine/Halt_" + StringFormat("%I64u", TEST_MAGIC) + "_" + TEST_SYMBOL + ".txt";
   ok &= a.TS_CHECK(FileIsExist(halt_file), "HALT evidence file exists after SetHalt");

   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify CStateStore.ClearHalt() appends recovery evidence before clearing the flag. */
bool Test_StateStore_ClearHalt(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);

   HaltEvidence ev;
   ev.reason           = "Clear HALT reason";
   ev.last_known_state = POSITION_STATE_HALT;
   ev.operator_action  = "Clear after operator verification";
   ev.symbol           = TEST_SYMBOL;
   ev.magic            = TEST_MAGIC;
   ev.ticket           = (ulong)98765;

   string halt_file = "TradeSpine/Halt_" + StringFormat("%I64u", TEST_MAGIC) + "_" + TEST_SYMBOL + ".txt";

   ok &= a.TS_CHECK(store.SetHalt(ev), "SetHalt before ClearHalt returns true");
   ok &= a.TS_CHECK(store.IsHalted(), "HALT flag set before ClearHalt");
   ok &= a.TS_CHECK(FileIsExist(halt_file), "HALT evidence file exists before ClearHalt");

   ok &= a.TS_CHECK(store.ClearHalt(), "ClearHalt returns true");
   ok &= a.TS_CHECK(!store.IsHalted(), "HALT flag removed by ClearHalt");
   ok &= a.TS_CHECK(FileIsExist(halt_file), "HALT evidence remains retained after ClearHalt");
   string recovered_content = ReadHaltFile(halt_file);
   ok &= a.TS_CHECK(StringFind(recovered_content, "cleared_at=") >= 0,
                    "ClearHalt appends durable recovery evidence before clearing the flag");

   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify HALT evidence filename uses unsigned decimal for magic values above LONG_MAX. */
bool Test_StateStore_Halt_LargeMagic(CAssert &a)
  {
   bool ok = true;

//--- 0x8000000000000000 is 2^63 — positive as ulong, negative as long.
   ulong large_magic = ((ulong)0x80000000 << 32);

   CanonicalIdentity id;
   id.account = 0;
   id.symbol  = "TSTEST";
   id.magic   = large_magic;
   id.scope   = "";

   CKeyBuilder kb;
   CStateStore store;

//--- Pre-test cleanup: remove any stale artifacts from prior MT5 test runs.
   {
      string pre_file = "TradeSpine/Halt_" + StringFormat("%I64u", large_magic) + "_TSTEST.txt";
      FileDelete(pre_file);
      string k_fp, k_halt;
      CanonicalIdentity pre_id = id;
      pre_id.scope = "fp";        kb.Build(pre_id, k_fp);
      pre_id.scope = "halt_flag"; kb.Build(pre_id, k_halt);
      GlobalVariableDel(k_fp);
      GlobalVariableDel(k_halt);
   }

   ok &= a.TS_CHECK(store.Init(id, &kb), "Init with large magic succeeds");

//--- The unsigned filename must differ from the signed one (test self-check).
   string expected_file = "TradeSpine/Halt_"
                        + StringFormat("%I64u", large_magic)
                        + "_TSTEST.txt";
   string signed_file   = "TradeSpine/Halt_"
                        + IntegerToString((long)large_magic)
                        + "_TSTEST.txt";
   ok &= a.TS_CHECK(expected_file != signed_file,
                    "Unsigned and signed filenames differ (self-check)");

   HaltEvidence ev;
   ev.reason           = "LargeMagic HALT test";
   ev.last_known_state = POSITION_STATE_ACTIVE;
   ev.operator_action  = "Verify and restart";
   ev.symbol           = "TSTEST";
   ev.magic            = large_magic;
   ev.ticket           = (ulong)0;

   ok &= a.TS_CHECK(store.SetHalt(ev), "SetHalt with large magic returns true");
   ok &= a.TS_CHECK(FileIsExist(expected_file),
                    "HALT file uses unsigned decimal path for large magic");
   ok &= a.TS_CHECK(!FileIsExist(signed_file),
                    "No HALT file at signed-negative path for large magic");

//--- Cleanup: remove evidence file and GVs created for this identity.
   FileDelete(expected_file);
   string fp_key, halt_key;
   id.scope = "fp";      kb.Build(id, fp_key);
   id.scope = "halt_flag"; kb.Build(id, halt_key);
   GlobalVariableDel(fp_key);
   GlobalVariableDel(halt_key);

   return(ok);
  }

/** \brief Verify CStateStore lossless ulong ticket split, including ULONG_MAX and zero. */
bool Test_StateStore_Ticket(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);

//--- Typical broker ticket value.
   ulong t1 = (ulong)12345678901;
   ok &= a.TS_CHECK(store.WriteTicket(t1), "WriteTicket (typical) returns true");
   ulong r1 = (ulong)0;
   ok &= a.TS_CHECK(store.ReadTicket(r1),  "ReadTicket (typical) returns true");
   ok &= a.TS_CHECK_EQ_L((long)r1, (long)t1, "Typical ticket round-trip exact");

//--- Edge case: ULONG_MAX (all 64 bits set).
   ulong ulong_max = (ulong) - 1; // 0xFFFFFFFFFFFFFFFF
   ok &= a.TS_CHECK(store.WriteTicket(ulong_max), "WriteTicket (ULONG_MAX) returns true");
   ulong r_max = (ulong)0;
   ok &= a.TS_CHECK(store.ReadTicket(r_max),      "ReadTicket (ULONG_MAX) returns true");
   ok &= a.TS_CHECK_EQ_L((long)r_max, (long)ulong_max, "ULONG_MAX ticket round-trip exact");

//--- Edge case: zero ticket.
   ok &= a.TS_CHECK(store.WriteTicket((ulong)0), "WriteTicket (0) returns true");
   ulong r_zero = (ulong)99;
   ok &= a.TS_CHECK(store.ReadTicket(r_zero),     "ReadTicket (0) returns true");
   ok &= a.TS_CHECK_EQ_L((long)r_zero, (long)(ulong)0, "Zero ticket round-trip exact");

   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify corrupt split-ID GV halves are rejected before ulong reassembly.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_StateStore_SplitIdRejectsCorruptParts(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);

   string key_hi, key_lo;
   kb.Build(MakeTestId("tkt_hi"), key_hi);
   kb.Build(MakeTestId("tkt_lo"), key_lo);

   ok &= a.TS_CHECK(store.WriteTicket((ulong)123456789), "WriteTicket before corruption succeeds");

   ulong read_ticket = (ulong)777;
   GlobalVariableSet(key_hi, 1.5);
   ok &= a.TS_CHECK(!store.ReadTicket(read_ticket),
                    "ReadTicket rejects fractional high split-ID half");
   ok &= a.TS_CHECK_EQ_L((long)read_ticket, (long)(ulong)777,
                         "ReadTicket leaves output unchanged on corrupt fractional high half");

   GlobalVariableSet(key_hi, 0.0);
   GlobalVariableSet(key_lo, 4294967296.0);
   ok &= a.TS_CHECK(!store.ReadTicket(read_ticket),
                    "ReadTicket rejects low split-ID half above 32-bit range");

   GlobalVariableSet(key_hi, -1.0);
   GlobalVariableSet(key_lo, 0.0);
   ok &= a.TS_CHECK(!store.ReadTicket(read_ticket),
                    "ReadTicket rejects negative high split-ID half");

   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify commit-last lifecycle snapshots, inactive-slot isolation, and corruption classification.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_StateStore_LifecycleSnapshot(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);
   CStateStore store;
   MakeStore(store, kb);

   LifecycleSnapshot idle;
   idle.state = POSITION_STATE_IDLE;
   idle.position_ticket = 0;
   idle.position_identifier = 0;
   idle.pending.ticket = 0;
   idle.pending.submitted_ts = 0;
   idle.pending.cancel_requested_ts = 0;
   idle.pending.cancel_origin = CANCEL_ORIGIN_NONE;
   idle.halted = false;
   idle.generation = 0;
   ok &= a.TS_CHECK(store.WriteLifecycleSnapshot(idle),
                    "First complete lifecycle snapshot commits");

   LifecycleSnapshot readback;
   ok &= a.TS_CHECK(store.ReadLifecycleSnapshot(readback) == STORE_READ_VALID,
                    "Committed lifecycle snapshot validates");
   ok &= a.TS_CHECK(readback.state == POSITION_STATE_IDLE && readback.generation == 1,
                    "First publication selects generation one");

   LifecycleSnapshot unknown = idle;
   unknown.state = POSITION_STATE_UNKNOWN;
   ok &= a.TS_CHECK(!store.WriteLifecycleSnapshot(unknown),
                    "UNKNOWN remains a legacy sentinel and is never committed");
   ok &= a.TS_CHECK(store.ReadLifecycleSnapshot(readback) == STORE_READ_VALID
                    && readback.state == POSITION_STATE_IDLE && readback.generation == 1,
                    "Rejected UNKNOWN replacement preserves the prior generation");

   LifecycleSnapshot contradictory = idle;
   contradictory.position_ticket = (ulong)9911;
   contradictory.position_identifier = (ulong)9911;
   ok &= a.TS_CHECK(!store.WriteLifecycleSnapshot(contradictory),
                    "Internally contradictory IDLE snapshot is rejected before publication");
   ok &= a.TS_CHECK(store.ReadLifecycleSnapshot(readback) == STORE_READ_VALID
                    && readback.state == POSITION_STATE_IDLE && readback.generation == 1,
                    "Rejected replacement preserves the prior committed generation");

   LifecycleSnapshot contradictory_halt = idle;
   contradictory_halt.state = POSITION_STATE_HALT;
   contradictory_halt.halted = true;
   contradictory_halt.position_ticket = (ulong)9911;
   contradictory_halt.position_identifier = (ulong)9911;
   contradictory_halt.pending.ticket = (ulong)9922;
   contradictory_halt.pending.submitted_ts = (datetime)1783167600;
   ok &= a.TS_CHECK(!store.WriteLifecycleSnapshot(contradictory_halt),
                    "HALT cannot publish contradictory position and pending-order ownership");
   ok &= a.TS_CHECK(store.ReadLifecycleSnapshot(readback) == STORE_READ_VALID
                    && readback.state == POSITION_STATE_IDLE && readback.generation == 1,
                    "Rejected contradictory HALT preserves the prior committed generation");

   string inactive_checksum;
   kb.Build(MakeTestId("life0_checksum"), inactive_checksum);
   GlobalVariableSet(inactive_checksum, 123.0);
   ok &= a.TS_CHECK(store.ReadLifecycleSnapshot(readback) == STORE_READ_VALID,
                    "Partial inactive-slot data cannot contradict the active snapshot");

   LifecycleSnapshot pending = idle;
   pending.state = POSITION_STATE_PENDING_CANCEL;
   pending.pending.ticket = (ulong)445566;
   pending.pending.submitted_ts = (datetime)1783167600;
   pending.pending.cancel_requested_ts = (datetime)1783167610;
   pending.pending.cancel_origin = CANCEL_ORIGIN_FRAMEWORK_TIMEOUT;
   ok &= a.TS_CHECK(store.WriteLifecycleSnapshot(pending),
                    "Replacement snapshot verifies before generation publication");
   ok &= a.TS_CHECK(store.ReadLifecycleSnapshot(readback) == STORE_READ_VALID
                    && readback.state == POSITION_STATE_PENDING_CANCEL
                    && readback.pending.ticket == (ulong)445566
                    && readback.generation == 2,
                    "PENDING_CANCEL evidence is read as one internally consistent generation");

   GlobalVariableSet(inactive_checksum, GlobalVariableGet(inactive_checksum) + 1.0);
   ok &= a.TS_CHECK(store.ReadLifecycleSnapshot(readback) == STORE_READ_CORRUPT,
                    "Checksum mismatch is classified as CORRUPT rather than ABSENT");

   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify pending-order persistence stores ticket and submission timestamp together.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_StateStore_PendingOrder(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);

   ulong written_ticket = (ulong)9876543210123;
   datetime written_ts  = (datetime)1783167600;

   ok &= a.TS_CHECK(store.WritePendingOrder(written_ticket, written_ts),
                    "WritePendingOrder returns true");

   ulong read_ticket = (ulong)0;
   datetime read_ts  = (datetime)0;
   ok &= a.TS_CHECK(store.ReadPendingOrder(read_ticket, read_ts),
                    "ReadPendingOrder returns true");
   ok &= a.TS_CHECK_EQ_L((long)read_ticket, (long)written_ticket,
                         "Pending order ticket round-trips exactly");
   ok &= a.TS_CHECK_EQ_L((long)read_ts, (long)written_ts,
                         "Pending order submission timestamp round-trips exactly");

   ok &= a.TS_CHECK(store.ClearPendingOrder(), "ClearPendingOrder returns true");
   ok &= a.TS_CHECK(!store.ReadPendingOrder(read_ticket, read_ts),
                    "ReadPendingOrder returns false after ClearPendingOrder");

   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify marker lease claim, conflict, heartbeat fencing, and release epoch behavior.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_StateStore_MarkerLease(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);

   long token1 = 0;
   ENUM_DUPLICATE_MARKER_STATUS status = DUPLICATE_MARKER_CONFLICT;
   datetime t0 = (datetime)1783167600;

   ok &= a.TS_CHECK(store.MarkerClaimOrReclaim(t0, 60, token1, status),
                    "MarkerClaimOrReclaim returns true on free marker");
   ok &= a.TS_CHECK(token1 > 0, "Free marker claim returns a positive token");
   ok &= a.TS_CHECK(status == DUPLICATE_MARKER_ACTIVE,
                    "Free marker claim status is ACTIVE");
   ok &= a.TS_CHECK(store.MarkerIsOwner(token1),
                    "Claim reports success only after owner and heartbeat publication are revalidated");

   long token_conflict = 0;
   status = DUPLICATE_MARKER_ACTIVE;
   ok &= a.TS_CHECK(store.MarkerClaimOrReclaim(t0 + 10, 60, token_conflict, status),
                    "Fresh owner conflict returns true as handled result");
   ok &= a.TS_CHECK(token_conflict == 0,
                    "Fresh owner conflict returns no token");
   ok &= a.TS_CHECK(status == DUPLICATE_MARKER_CONFLICT,
                    "Fresh owner conflict reports CONFLICT");

   long stale_token = token1;
   ok &= a.TS_CHECK(store.MarkerHeartbeat(token1, t0 + 30),
                    "Current owner can heartbeat");
   long token2 = token1;
   ok &= a.TS_CHECK(token2 == stale_token + 1,
                    "Heartbeat returns advanced owner token to caller");
   ok &= a.TS_CHECK(store.MarkerIsOwner(token2) && !store.MarkerIsOwner(stale_token),
                    "Heartbeat fences the previous token immediately");
   ok &= a.TS_CHECK(!store.MarkerHeartbeat(stale_token, t0 + 31),
                    "Late old token cannot heartbeat after token advanced");
   ok &= a.TS_CHECK(!store.MarkerRelease(stale_token),
                    "Late old token cannot release after token advanced");
   ok &= a.TS_CHECK(store.MarkerRelease(token2),
                    "Current owner can release and preserve epoch");

   long token3 = 0;
   status = DUPLICATE_MARKER_CONFLICT;
   ok &= a.TS_CHECK(store.MarkerClaimOrReclaim(t0 + 40, 60, token3, status),
                    "Released marker can be claimed again");
   ok &= a.TS_CHECK(token3 > token2,
                    "Reclaimed marker token is strictly increasing");
   ok &= a.TS_CHECK(status == DUPLICATE_MARKER_ACTIVE,
                    "Released marker claim reports ACTIVE");

   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify positive owner without heartbeat is treated as conflict/corruption, never as free bootstrap.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_StateStore_MarkerRejectsMissingHeartbeat(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);
   CStateStore store;
   MakeStore(store, kb);
   string owner_key, hb_key;
   kb.Build(MakeTestId("marker_owner"), owner_key);
   kb.Build(MakeTestId("marker_hb_ts"), hb_key);
   GlobalVariableSet(owner_key, 7.0);
   GlobalVariableSet(hb_key, 0.0);
   long token = 0;
   ENUM_DUPLICATE_MARKER_STATUS status = DUPLICATE_MARKER_ACTIVE;
   ok &= a.TS_CHECK(store.MarkerClaimOrReclaim((datetime)1783167600, 60, token, status),
                    "Positive owner with missing heartbeat is handled as a conflict");
   ok &= a.TS_CHECK(token == 0 && status == DUPLICATE_MARKER_CONFLICT,
                    "Corrupt bootstrap evidence returns no ownership token");
   CleanupGVs(kb);
   return(ok);
  }

/** \brief Deterministically prove first-use and CAS-to-heartbeat interleavings never yield two owners.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_StateStore_MarkerInterleavings(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);
   DeterministicMarkerBackend backend;
   CanonicalIdentity base = MakeTestId("");
   string interleave_fp, stolen_fp;
   kb.Build(MakeTestId("marker_interleave_fp"), interleave_fp);
   kb.Build(MakeTestId("marker_stolen_fp"), stolen_fp);
   GlobalVariableDel(interleave_fp);
   GlobalVariableDel(stolen_fp);
   CStateStore owner_a;
   CStateStore owner_b;
   ok &= a.TS_CHECK(owner_a.Init(base, &kb, "marker_interleave", &backend)
                    && owner_b.Init(base, &kb, "marker_interleave", &backend),
                    "Two stores share one deterministic marker backend");
   long token_a = 0, token_b = 0;
   ENUM_DUPLICATE_MARKER_STATUS status_a = DUPLICATE_MARKER_CONFLICT;
   ENUM_DUPLICATE_MARKER_STATUS status_b = DUPLICATE_MARKER_ACTIVE;
   ok &= a.TS_CHECK(owner_a.MarkerClaimOrReclaim((datetime)1000, 60, token_a, status_a)
                    && token_a > 0 && owner_a.MarkerIsOwner(token_a),
                    "First bootstrap claimant owns the fully published marker");
   ok &= a.TS_CHECK(owner_b.MarkerClaimOrReclaim((datetime)1001, 60, token_b, status_b)
                    && token_b == 0 && status_b == DUPLICATE_MARKER_CONFLICT,
                    "Second first-use contender cannot report ownership");
   backend.steal_after_heartbeat = true;
   long heartbeat_token = token_a;
   ok &= a.TS_CHECK(!owner_a.MarkerHeartbeat(heartbeat_token, (datetime)1030)
                    && heartbeat_token == token_a
                    && !owner_a.MarkerIsOwner(token_a),
                    "CAS-to-heartbeat ownership theft cannot report a successful heartbeat owner");

   DeterministicMarkerBackend stolen_backend;
   stolen_backend.steal_after_heartbeat = true;
   CStateStore stolen_claim;
   ok &= a.TS_CHECK(stolen_claim.Init(base, &kb, "marker_stolen", &stolen_backend),
                    "CAS-to-heartbeat fixture initializes");
   long stolen_token = 0;
   ENUM_DUPLICATE_MARKER_STATUS stolen_status = DUPLICATE_MARKER_ACTIVE;
   ok &= a.TS_CHECK(!stolen_claim.MarkerClaimOrReclaim((datetime)2000, 60,
                                                       stolen_token, stolen_status),
                    "Ownership theft between heartbeat publication and reread fails the claim");
   ok &= a.TS_CHECK(stolen_token == 0,
                    "Interleaved claimant never receives a success token");
   GlobalVariableDel(interleave_fp);
   GlobalVariableDel(stolen_fp);
   CleanupGVs(kb);
   return(ok);
  }

/** \brief A transient heartbeat reread mismatch must not release the caller's lease.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_StateStore_MarkerHeartbeatMismatchPreservesOwner(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   DeterministicMarkerBackend backend;
   CanonicalIdentity base = MakeTestId("");
   string fingerprint_key;
   kb.Build(MakeTestId("marker_mismatch_fp"), fingerprint_key);
   GlobalVariableDel(fingerprint_key);

   CStateStore store;
   ok &= a.TS_CHECK(store.Init(base, &kb, "marker_mismatch", &backend),
                    "Transient-mismatch fixture initializes");
   long token = 0;
   ENUM_DUPLICATE_MARKER_STATUS status = DUPLICATE_MARKER_CONFLICT;
   ok &= a.TS_CHECK(store.MarkerClaimOrReclaim((datetime)3000, 60, token, status)
                    && token > 0 && store.MarkerIsOwner(token),
                    "Fixture claims a verified lease");

   long original_token = token;
   backend.transient_heartbeat_read_mismatch = true;
   ok &= a.TS_CHECK(!store.MarkerHeartbeat(token, (datetime)3030),
                    "Transient heartbeat reread mismatch reports failure");
   ok &= a.TS_CHECK(token == original_token && store.MarkerIsOwner(original_token),
                    "Failed heartbeat preserves the caller's positive owner epoch");
   ok &= a.TS_CHECK(store.MarkerRelease(original_token),
                    "Preserved owner can still perform an explicit release");

   GlobalVariableDel(fingerprint_key);
   return(ok);
  }

/** \brief Verify a runtime namespace isolates every generated key from the live store.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_StateStore_RuntimeNamespaceIsolation(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);
   CStateStore live;
   CStateStore isolated;
   CanonicalIdentity base = MakeTestId("");
   ok &= a.TS_CHECK(live.Init(base, &kb), "Live store initializes");
   ok &= a.TS_CHECK(isolated.Init(base, &kb, "pass7"), "Isolated store initializes");
   ok &= a.TS_CHECK(!live.IsRuntimeIsolated(), "Live store reports no runtime isolation");
   ok &= a.TS_CHECK(isolated.IsRuntimeIsolated(), "Namespaced store reports runtime isolation");
   ok &= a.TS_CHECK(isolated.WriteScalar("test_scalar", 7.0),
                    "Isolated store writes its own scalar");
   double live_value = -1.0;
   ok &= a.TS_CHECK(!live.ReadScalar("test_scalar", live_value),
                    "Tester write never appears in the live namespace");
   string isolated_scalar, isolated_fp;
   kb.Build(MakeTestId("pass7_test_scalar"), isolated_scalar);
   kb.Build(MakeTestId("pass7_fp"), isolated_fp);
   if(GlobalVariableCheck(isolated_scalar)) GlobalVariableDel(isolated_scalar);
   if(GlobalVariableCheck(isolated_fp)) GlobalVariableDel(isolated_fp);
   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify stale marker reclaim uses explicit heartbeat timestamp, not access time.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_StateStore_MarkerLease_StaleReclaim(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);

   long token1 = 0;
   ENUM_DUPLICATE_MARKER_STATUS status = DUPLICATE_MARKER_CONFLICT;
   datetime t0 = (datetime)1783167600;
   ok &= a.TS_CHECK(store.MarkerClaimOrReclaim(t0, 60, token1, status),
                    "Initial marker claim succeeds");

//--- Accessing the marker through a second claim attempt must not refresh liveness.
   long no_token = 0;
   status = DUPLICATE_MARKER_ACTIVE;
   ok &= a.TS_CHECK(store.MarkerClaimOrReclaim(t0 + 10, 60, no_token, status),
                    "Fresh conflict check succeeds without taking ownership");
   ok &= a.TS_CHECK(status == DUPLICATE_MARKER_CONFLICT,
                    "Fresh conflict check reports CONFLICT");

   long token2 = 0;
   status = DUPLICATE_MARKER_CONFLICT;
   ok &= a.TS_CHECK(store.MarkerClaimOrReclaim(t0 + 61, 60, token2, status),
                    "Stale marker can be reclaimed after lease_secs");
   ok &= a.TS_CHECK(token2 > token1,
                    "Stale reclaim returns a newer token");
   ok &= a.TS_CHECK(status == DUPLICATE_MARKER_STALE_RECLAIMED,
                    "Stale reclaim reports STALE_RECLAIMED");

   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify fractional marker owner values are treated as lease corruption.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_StateStore_MarkerLeaseRejectsFractionalOwner(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);

   string owner_key, hb_key;
   kb.Build(MakeTestId("marker_owner"), owner_key);
   kb.Build(MakeTestId("marker_hb_ts"), hb_key);

   datetime t0 = (datetime)1783167600;
   GlobalVariableSet(owner_key, -1.5);
   GlobalVariableSet(hb_key, 0.0);

   long token = 0;
   ENUM_DUPLICATE_MARKER_STATUS status = DUPLICATE_MARKER_ACTIVE;
   ok &= a.TS_CHECK(!store.MarkerClaimOrReclaim(t0, 60, token, status),
                    "MarkerClaimOrReclaim rejects fractional free owner epoch");
   ok &= a.TS_CHECK(token == 0, "Fractional free owner returns no token");

   GlobalVariableSet(owner_key, 1.5);
   GlobalVariableSet(hb_key, (double)(t0 - 120));
   status = DUPLICATE_MARKER_CONFLICT;
   ok &= a.TS_CHECK(!store.MarkerClaimOrReclaim(t0, 60, token, status),
                    "MarkerClaimOrReclaim rejects fractional stale owner token");
   ok &= a.TS_CHECK(token == 0, "Fractional stale owner returns no token");

   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify CStateStore.Verify() fails after fingerprint corruption (StateCorruption scenario). */
bool Test_StateStore_VerifyFailOnCorruption(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);
   ok &= a.TS_CHECK(store.Verify(), "Verify passes initially");

//--- Manually corrupt the fingerprint GV.
   string fp_key;
   kb.Build(MakeTestId("fp"), fp_key);
   GlobalVariableSet(fp_key, -1.0); // -1.0 is never a valid fingerprint (always ≥ 0)

   ok &= a.TS_CHECK(!store.Verify(), "Verify fails after fingerprint corruption (StateCorruption)");

   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify CStateStore.Init() returns false on fingerprint mismatch (StateCorruption guard). */
bool Test_StateStore_InitMismatch(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

//--- Pre-set the fingerprint GV to an obviously wrong value.
   string fp_key;
   kb.Build(MakeTestId("fp"), fp_key);
   GlobalVariableSet(fp_key, -99.0);

//--- Init should detect the mismatch and return false.
   CStateStore store;
   ok &= a.TS_CHECK(!MakeStore(store, kb),
                    "Init() returns false on fingerprint mismatch (StateCorruption guard)");

   CleanupGVs(kb);
   return(ok);
  }

/** \brief Verify IsDuplicate() is a pure read: it neither creates nor overwrites GVs. */
bool Test_StateStore_LowIO(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);

//--- Proof 1: IsDuplicate on an unset key must not create the GV.
   string key_unset;
   kb.Build(MakeTestId("dup_xyz"), key_unset);
   ok &= a.TS_CHECK(!store.IsDuplicate("xyz"),       "IsDuplicate false for unset key");
   ok &= a.TS_CHECK(!GlobalVariableCheck(key_unset), "IsDuplicate on unset key creates no GV");

//--- Proof 2: IsDuplicate must not overwrite an existing GV.
//--- SetDuplicate writes 1.0; replace with sentinel 2.0 (still ≥ 0.5 so IsDuplicate is true).
//--- If IsDuplicate erroneously called SetDuplicate or GlobalVariableSet, the 2.0 would
//--- be overwritten with 1.0, which the final assertion would catch.
   store.SetDuplicate("xyz");
   GlobalVariableSet(key_unset, 2.0); // sentinel differs from the 1.0 that SetDuplicate writes

   ok &= a.TS_CHECK(store.IsDuplicate("xyz"), "IsDuplicate true for sentinel value");
   ok &= a.TS_CHECK(store.IsDuplicate("xyz"), "IsDuplicate true on repeated call");

   double sentinel_val = GlobalVariableGet(key_unset);
   ok &= a.TS_CHECK(sentinel_val == 2.0,
                    "IsDuplicate does not rewrite the GV (sentinel 2.0 preserved)");

   CleanupGVs(kb);
   return(ok);
  }

/**
 * \brief Verify CKeyBuilder encodes magic > LONG_MAX as unsigned decimal,
 *        producing a 19-char key with uppercase-only hex digits.
 */
bool Test_KeyBuilder_LargeMagic(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;

//--- Use a magic value above LONG_MAX (0x8000000000000000).
//--- Build via bit-shift to avoid unsupported UL literal suffix.
   ulong large_magic = ((ulong)0x80000000 << 32); // 0x8000000000000000

   CanonicalIdentity id;
   id.account = 0;
   id.symbol  = "TSTEST";
   id.magic   = large_magic;
   id.scope   = "halt";

   string key1, key2;
   ok &= a.TS_CHECK(kb.Build(id, key1), "Build with large magic succeeds");
   ok &= a.TS_CHECK(kb.Build(id, key2), "Second Build with large magic succeeds (deterministic)");
   ok &= a.TS_CHECK_EQ_STR(key1, key2,  "Large magic key is deterministic");
   ok &= a.TS_CHECK(StringLen(key1) == 19, "Large magic key is exactly 19 chars");
   ok &= a.TS_CHECK(StringSubstr(key1, 0, 3) == "ts_", "Large magic key has 'ts_' prefix");

//--- All 16 hex digits must be uppercase [0-9A-F].
   string hex_part = StringSubstr(key1, 3);
   bool all_upper_hex = true;
   for(int i = 0; i < StringLen(hex_part); i++)
     {
      ushort c = StringGetCharacter(hex_part, i);
      if(!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F')))
        {
         all_upper_hex = false;
         break;
        }
     }
   ok &= a.TS_CHECK(all_upper_hex, "Key hex digits are all uppercase [0-9A-F]");

//--- Large magic must produce a different key than small magic.
   CanonicalIdentity id_small = id;
   id_small.magic = 42;
   string key_small;
   kb.Build(id_small, key_small);
   ok &= a.TS_CHECK(key1 != key_small, "Large magic key differs from small magic key");

//--- Fingerprint with large magic stays within [0, 2^53-1].
   double fp = kb.Fingerprint(id);
   ok &= a.TS_CHECK(fp >= 0.0,               "Fingerprint with large magic is non-negative");
   ok &= a.TS_CHECK(fp <= 9007199254740991.0, "Fingerprint with large magic ≤ 2^53-1");
   ok &= a.TS_CHECK(fp == (double)(long)fp,   "Fingerprint with large magic is exact double integer");

//--- Known-vector assertions: these exact values pin the %I64u + %016I64X contract.
//--- Input: "0|TSTEST|9223372036854775808|halt"
//--- If the unsigned-magic fix reverted to IntegerToString((long)magic), the pre-hash
//--- string would be "0|TSTEST|-9223372036854775808|halt" and produce a different key.
   ok &= a.TS_CHECK_EQ_STR(key1, "ts_B19B1FFA609D0940",
                            "Known-vector key for 0|TSTEST|9223372036854775808|halt");
//--- Scope-free fingerprint: FNV1a64("0|TSTEST|9223372036854775808") & (2^53-1)
   ok &= a.TS_CHECK_EQ_D(fp, 7871618290286861.0, 0.0,
                          "Known-vector fingerprint for 0|TSTEST|9223372036854775808");

   return(ok);
  }

/** \brief Read all lines of a text file and return the concatenated content. */
string ReadHaltFile(string path)
  {
   int fh = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(fh == INVALID_HANDLE)
      return("");
   string content = "";
   while(!FileIsEnding(fh))
      content += FileReadString(fh) + "\n";
   FileClose(fh);
   return(content);
  }

/** \brief Verify HALT filename sanitises '/' in symbol names to prevent subdirectory traversal. */
bool Test_StateStore_Halt_PathSymbol(CAssert &a)
  {
   bool ok = true;

   CanonicalIdentity id;
   id.account = TEST_ACCOUNT;
   id.symbol  = "TST/EST"; // forward slash in symbol name
   id.magic   = TEST_MAGIC;
   id.scope   = "";

   CKeyBuilder kb;
   CStateStore store;
   ok &= a.TS_CHECK(store.Init(id, &kb), "Init with path-like symbol succeeds");

   HaltEvidence ev;
   ev.reason           = "PathSymbol HALT test";
   ev.last_known_state = POSITION_STATE_ACTIVE;
   ev.operator_action  = "Verify and restart";
   ev.symbol           = "TST/EST";
   ev.magic            = TEST_MAGIC;
   ev.ticket           = (ulong)0;

   ok &= a.TS_CHECK(store.SetHalt(ev), "SetHalt with path-like symbol returns true");

   string sanitized_file   = "TradeSpine/Halt_" + StringFormat("%I64u", TEST_MAGIC) + "_TST_EST.txt";
   string unsanitized_file = "TradeSpine/Halt_" + StringFormat("%I64u", TEST_MAGIC) + "_TST/EST.txt";

   ok &= a.TS_CHECK(FileIsExist(sanitized_file),
                    "HALT file at sanitized path (/ replaced with _)");
   ok &= a.TS_CHECK(!FileIsExist(unsanitized_file),
                    "No HALT file at unsanitized path (no subdirectory traversal)");

//--- Cleanup: delete evidence file and GVs created for this non-standard identity.
   FileDelete(sanitized_file);
   string fp_key, halt_key;
   id.scope = "fp";        kb.Build(id, fp_key);
   id.scope = "halt_flag"; kb.Build(id, halt_key);
   GlobalVariableDel(fp_key);
   GlobalVariableDel(halt_key);

   return(ok);
  }

/** \brief Verify HALT payload sanitises embedded newlines to prevent injection into evidence files. */
bool Test_StateStore_Halt_PayloadEscape(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);

   HaltEvidence ev;
   ev.reason           = "line1\nline2";           // embedded LF must be stripped
   ev.last_known_state = POSITION_STATE_ACTIVE;
   ev.operator_action  = "action\r\nwith\nnewlines"; // embedded CRLF and LF must be stripped
   ev.symbol           = TEST_SYMBOL;
   ev.magic            = TEST_MAGIC;
   ev.ticket           = (ulong)0;

   ok &= a.TS_CHECK(store.SetHalt(ev), "SetHalt with newlines in payload returns true");

   string halt_file = "TradeSpine/Halt_" + StringFormat("%I64u", TEST_MAGIC) + "_" + TEST_SYMBOL + ".txt";
   ok &= a.TS_CHECK(FileIsExist(halt_file), "HALT evidence file exists");

//--- Read lines one by one; count only non-empty ones.
   int fh = FileOpen(halt_file, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   int line_count = 0;
   if(fh != INVALID_HANDLE)
     {
      while(!FileIsEnding(fh))
        {
         string line = FileReadString(fh);
         if(StringLen(line) > 0)
            line_count++;
        }
      FileClose(fh);
     }
   ok &= a.TS_CHECK(line_count == 7,
                    "HALT file has exactly 7 lines (no injected lines from payload newlines)");

//--- Positive check: reason payload newline was replaced with space, not silently dropped.
   string content = ReadHaltFile(halt_file);
   ok &= a.TS_CHECK(StringFind(content, "reason=line1 line2") >= 0,
                    "Reason newline replaced with space in HALT evidence");

   CleanupGVs(kb);
   return(ok);
  }

//+------------------------------------------------------------------+
//| TDD/BDD trace-alias entry points called by RunAllTests.          |
//+------------------------------------------------------------------+

/** \brief TDD.05.04.e64a — canonical unit contract for CKeyBuilder and CStateStore. */
bool test_persistence_and_audit_evidence_unit_contract(CAssert &a)
  {
   bool ok = true;
   ok &= Test_KeyBuilder_Determinism(a);
   ok &= Test_KeyBuilder_ScopeIsolation(a);
   ok &= Test_KeyBuilder_Verify(a);
   ok &= Test_KeyBuilder_Fingerprint(a);
   ok &= Test_KeyBuilder_LargeMagic(a);
   ok &= Test_StateStore_Init(a);
   ok &= Test_StateStore_Scalar(a);
   ok &= Test_StateStore_Duplicate(a);
   ok &= Test_StateStore_Halt(a);
   ok &= Test_StateStore_ClearHalt(a);
   ok &= Test_StateStore_Halt_LargeMagic(a);
   ok &= Test_StateStore_Halt_PathSymbol(a);
   ok &= Test_StateStore_Halt_PayloadEscape(a);
   ok &= Test_StateStore_Ticket(a);
   ok &= Test_StateStore_SplitIdRejectsCorruptParts(a);
   ok &= Test_StateStore_LifecycleSnapshot(a);
   ok &= Test_StateStore_PendingOrder(a);
   ok &= Test_StateStore_MarkerLease(a);
   ok &= Test_StateStore_MarkerLease_StaleReclaim(a);
   ok &= Test_StateStore_MarkerLeaseRejectsFractionalOwner(a);
   ok &= Test_StateStore_MarkerRejectsMissingHeartbeat(a);
   ok &= Test_StateStore_MarkerInterleavings(a);
   ok &= Test_StateStore_MarkerHeartbeatMismatchPreservesOwner(a);
   ok &= Test_StateStore_RuntimeNamespaceIsolation(a);
   ok &= Test_StateStore_VerifyFailOnCorruption(a);
   ok &= Test_StateStore_InitMismatch(a);
   ok &= Test_StateStore_LowIO(a);
   return(ok);
  }

/** \brief BDD.01.03.0073 — guarded order writes duplicate + HALT markers. */
bool test_persistence_and_audit_evidence_0073_unit(CAssert &a)
  {
   bool ok = true;
   ok &= Test_StateStore_Duplicate(a);
   ok &= Test_StateStore_Halt(a);
   ok &= Test_StateStore_ClearHalt(a);
   ok &= Test_StateStore_Halt_LargeMagic(a);
   ok &= Test_StateStore_Halt_PathSymbol(a);
   ok &= Test_StateStore_Halt_PayloadEscape(a);
   return(ok);
  }

/** \brief BDD.01.03.d6ae — state-side scope isolation (records remain separated). */
bool test_persistence_and_audit_evidence_d6ae_unit(CAssert &a)
  {
   return(Test_KeyBuilder_ScopeIsolation(a));
  }

/** \brief BDD.01.03.e16a — ambiguous evidence triggers StateCorruption detection. */
bool test_persistence_and_audit_evidence_e16a_unit(CAssert &a)
  {
   bool ok = true;
   ok &= Test_StateStore_VerifyFailOnCorruption(a);
   ok &= Test_StateStore_InitMismatch(a);
   return(ok);
  }

/** \brief BDD.01.03.b37d — GV operations stay bounded (low-I/O requirement). */
bool test_persistence_and_audit_evidence_b37d_unit(CAssert &a)
  {
   return(Test_StateStore_LowIO(a));
  }

//+------------------------------------------------------------------+
//| Script entry point.                                              |
//| Returns 0=all pass, 1=any failure, 2=pass but skips present.    |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_RUN_ALL_TESTS
int OnStart()
  {
   CAssert asserts;
   asserts.Reset();
   Print("== Test_StateStore ==");
   Test_KeyBuilder_Determinism(asserts);
   Test_KeyBuilder_ScopeIsolation(asserts);
   Test_KeyBuilder_Verify(asserts);
   Test_KeyBuilder_Fingerprint(asserts);
   Test_KeyBuilder_LargeMagic(asserts);
   Test_StateStore_Init(asserts);
   Test_StateStore_Scalar(asserts);
   Test_StateStore_Duplicate(asserts);
   Test_StateStore_Halt(asserts);
   Test_StateStore_ClearHalt(asserts);
   Test_StateStore_Halt_LargeMagic(asserts);
   Test_StateStore_Halt_PathSymbol(asserts);
   Test_StateStore_Halt_PayloadEscape(asserts);
   Test_StateStore_Ticket(asserts);
   Test_StateStore_SplitIdRejectsCorruptParts(asserts);
   Test_StateStore_LifecycleSnapshot(asserts);
   Test_StateStore_PendingOrder(asserts);
   Test_StateStore_MarkerLease(asserts);
   Test_StateStore_MarkerLease_StaleReclaim(asserts);
   Test_StateStore_MarkerLeaseRejectsFractionalOwner(asserts);
   Test_StateStore_MarkerRejectsMissingHeartbeat(asserts);
   Test_StateStore_MarkerInterleavings(asserts);
   Test_StateStore_MarkerHeartbeatMismatchPreservesOwner(asserts);
   Test_StateStore_RuntimeNamespaceIsolation(asserts);
   Test_StateStore_VerifyFailOnCorruption(asserts);
   Test_StateStore_InitMismatch(asserts);
   Test_StateStore_LowIO(asserts);
   bool pass = asserts.TS_REPORT_SUMMARY("Test_StateStore");
   if(!pass)
      return(1);
   if(asserts.TestsSkipped() > 0)
      return(2);
   return(0);
  }
#endif
//+------------------------------------------------------------------+
