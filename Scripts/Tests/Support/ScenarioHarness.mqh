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
   // Accepts four non-owned pointers; validates each with CheckPointer and prints [ERROR] for any null.
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

   // Returns true only when all four pointers are non-null; subclasses can gate setup on this.
   bool IsReady(void) const
     {
      return(m_clock != NULL && m_sink != NULL && m_ctx != NULL && m_asserts != NULL);
     }

   // Clears the sink and resets the clock to 0 so each test scenario starts from a blank slate.
   void Reset(void)
     {
      if(m_sink  != NULL) m_sink.Clear();
      if(m_clock != NULL) m_clock.Set(0);
     }

   // Verifies that the sink holds a message matching ev.expected_kind (category) and ev.expected_trace
   // (substring); FAILs for required or malformed assertions, SKIPs for optional missing evidence.
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

   // Downstream IPLANs override these to inject fixture setup and teardown without touching the base class.
   virtual void OnOwnerSetup(void) {}
   virtual void OnOwnerTeardown(void) {}
  };

#endif // TRADESPINE_TEST_SUPPORT_SCENARIO_HARNESS_MQH
//+------------------------------------------------------------------+
