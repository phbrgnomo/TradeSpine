//+------------------------------------------------------------------+
//|                                      Test_OptContextProfiler.mq5 |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_OptContextProfiler.mq5                |
//| @tdd: TDD.09.04.8050  @spec: SPEC-09  @iplan: IPLAN-09           |
//|                                                                  |
//| Tier-1 integration tests for OptContext + Profiler gating.       |
//| Optimization unconditionally silences all non-core work;         |
//| there is no audit_in_optimization override.                      |
//| No broker execution APIs.                                        |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-09 - OptContext and Profiler tests"
#property script_show_inputs

#include "TestAssert.mqh"
#include "../../Include/Core/Interfaces.mqh"
#include "../../Include/Core/OptContext.mqh"
#include "../../Include/Core/Profiler.mqh"

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
bool Test_OptimizationGated()
  {
   bool ok = true;
   RuntimeMode mode = MakeMode(true, true);
   OptContext ctx(mode);

   ok &= CheckFalse(ctx.AllowsHighVolumeEvidence(),
                    "High-volume evidence disabled in optimization");
   ok &= CheckFalse(ctx.AllowsDiagnostics(), "Diagnostics disabled in optimization");
   ok &= CheckFalse(ctx.AllowsProfiler(),    "Profiler disabled in optimization");
   ok &= Check(ctx.IsOptimizing(),           "IsOptimizing true");
   ok &= Check(ctx.IsTesting(),              "IsTesting true");
   return(ok);
  }

//+------------------------------------------------------------------+
//| Plain tester enables profiler; live disables it by default.      |
//+------------------------------------------------------------------+
bool Test_TesterVsLive()
  {
   bool ok = true;
   RuntimeMode tester = MakeMode(true, false);
   OptContext ctx_t(tester);
   ok &= Check(ctx_t.AllowsProfiler(),    "Profiler on by default in plain tester");
   ok &= Check(ctx_t.AllowsDiagnostics(), "Diagnostics on in plain tester");

   RuntimeMode live = MakeMode(false, false);
   OptContext ctx_l(live);
   ok &= CheckFalse(ctx_l.AllowsProfiler(), "Profiler off by default in live");
   ok &= Check(ctx_l.IsLive(),              "IsLive true off-tester");
   return(ok);
  }

//+------------------------------------------------------------------+
//| Disabled profiler performs no persistent writes (BDD.01.03.b37d).|
//+------------------------------------------------------------------+
bool Test_ProfilerNoWriteWhenGated()
  {
   bool ok = true;
   RuntimeMode mode = MakeMode(true, true); // optimization -> all gated
   OptContext ctx(mode);
   CapturingLogSink sink;
   Profiler prof(GetPointer(ctx), GetPointer(sink));

   prof.Start("entry_pipeline");
   prof.Stop("entry_pipeline");
   prof.PrintResults();

   ok &= CheckEqualL((long)sink.Count(), 0,
                     "Gated profiler issued no log writes");
   ProfileSample s = prof.GetSample("entry_pipeline");
   ok &= CheckFalse(s.enabled,        "Gated sample reports enabled=false");
   ok &= CheckEqualL(s.elapsed_us, 0, "Gated sample reports zero elapsed");
   ok &= CheckFalse(prof.IsActive(),  "Profiler.IsActive false under gated policy");
   return(ok);
  }

//+------------------------------------------------------------------+
//| Active profiler records a sample and can emit evidence.          |
//+------------------------------------------------------------------+
bool Test_ProfilerActiveRecords()
  {
   bool ok = true;
   RuntimeMode mode = MakeMode(true, false); // plain tester -> profiler on
   OptContext ctx(mode);
   CapturingLogSink sink;
   Profiler prof(GetPointer(ctx), GetPointer(sink));

   ok &= Check(prof.IsActive(), "Profiler active in plain tester");
   prof.Start("calc");
   long acc = 0;
   for(int i = 0; i < 1000; i++)
      acc += i;
   prof.Stop("calc");

   ProfileSample s = prof.GetSample("calc");
   ok &= Check(s.enabled,         "Active sample reports enabled=true");
   ok &= Check(s.elapsed_us >= 0, "Active sample elapsed is non-negative");
   prof.PrintResults();
   ok &= Check(sink.Count() >= 1, "Active profiler emitted evidence to the sink");
   return(ok);
  }

//+------------------------------------------------------------------+
//| Memory-evidence baseline-and-delta harness (SPEC-09/EARS.01.03.8044).|
//| Verifies scenario propagation, non-negative MQL-program memory,  |
//| and terminal build context in timing_source.                     |
//| Native TerminalInfoInteger used directly for the expected build  |
//| string so the profiler path stays dependency-light.              |
//+------------------------------------------------------------------+
bool Test_ProfilerMemoryEvidence()
  {
   bool ok = true;
   RuntimeMode mode = MakeMode(true, false); // plain tester -> profiler on
   OptContext ctx(mode);
   Profiler prof(GetPointer(ctx));

   int build = (int)TerminalInfoInteger(TERMINAL_BUILD);

   long baseline = prof.CaptureBaselineMemory("bench_test");
   BenchmarkBaseline b = prof.GetBenchmarkData("bench_test", baseline);

   ok &= CheckEqualStr(b.scenario, "bench_test",
                       "Scenario name propagates to benchmark record");
   ok &= Check(b.baseline_memory >= 0,
               "MQL program memory baseline is non-negative (MB)");
   ok &= Check(StringFind(b.timing_source, "GetMicrosecondCount") == 0,
               "Timing source starts with GetMicrosecondCount");
   ok &= Check(StringFind(b.timing_source,
               StringFormat("build=%d", build)) >= 0,
               "Timing source encodes the actual terminal build number");
   return(ok);
  }

//+------------------------------------------------------------------+
//| Duplicate Stop() must not overwrite the recorded elapsed time.   |
//+------------------------------------------------------------------+
bool Test_ProfilerNoDuplicateStop()
  {
   bool ok = true;
   RuntimeMode mode = MakeMode(true, false);
   OptContext ctx(mode);
   Profiler prof(GetPointer(ctx));

   prof.Start("x");
   long acc = 0;
   for(int i = 0; i < 500; i++)
      acc += i;            // small workload to ensure non-zero elapsed
   prof.Stop("x");
   ProfileSample s1 = prof.GetSample("x");

   prof.Stop("x");         // duplicate stop — must be a no-op
   ProfileSample s2 = prof.GetSample("x");

   ok &= Check(s1.enabled,             "First Stop records an enabled sample");
   ok &= CheckEqualL(s2.elapsed_us, s1.elapsed_us,
                     "Duplicate Stop() does not overwrite the recorded elapsed time");
   return(ok);
  }

//+------------------------------------------------------------------+
//| Scope-cap overflow emits exactly one gated diagnostic.           |
//+------------------------------------------------------------------+
bool Test_ProfilerScopeOverflow()
  {
   bool ok = true;
   RuntimeMode mode = MakeMode(true, false);
   OptContext ctx(mode);
   CapturingLogSink sink;
   Profiler prof(GetPointer(ctx), GetPointer(sink));

   // Fill every slot
   for(int i = 0; i < PROFILER_MAX_SCOPES; i++)
      prof.Start(StringFormat("scope_%d", i));

   int before = sink.Count();
   prof.Start("overflow_trigger"); // one beyond cap
   ok &= Check(sink.Count() > before,
               "Overflow diagnostic emitted when scope cap exceeded");

   prof.Start("overflow_trigger2"); // second overflow — no second diagnostic
   ok &= CheckEqualL((long)(sink.Count() - before), 1,
                     "Overflow diagnostic fires exactly once");
   return(ok);
  }

//+------------------------------------------------------------------+
//| M1: injected diagnostics_enabled=false is honored outside        |
//| optimization. Profiler policy (tester/non-opt) is independent   |
//| of the diagnostics flag.                                         |
//+------------------------------------------------------------------+
bool Test_DiagnosticsInjectedDisabled()
  {
   bool ok = true;
   RuntimeMode mode;
   mode.is_tester           = true;
   mode.is_optimization     = false;
   mode.diagnostics_enabled = false; // explicitly disabled outside optimization
   OptContext ctx(mode);

   ok &= CheckFalse(ctx.AllowsDiagnostics(),
                    "Injected diagnostics_enabled=false honored outside optimization");
   ok &= Check(ctx.AllowsProfiler(),
               "Profiler policy (tester, non-opt) unaffected by diagnostics flag");
   ok &= CheckFalse(ctx.IsOptimizing(), "Mode is not optimization");
   ok &= Check(ctx.IsTesting(),         "Mode is tester");
   return(ok);
  }

//+------------------------------------------------------------------+
//| L1: PROFILER macros must not evaluate the scope argument when    |
//| the profiler is NULL or inactive. A side-effecting expression    |
//| (++counter) proves the argument is never computed.               |
//+------------------------------------------------------------------+
bool Test_MacroNoEvalWhenInactive()
  {
   bool ok = true;
   int counter = 0;

   // Case 1: g_profiler == NULL — body never executes.
   g_profiler = NULL;
   PROFILER_START("s" + IntegerToString(++counter));
   PROFILER_STOP( "s" + IntegerToString(++counter));
   ok &= CheckEqualL((long)counter, 0,
                     "PROFILER macros do not evaluate scope when g_profiler is NULL");

   // Case 2: profiler exists but IsActive()==false — scope still not evaluated.
   RuntimeMode mode = MakeMode(true, true); // optimization -> inactive
   OptContext ctx(mode);
   Profiler inactive_prof(GetPointer(ctx));
   g_profiler = GetPointer(inactive_prof);
   ok &= CheckFalse(g_profiler.IsActive(), "Fixture profiler is inactive under optimization");

   counter = 0;
   PROFILER_START("s" + IntegerToString(++counter));
   PROFILER_STOP( "s" + IntegerToString(++counter));
   ok &= CheckEqualL((long)counter, 0,
                     "PROFILER macros do not evaluate scope when profiler is inactive");

   g_profiler = NULL; // release before inactive_prof goes out of scope
   return(ok);
  }

//+------------------------------------------------------------------+
//| TDD trace aliases.                                               |
//+------------------------------------------------------------------+
bool test_core_runtime_and_configuration_integration_contract()
  {
   return(Test_OptimizationGated() && Test_ProfilerNoWriteWhenGated() &&
          Test_ProfilerMemoryEvidence() && Test_ProfilerNoDuplicateStop() &&
          Test_ProfilerScopeOverflow() && Test_DiagnosticsInjectedDisabled() &&
          Test_MacroNoEvalWhenInactive());
  }
bool test_core_runtime_and_configuration_aa68_integration() { return(Test_TesterVsLive()); }
bool test_core_runtime_and_configuration_b37d_integration() { return(Test_ProfilerActiveRecords() && Test_ProfilerMemoryEvidence()); }
bool test_core_runtime_and_configuration_cb03_integration() { return(Test_OptimizationGated()); }

//+------------------------------------------------------------------+
//| Script entry point.                                              |
//| Returns 0=all pass, 1=any failure, 2=pass but skips present.    |
//+------------------------------------------------------------------+
int OnStart()
  {
   ResetAsserts();
   Print("== Test_OptContextProfiler ==");
   Test_OptimizationGated();
   Test_TesterVsLive();
   Test_ProfilerNoWriteWhenGated();
   Test_ProfilerActiveRecords();
   Test_ProfilerMemoryEvidence();
   Test_ProfilerNoDuplicateStop();
   Test_ProfilerScopeOverflow();
   Test_DiagnosticsInjectedDisabled();
   Test_MacroNoEvalWhenInactive();
   bool pass = ReportSummary("Test_OptContextProfiler");
   if(!pass)                return(1);
   if(g_tests_skipped > 0) return(2);
   return(0);
  }
//+------------------------------------------------------------------+
