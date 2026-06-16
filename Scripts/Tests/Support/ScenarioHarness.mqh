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
//| \brief ScenarioHarness - minimal component assembly for          |
//|        integration tests: wires FakeClock + FakeLogSink +         |
//|        COptContext + CAssert, with owner-extension hooks and      |
//|        evidence assertions. Broker/position/symbol/store fakes    |
//|        are added by the owning IPLANs (CHG-06).                  |
//+------------------------------------------------------------------+
class ScenarioHarness
  {
protected:
   FakeClock   *m_clock;   // not owned
   FakeLogSink *m_sink;    // not owned
   COptContext *m_ctx;     // not owned
   CAssert     *m_asserts; // not owned

private:
   // Maps an evidence kind enum to the log category string; returns "" for unrecognised values.
   static string KindToCategory(ENUM_EVIDENCE_KIND kind)
     {
      switch(kind)
        {
         case EVIDENCE_INTENT:     return("intent");
         case EVIDENCE_EXECUTION:  return("execution");
         case EVIDENCE_DIAGNOSTIC: return("diagnostic");
         case EVIDENCE_STATE:      return("state");
         case EVIDENCE_RELEASE:    return("release");
        }
      return("");  // empty signals invalid kind
     }

public:
   //+------------------------------------------------------------------+
   //| \brief Construct a scenario harness from non-owned test fixtures. |
   //| \param clk Fake clock pointer; must be valid for a ready harness. |
   //| \param sink Fake log sink pointer; must be valid for readiness.   |
   //| \param ctx Runtime context pointer; must be valid for readiness.  |
   //| \param asserts Assertion recorder pointer; must be valid.         |
   //+------------------------------------------------------------------+
   ScenarioHarness(FakeClock *clk, FakeLogSink *sink, COptContext *ctx, CAssert *asserts)
     {
      m_clock   = (CheckPointer(clk)     != POINTER_INVALID) ? clk     : NULL;
      m_sink    = (CheckPointer(sink)    != POINTER_INVALID) ? sink    : NULL;
      m_ctx     = (CheckPointer(ctx)     != POINTER_INVALID) ? ctx     : NULL;
      m_asserts = (CheckPointer(asserts) != POINTER_INVALID) ? asserts : NULL;
      if(m_clock   == NULL) Print("[ERROR] ScenarioHarness: null clock pointer");
      if(m_sink    == NULL) Print("[ERROR] ScenarioHarness: null sink pointer");
      if(m_ctx     == NULL) Print("[ERROR] ScenarioHarness: null runtime-context pointer");
      if(m_asserts == NULL) Print("[ERROR] ScenarioHarness: null asserts pointer");
     }

   //+------------------------------------------------------------------+
   //| \brief Report whether all required non-owned pointers are valid.  |
   //| \return true when clock, sink, context, and asserts are non-null. |
   //+------------------------------------------------------------------+
   bool IsReady(void) const
     {
      return(m_clock != NULL && m_sink != NULL && m_ctx != NULL && m_asserts != NULL);
     }

   //+------------------------------------------------------------------+
   //| \brief Reset fake sink and clock state for a new scenario.        |
   //+------------------------------------------------------------------+
   void Reset(void)
     {
      if(m_sink  != NULL) m_sink.Clear();
      if(m_clock != NULL) m_clock.Set(0);
     }

   //+------------------------------------------------------------------+
   //| \brief Assert that the sink contains the expected evidence trace. |
   //| \param ev Expected evidence kind, trace text, and required flag.  |
   //| \return true when evidence is present or optional evidence skips. |
   //+------------------------------------------------------------------+
   bool AssertEvidence(const EvidenceAssertion &ev)
     {
      if(m_asserts == NULL)
        {
         Print("[ERROR] ScenarioHarness: null asserts in AssertEvidence");
         return(false);
        }
      if(m_sink == NULL)
         return(m_asserts.TS_CHECK(false, "ScenarioHarness: null sink in AssertEvidence"));
      string kind_cat = KindToCategory(ev.expected_kind);
      if(StringLen(kind_cat) == 0)
         return(m_asserts.TS_CHECK(false, StringFormat(
                "Malformed EvidenceAssertion: invalid expected_kind value %d",
                (int)ev.expected_kind)));
      bool found = m_sink.HasMessageInCategory(kind_cat, ev.expected_trace);
      if(found)
         return(m_asserts.TS_CHECK(true, StringFormat("Evidence '%s' (kind:%s) present in log",
                                   ev.expected_trace, kind_cat)));
      if(ev.required)
        {
         if(m_sink.HasOverflow())
            return(m_asserts.TS_CHECK(false, StringFormat(
                   "Evidence '%s' (kind:%s) INCONCLUSIVE — sink overflowed before capture",
                   ev.expected_trace, kind_cat)));
         return(m_asserts.TS_CHECK(false, StringFormat(
                "Required evidence '%s' (kind:%s) missing from log",
                ev.expected_trace, kind_cat)));
        }
      m_asserts.TS_SKIP(StringFormat("Optional evidence '%s' not present (deferred)", ev.expected_trace));
      return(true);
     }

   //+------------------------------------------------------------------+
   //| \brief Owner-plan setup hook for downstream harness extensions.   |
   //+------------------------------------------------------------------+
   virtual void OnOwnerSetup(void) {}

   //+------------------------------------------------------------------+
   //| \brief Owner-plan teardown hook for downstream harness extensions.|
   //+------------------------------------------------------------------+
   virtual void OnOwnerTeardown(void) {}
  };

#endif // TRADESPINE_TEST_SUPPORT_SCENARIO_HARNESS_MQH
//+------------------------------------------------------------------+
