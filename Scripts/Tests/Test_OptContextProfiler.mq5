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
   m.diagnostics_enabled = false;
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
//| TDD trace aliases.                                               |
//+------------------------------------------------------------------+
bool test_core_runtime_and_configuration_integration_contract()
  {
   return(Test_OptimizationGated() && Test_ProfilerNoWriteWhenGated());
  }
bool test_core_runtime_and_configuration_aa68_integration() { return(Test_TesterVsLive()); }
bool test_core_runtime_and_configuration_b37d_integration() { return(Test_ProfilerActiveRecords()); }
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
   bool pass = ReportSummary("Test_OptContextProfiler");
   if(!pass)                return(1);
   if(g_tests_skipped > 0) return(2);
   return(0);
  }
//+------------------------------------------------------------------+
