//+------------------------------------------------------------------+
//|                                              ScenarioHarness.mqh |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| Minimal reusable component assembly for IPLAN-11 integration     |
//| tests. Wires FakeClock + FakeLogSink + COptContext and provides  |
//| owner-extension hooks and evidence assertions. Does NOT include  |
//| broker, position, symbol, or store fakes (deferred to owner      |
//| IPLANs per CHG-06). @spec: SPEC-11  @iplan: IPLAN-11            |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_TEST_SUPPORT_SCENARIO_HARNESS_MQH
#define TRADESPINE_TEST_SUPPORT_SCENARIO_HARNESS_MQH

#include "FakeClock.mqh"
#include "FakeLogSink.mqh"
#include "../../../Include/Core/OptContext.mqh"
#include "../../../Include/Testing/Assert.mqh"

//+------------------------------------------------------------------+
//| ScenarioHarness                                                  |
//+------------------------------------------------------------------+
class ScenarioHarness
  {
protected:
   FakeClock   *m_clock;   // not owned
   FakeLogSink *m_sink;    // not owned
   COptContext *m_ctx;     // not owned
   CAssert     *m_asserts; // not owned

public:
   ScenarioHarness(FakeClock *clk, FakeLogSink *sink, COptContext *ctx, CAssert *asserts)
      : m_clock(clk), m_sink(sink), m_ctx(ctx), m_asserts(asserts) {}

   //--- Reset deterministic state between stimulus runs
   void Reset(void)
     {
      m_sink.Clear();
      m_clock.Set(0);
     }

   //--- Check FakeLogSink for the expected_trace.
   //    required=true and missing -> FAIL via CAssert.
   //    required=false and missing -> Skip via CAssert.
   bool AssertEvidence(const EvidenceAssertion &ev)
     {
      bool found = m_sink.HasMessage(ev.expected_trace);
      if(found)
         return(m_asserts.Check(true, StringFormat("Evidence '%s' present in log", ev.expected_trace)));
      if(ev.required)
         return(m_asserts.Check(false, StringFormat("Required evidence '%s' missing from log", ev.expected_trace)));
      m_asserts.Skip(StringFormat("Optional evidence '%s' not present (deferred)", ev.expected_trace));
      return(true);
     }

   //--- Owner-extension hooks (downstream IPLANs override these)
   virtual void OnOwnerSetup(void) {}
   virtual void OnOwnerTeardown(void) {}
  };

#endif // TRADESPINE_TEST_SUPPORT_SCENARIO_HARNESS_MQH
//+------------------------------------------------------------------+
