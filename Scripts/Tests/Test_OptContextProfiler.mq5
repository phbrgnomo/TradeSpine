//+------------------------------------------------------------------+
//|                                      Test_OptContextProfiler.mq5 |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_OptContextProfiler.mq5                |
//| @tdd: TDD.09.04.8050  @spec: SPEC-09  @iplan: IPLAN-09           |
//|                                                                  |
//| Tier-1 integration tests for COptContext + CProfiler gating.       |
//| Optimization unconditionally silences all non-core work;         |
//| there is no audit_in_optimization override.                      |
//| No broker execution APIs.                                        |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-09 - COptContext and CProfiler tests"
#include "../../Include/Testing/Assert.mqh"
#include "../../Include/Core/Interfaces.mqh"
#include "../../Include/Core/OptContext.mqh"
#include "../../Include/Core/Profiler.mqh"

//+------------------------------------------------------------------+
//| Local test double for ILogSink.                                  |
//| Keep local until another test file needs the same fake; shared   |
//| test doubles belong under Scripts/Tests/Support, never Core.     |
//+------------------------------------------------------------------+
class CapturingLogSink : public ILogSink
  {
private:
   int    m_count;
   string m_last;

public:
   CapturingLogSink(void)
     {
      m_count = 0;
      m_last  = "";
     }

   void Write(const ENUM_LOG_LEVEL level, const string category, const string message) override
     {
      m_count++;
      m_last = StringFormat("[%d] %s: %s", (int)level, category, message);
     }

   int Count(void) const
     {
      return(m_count);
     }

   string Last(void) const
     {
      return(m_last);
     }

   void Reset(void)
     {
      m_count = 0;
      m_last  = "";
     }
  };

//+------------------------------------------------------------------+
//| Helper: build a RuntimeMode.                                     |
//+------------------------------------------------------------------+
RuntimeMode MakeMode(const bool tester, const bool optimization)
  {
   RuntimeMode m;
   m.is_tester           = tester;
   m.is_optimization     = optimization;
   m.diagnostics_enabled = !optimization; // optimization silences; otherwise allow diagnostics
   return(m);
  }

//+------------------------------------------------------------------+
//| Optimization unconditionally gates all high-I/O work.            |
//+------------------------------------------------------------------+
bool Test_OptimizationGated(CAssert &asserts)
  {
   bool ok = true;
   RuntimeMode mode = MakeMode(true, true);
   COptContext ctx(mode);

   ok &= asserts.CheckFalse(ctx.AllowsHighVolumeEvidence(),
                    "High-volume evidence disabled in optimization");
   ok &= asserts.CheckFalse(ctx.AllowsDiagnostics(), "Diagnostics disabled in optimization");
   ok &= asserts.CheckFalse(ctx.AllowsProfiler(),    "CProfiler disabled in optimization");
   ok &= asserts.Check(ctx.IsOptimizing(),           "IsOptimizing true");
   ok &= asserts.Check(ctx.IsTesting(),              "IsTesting true");
   return(ok);
  }

//+------------------------------------------------------------------+
//| Plain tester enables profiler; live disables it by default.      |
//+------------------------------------------------------------------+
bool Test_TesterVsLive(CAssert &asserts)
  {
   bool ok = true;
   RuntimeMode tester = MakeMode(true, false);
   COptContext ctx_t(tester);
   ok &= asserts.Check(ctx_t.AllowsProfiler(),    "CProfiler on by default in plain tester");
   ok &= asserts.Check(ctx_t.AllowsDiagnostics(), "Diagnostics on in plain tester");

   RuntimeMode live = MakeMode(false, false);
   COptContext ctx_l(live);
   ok &= asserts.CheckFalse(ctx_l.AllowsProfiler(), "CProfiler off by default in live");
   ok &= asserts.Check(ctx_l.IsLive(),              "IsLive true off-tester");
   return(ok);
  }

//+------------------------------------------------------------------+
//| Disabled profiler performs no persistent writes (BDD.01.03.b37d).|
//+------------------------------------------------------------------+
bool Test_ProfilerNoWriteWhenGated(CAssert &asserts)
  {
   bool ok = true;
   RuntimeMode mode = MakeMode(true, true); // optimization -> all gated
   COptContext ctx(mode);
   CapturingLogSink sink;
   CProfiler prof(GetPointer(ctx), GetPointer(sink));

   prof.Start("entry_pipeline");
   prof.Stop("entry_pipeline");
   prof.PrintResults();

   ok &= asserts.CheckEqualL((long)sink.Count(), 0,
                     "Gated profiler issued no log writes");
   ProfileSample s = prof.GetSample("entry_pipeline");
   ok &= asserts.CheckFalse(s.enabled,        "Gated sample reports enabled=false");
   ok &= asserts.CheckEqualL(s.elapsed_us, 0, "Gated sample reports zero elapsed");
   ok &= asserts.CheckFalse(prof.IsActive(),  "CProfiler.IsActive false under gated policy");
   return(ok);
  }

//+------------------------------------------------------------------+
//| Active profiler records a sample and can emit evidence.          |
//+------------------------------------------------------------------+
bool Test_ProfilerActiveRecords(CAssert &asserts)
  {
   bool ok = true;
   RuntimeMode mode = MakeMode(true, false); // plain tester -> profiler on
   COptContext ctx(mode);
   CapturingLogSink sink;
   CProfiler prof(GetPointer(ctx), GetPointer(sink));

   ok &= asserts.Check(prof.IsActive(), "CProfiler active in plain tester");
   prof.Start("calc");
   long acc = 0;
   for(int i = 0; i < 1000; i++)
      acc += i;
   prof.Stop("calc");

   ProfileSample s = prof.GetSample("calc");
   ok &= asserts.Check(s.enabled,         "Active sample reports enabled=true");
   ok &= asserts.Check(s.elapsed_us >= 0, "Active sample elapsed is non-negative");
   prof.PrintResults();
   ok &= asserts.Check(sink.Count() >= 1, "Active profiler emitted evidence to the sink");
   ok &= asserts.Check(StringFind(sink.Last(), "[1]") >= 0,
               "PrintResults writes at LOG_INFO (level 1)");
   return(ok);
  }

//+------------------------------------------------------------------+
//| Memory-evidence baseline-and-delta harness (SPEC-09/EARS.01.03.8044).|
//| Verifies scenario propagation, non-negative MQL-program memory,  |
//| and terminal build context in timing_source.                     |
//| Native TerminalInfoInteger used directly for the expected build  |
//| string so the profiler path stays dependency-light.              |
//+------------------------------------------------------------------+
bool Test_ProfilerMemoryEvidence(CAssert &asserts)
  {
   bool ok = true;
   RuntimeMode mode = MakeMode(true, false); // plain tester -> profiler on
   COptContext ctx(mode);
   CProfiler prof(GetPointer(ctx));

   int build = (int)TerminalInfoInteger(TERMINAL_BUILD);

   long baseline = prof.CaptureBaselineMemory();
   BenchmarkBaseline b = prof.GetBenchmarkData("bench_test", baseline);

   ok &= asserts.CheckEqualStr(b.scenario, "bench_test",
                       "Scenario name propagates to benchmark record");
   ok &= asserts.Check(b.baseline_memory >= 0,
               "MQL program memory baseline is non-negative (MB)");
   ok &= asserts.Check(StringFind(b.timing_source, "GetMicrosecondCount") == 0,
               "Timing source starts with GetMicrosecondCount");
   ok &= asserts.Check(StringFind(b.timing_source,
               StringFormat("build=%d", build)) >= 0,
               "Timing source encodes the actual terminal build number");
   return(ok);
  }

//+------------------------------------------------------------------+
//| Duplicate Stop() must not overwrite the recorded elapsed time.   |
//+------------------------------------------------------------------+
bool Test_ProfilerNoDuplicateStop(CAssert &asserts)
  {
   bool ok = true;
   RuntimeMode mode = MakeMode(true, false);
   COptContext ctx(mode);
   CProfiler prof(GetPointer(ctx));

   prof.Start("x");
   long acc = 0;
   for(int i = 0; i < 500; i++)
      acc += i;            // small workload to ensure non-zero elapsed
   prof.Stop("x");
   ProfileSample s1 = prof.GetSample("x");

   prof.Stop("x");         // duplicate stop — must be a no-op
   ProfileSample s2 = prof.GetSample("x");

   ok &= asserts.Check(s1.enabled,             "First Stop records an enabled sample");
   ok &= asserts.CheckEqualL(s2.elapsed_us, s1.elapsed_us,
                     "Duplicate Stop() does not overwrite the recorded elapsed time");
   return(ok);
  }

//+------------------------------------------------------------------+
//| Scope-cap overflow emits exactly one gated diagnostic.           |
//+------------------------------------------------------------------+
bool Test_ProfilerScopeOverflow(CAssert &asserts)
  {
   bool ok = true;
   RuntimeMode mode = MakeMode(true, false);
   COptContext ctx(mode);
   CapturingLogSink sink;
   CProfiler prof(GetPointer(ctx), GetPointer(sink));

   // Fill every slot
   for(int i = 0; i < PROFILER_MAX_SCOPES; i++)
      prof.Start(StringFormat("scope_%d", i));

   int before = sink.Count();
   prof.Start("overflow_trigger"); // one beyond cap
   ok &= asserts.Check(sink.Count() > before,
               "Overflow diagnostic emitted when scope cap exceeded");
   ok &= asserts.Check(StringFind(sink.Last(), "[2]") >= 0,
               "Overflow diagnostic written at LOG_WARN (level 2)");

   prof.Start("overflow_trigger2"); // second overflow — no second diagnostic
   ok &= asserts.CheckEqualL((long)(sink.Count() - before), 1,
                     "Overflow diagnostic fires exactly once");
   return(ok);
  }

//+------------------------------------------------------------------+
//| M1: injected diagnostics_enabled=false is honored outside        |
//| optimization. CProfiler policy (tester/non-opt) is independent   |
//| of the diagnostics flag.                                         |
//+------------------------------------------------------------------+
bool Test_DiagnosticsInjectedDisabled(CAssert &asserts)
  {
   bool ok = true;
   RuntimeMode mode;
   mode.is_tester           = true;
   mode.is_optimization     = false;
   mode.diagnostics_enabled = false; // explicitly disabled outside optimization
   COptContext ctx(mode);

   ok &= asserts.CheckFalse(ctx.AllowsDiagnostics(),
                    "Injected diagnostics_enabled=false honored outside optimization");
   ok &= asserts.Check(ctx.AllowsProfiler(),
               "CProfiler policy (tester, non-opt) unaffected by diagnostics flag");
   ok &= asserts.CheckFalse(ctx.IsOptimizing(), "Mode is not optimization");
   ok &= asserts.Check(ctx.IsTesting(),         "Mode is tester");
   return(ok);
  }

//+------------------------------------------------------------------+
//| L1: PROFILER macros must not evaluate the scope argument when    |
//| the profiler is NULL or inactive. A side-effecting expression    |
//| (++counter) proves the argument is never computed.               |
//+------------------------------------------------------------------+
bool Test_MacroNoEvalWhenInactive(CAssert &asserts)
  {
   bool ok = true;
   int counter = 0;

   // Case 1: g_profiler == NULL — body never executes.
   g_profiler = NULL;
   PROFILER_START("s" + IntegerToString(++counter));
   PROFILER_STOP( "s" + IntegerToString(++counter));
   ok &= asserts.CheckEqualL((long)counter, 0,
                     "PROFILER macros do not evaluate scope when g_profiler is NULL");

   // Case 2: profiler exists but IsActive()==false — scope still not evaluated.
   RuntimeMode mode = MakeMode(true, true); // optimization -> inactive
   COptContext ctx(mode);
   CProfiler inactive_prof(GetPointer(ctx));
   g_profiler = GetPointer(inactive_prof);
   ok &= asserts.CheckFalse(g_profiler.IsActive(), "Fixture profiler is inactive under optimization");

   counter = 0;
   PROFILER_START("s" + IntegerToString(++counter));
   PROFILER_STOP( "s" + IntegerToString(++counter));
   ok &= asserts.CheckEqualL((long)counter, 0,
                     "PROFILER macros do not evaluate scope when profiler is inactive");

   g_profiler = NULL; // release before inactive_prof goes out of scope
   return(ok);
  }

//+------------------------------------------------------------------+
//| TDD trace aliases.                                               |
//+------------------------------------------------------------------+
bool test_core_runtime_and_configuration_integration_contract(CAssert &asserts)
  {
   return(Test_OptimizationGated(asserts) && Test_ProfilerNoWriteWhenGated(asserts) &&
          Test_ProfilerMemoryEvidence(asserts) && Test_ProfilerNoDuplicateStop(asserts) &&
          Test_ProfilerScopeOverflow(asserts) && Test_DiagnosticsInjectedDisabled(asserts) &&
          Test_MacroNoEvalWhenInactive(asserts));
  }
bool test_core_runtime_and_configuration_aa68_integration(CAssert &asserts) { return(Test_TesterVsLive(asserts)); }
bool test_core_runtime_and_configuration_b37d_unit(CAssert &asserts)        { return(Test_ProfilerNoWriteWhenGated(asserts)); }
bool test_core_runtime_and_configuration_b37d_integration(CAssert &asserts) { return(Test_ProfilerActiveRecords(asserts) && Test_ProfilerMemoryEvidence(asserts)); }
bool test_core_runtime_and_configuration_cb03_integration(CAssert &asserts) { return(Test_OptimizationGated(asserts)); }

//+------------------------------------------------------------------+
//| Script entry point.                                              |
//| Returns 0=all pass, 1=any failure, 2=pass but skips present.    |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_RUN_ALL_TESTS
int OnStart()
  {
   CAssert asserts;
   asserts.Reset();
   Print("== Test_OptContextProfiler ==");
   Test_OptimizationGated(asserts);
   Test_TesterVsLive(asserts);
   Test_ProfilerNoWriteWhenGated(asserts);
   Test_ProfilerActiveRecords(asserts);
   Test_ProfilerMemoryEvidence(asserts);
   Test_ProfilerNoDuplicateStop(asserts);
   Test_ProfilerScopeOverflow(asserts);
   Test_DiagnosticsInjectedDisabled(asserts);
   Test_MacroNoEvalWhenInactive(asserts);
   bool pass = asserts.ReportSummary("Test_OptContextProfiler");
   if(!pass)                return(1);
   if(asserts.TestsSkipped() > 0) return(2);
   return(0);
  }
#endif
//+------------------------------------------------------------------+
