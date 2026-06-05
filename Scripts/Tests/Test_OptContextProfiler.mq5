//+------------------------------------------------------------------+
//|                                       Test_OptContextProfiler.mq5 |
//|              Copyright 2026, Paulo Henrique Barreto Reboucas      |
//|                                                                  |
//| @tests: Scripts/Tests/Test_OptContextProfiler.mq5                |
//| @tdd: TDD.09.04.8050  @spec: SPEC-09  @iplan: IPLAN-09           |
//|                                                                  |
//| Tier-1 integration tests for OptContext + Profiler gating with a |
//| fake log sink: optimization disables high-I/O diagnostics unless |
//| audit_in_optimization is enabled. No broker execution APIs.      |
//+------------------------------------------------------------------+
#property copyright "Paulo Henrique Barreto Reboucas"
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
   m.is_tester            = tester;
   m.is_optimization      = optimization;
   m.diagnostics_enabled  = false;
   return(m);
  }

//+------------------------------------------------------------------+
//| Optimization without audit gates all high-I/O policy decisions.  |
//+------------------------------------------------------------------+
bool Test_OptimizationGated()
  {
   RuntimeMode mode = MakeMode(true, true);
   OptContext ctx(mode, false); // audit_in_optimization = false

   CheckFalse(ctx.AllowsHighVolumeEvidence(), "High-volume evidence disabled in optimization");
   CheckFalse(ctx.AllowsDiagnostics(),        "Diagnostics disabled in optimization");
   CheckFalse(ctx.AllowsProfiler(),           "Profiler disabled in optimization");
   Check(ctx.IsOptimizing(),                  "IsOptimizing true");
   Check(ctx.IsTesting(),                     "IsTesting true");
   return(true);
  }

//+------------------------------------------------------------------+
//| Audit-enabled optimization permits bounded evidence.             |
//+------------------------------------------------------------------+
bool Test_OptimizationAudited()
  {
   RuntimeMode mode = MakeMode(true, true);
   OptContext ctx(mode, true); // audit_in_optimization = true

   Check(ctx.AllowsHighVolumeEvidence(), "High-volume evidence allowed when audit enabled");
   Check(ctx.AllowsProfiler(),           "Profiler allowed when audit enabled");
   return(true);
  }

//+------------------------------------------------------------------+
//| Plain tester enables profiler; live disables it by default.      |
//+------------------------------------------------------------------+
bool Test_TesterVsLive()
  {
   RuntimeMode tester = MakeMode(true, false);
   OptContext ctx_t(tester, false);
   Check(ctx_t.AllowsProfiler(),    "Profiler on by default in plain tester");
   Check(ctx_t.AllowsDiagnostics(), "Diagnostics on in plain tester");

   RuntimeMode live = MakeMode(false, false);
   OptContext ctx_l(live, false);
   CheckFalse(ctx_l.AllowsProfiler(), "Profiler off by default in live");
   Check(ctx_l.IsLive(),              "IsLive true off-tester");
   return(true);
  }

//+------------------------------------------------------------------+
//| Disabled profiler performs no persistent writes (BDD.01.03.b37d).|
//+------------------------------------------------------------------+
bool Test_ProfilerNoWriteWhenGated()
  {
   RuntimeMode mode = MakeMode(true, true);
   OptContext ctx(mode, false);          // profiler disabled by policy
   CapturingLogSink sink;
   Profiler prof(GetPointer(ctx), GetPointer(sink));

   prof.Start("entry_pipeline");
   prof.Stop("entry_pipeline");
   prof.PrintResults();

   CheckEqualL((long)sink.Count(), 0, "Gated profiler issued no log writes");
   ProfileSample s = prof.GetSample("entry_pipeline");
   CheckFalse(s.enabled,            "Gated sample reports enabled=false");
   CheckEqualL(s.elapsed_us, 0,     "Gated sample reports zero elapsed");
   CheckFalse(prof.IsActive(),      "Profiler.IsActive false under gated policy");
   return(true);
  }

//+------------------------------------------------------------------+
//| Active profiler records a sample and can emit evidence.          |
//+------------------------------------------------------------------+
bool Test_ProfilerActiveRecords()
  {
   RuntimeMode mode = MakeMode(true, false); // plain tester -> profiler on
   OptContext ctx(mode, false);
   CapturingLogSink sink;
   Profiler prof(GetPointer(ctx), GetPointer(sink));

   Check(prof.IsActive(), "Profiler active in plain tester");
   prof.Start("calc");
   long acc = 0;
   for(int i = 0; i < 1000; i++)
      acc += i;
   prof.Stop("calc");

   ProfileSample s = prof.GetSample("calc");
   Check(s.enabled,           "Active sample reports enabled=true");
   Check(s.elapsed_us >= 0,   "Active sample elapsed is non-negative");
   prof.PrintResults();
   Check(sink.Count() >= 1,   "Active profiler emitted evidence to the sink");
   return(true);
  }

//+------------------------------------------------------------------+
//| TDD trace aliases.                                               |
//+------------------------------------------------------------------+
bool test_core_runtime_and_configuration_integration_contract() { return(Test_OptimizationGated() && Test_ProfilerNoWriteWhenGated()); }
bool test_core_runtime_and_configuration_aa68_integration()      { return(Test_TesterVsLive()); }
bool test_core_runtime_and_configuration_b37d_integration()      { return(Test_ProfilerActiveRecords()); }
bool test_core_runtime_and_configuration_cb03_integration()      { return(Test_OptimizationAudited()); }

//+------------------------------------------------------------------+
//| Script entry point.                                              |
//+------------------------------------------------------------------+
void OnStart()
  {
   ResetAsserts();
   Print("== Test_OptContextProfiler ==");
   Test_OptimizationGated();
   Test_OptimizationAudited();
   Test_TesterVsLive();
   Test_ProfilerNoWriteWhenGated();
   Test_ProfilerActiveRecords();
   ReportSummary("Test_OptContextProfiler");
  }
//+------------------------------------------------------------------+
