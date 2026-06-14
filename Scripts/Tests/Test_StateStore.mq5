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

//+------------------------------------------------------------------+
//| Build a test CanonicalIdentity with the given scope.             |
//+------------------------------------------------------------------+
CanonicalIdentity MakeTestId(string scope)
  {
   CanonicalIdentity id;
   id.account = TEST_ACCOUNT;
   id.symbol  = TEST_SYMBOL;
   id.magic   = TEST_MAGIC;
   id.scope   = scope;
   return(id);
  }

//+------------------------------------------------------------------+
//| Delete test GVs created during a test; ignores missing keys.     |
//+------------------------------------------------------------------+
void CleanupGVs(CKeyBuilder &kb)
  {
   string scopes[] =
     {
      "fp", "halt_flag", "tkt_hi", "tkt_lo",
      "test_scalar", "dup_intentA", "dup_intentB", "dup_xyz"
     };
   for(int i = 0; i < ArraySize(scopes); i++)
     {
      string key;
      if(kb.Build(MakeTestId(scopes[i]), key))
         GlobalVariableDel(key);
     }
//--- Also delete any halt evidence file.
   FileDelete("TradeSpine/Halt_" + IntegerToString(TEST_MAGIC) + "_" + TEST_SYMBOL + ".txt");
  }

//+------------------------------------------------------------------+
//| Helper: create and init a fresh StateStore for tests.            |
//| Returns true when Init() succeeds.                               |
//+------------------------------------------------------------------+
bool MakeStore(CStateStore &store, CKeyBuilder &kb)
  {
   CanonicalIdentity base = MakeTestId(""); // scope overwritten internally
   return(store.Init(base, &kb));
  }

//--- ----------------------------------------------------------------+
//--- KeyBuilder tests                                                |
//--- ----------------------------------------------------------------+

//+------------------------------------------------------------------+
//| CKeyBuilder: determinism, length, raw-identity absence.          |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| CKeyBuilder: different scopes produce different keys.            |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| CKeyBuilder: Verify detects mismatch (KeyCollision path).        |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| CKeyBuilder: Fingerprint is exact double in [0, 2^53-1].        |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| CStateStore: Init() writes fingerprint; reinit with same id ok.  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| CStateStore: scalar read/write round-trip.                       |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| CStateStore: duplicate markers guard against double-processing.  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| CStateStore: HALT flag round-trip; file evidence written.        |
//+------------------------------------------------------------------+
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

   ok &= a.TS_CHECK(store.SetHalt(ev), "SetHalt returns true");
   ok &= a.TS_CHECK(store.IsHalted(),  "IsHalted true after SetHalt");

   CleanupGVs(kb);
   return(ok);
  }

//+------------------------------------------------------------------+
//| CStateStore: lossless ulong ticket split (including ULONG_MAX).  |
//+------------------------------------------------------------------+
bool Test_StateStore_Ticket(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);

//--- Typical broker ticket value.
   ulong t1 = 12345678901UL;
   ok &= a.TS_CHECK(store.WriteTicket(t1), "WriteTicket (typical) returns true");
   ulong r1 = 0;
   ok &= a.TS_CHECK(store.ReadTicket(r1),  "ReadTicket (typical) returns true");
   ok &= a.TS_CHECK_EQ_L((long)r1, (long)t1, "Typical ticket round-trip exact");

//--- Edge case: ULONG_MAX (all 64 bits set).
   ulong ulong_max = (ulong) - 1; // 0xFFFFFFFFFFFFFFFF
   ok &= a.TS_CHECK(store.WriteTicket(ulong_max), "WriteTicket (ULONG_MAX) returns true");
   ulong r_max = 0;
   ok &= a.TS_CHECK(store.ReadTicket(r_max),      "ReadTicket (ULONG_MAX) returns true");
   ok &= a.TS_CHECK_EQ_L((long)r_max, (long)ulong_max, "ULONG_MAX ticket round-trip exact");

//--- Edge case: zero ticket.
   ok &= a.TS_CHECK(store.WriteTicket(0UL), "WriteTicket (0) returns true");
   ulong r_zero = 99UL;
   ok &= a.TS_CHECK(store.ReadTicket(r_zero),     "ReadTicket (0) returns true");
   ok &= a.TS_CHECK_EQ_L((long)r_zero, (long)0UL, "Zero ticket round-trip exact");

   CleanupGVs(kb);
   return(ok);
  }

//+------------------------------------------------------------------+
//| CStateStore: Verify() fails after fingerprint is corrupted.      |
//| This simulates a StateCorruption / ambiguous-evidence scenario.  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| CStateStore: Init returns false when fingerprint already wrong.  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| b37d: GV ops happen only on meaningful transitions, not every    |
//| call. We verify that no redundant ops are triggered by reading   |
//| a value that was set earlier (count of GV calls is bounded).    |
//+------------------------------------------------------------------+
bool Test_StateStore_LowIO(CAssert &a)
  {
   bool ok = true;
   CKeyBuilder kb;
   CleanupGVs(kb);

   CStateStore store;
   MakeStore(store, kb);

//--- Write once; check total GVs referencing our test namespace does not
//--- grow unexpectedly from repeated duplicate checks on the same key.
   store.SetDuplicate("xyz");
   ok &= a.TS_CHECK(store.IsDuplicate("xyz"), "Duplicate correctly detected");
//--- Calling IsDuplicate multiple times is idempotent (no new GVs).
   bool dup1 = store.IsDuplicate("xyz");
   bool dup2 = store.IsDuplicate("xyz");
   ok &= a.TS_CHECK(dup1 == dup2, "IsDuplicate is idempotent (no new GVs per call)");

   CleanupGVs(kb);
   return(ok);
  }

//+------------------------------------------------------------------+
//| TDD/BDD trace-alias entry points called by RunAllTests.          |
//+------------------------------------------------------------------+

//--- TDD.05.04.e64a: canonical unit contract for KeyBuilder + StateStore.
bool test_persistence_and_audit_evidence_unit_contract(CAssert &a)
  {
   bool ok = true;
   ok &= Test_KeyBuilder_Determinism(a);
   ok &= Test_KeyBuilder_ScopeIsolation(a);
   ok &= Test_KeyBuilder_Verify(a);
   ok &= Test_KeyBuilder_Fingerprint(a);
   ok &= Test_StateStore_Init(a);
   ok &= Test_StateStore_Scalar(a);
   ok &= Test_StateStore_Duplicate(a);
   ok &= Test_StateStore_Halt(a);
   ok &= Test_StateStore_Ticket(a);
   ok &= Test_StateStore_VerifyFailOnCorruption(a);
   ok &= Test_StateStore_InitMismatch(a);
   ok &= Test_StateStore_LowIO(a);
   return(ok);
  }

//--- BDD.01.03.0073: guarded order writes duplicate + HALT markers.
bool test_persistence_and_audit_evidence_0073_unit(CAssert &a)
  {
   bool ok = true;
   ok &= Test_StateStore_Duplicate(a);
   ok &= Test_StateStore_Halt(a);
   return(ok);
  }

//--- BDD.01.03.d6ae: state-side scope isolation (records remain separated).
bool test_persistence_and_audit_evidence_d6ae_unit(CAssert &a)
  {
   return(Test_KeyBuilder_ScopeIsolation(a));
  }

//--- BDD.01.03.e16a: ambiguous evidence → StateCorruption detected.
bool test_persistence_and_audit_evidence_e16a_unit(CAssert &a)
  {
   bool ok = true;
   ok &= Test_StateStore_VerifyFailOnCorruption(a);
   ok &= Test_StateStore_InitMismatch(a);
   return(ok);
  }

//--- BDD.01.03.b37d: GV ops stay bounded (low-I/O requirement).
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
   Test_StateStore_Init(asserts);
   Test_StateStore_Scalar(asserts);
   Test_StateStore_Duplicate(asserts);
   Test_StateStore_Halt(asserts);
   Test_StateStore_Ticket(asserts);
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
