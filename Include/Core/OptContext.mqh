//+------------------------------------------------------------------+
//|                                                    OptContext.mqh |
//|              Copyright 2026, Paulo Henrique Barreto Reboucas      |
//|                                                                  |
//| @code: Include/Core/OptContext.mqh                               |
//| @spec: SPEC-09  @tdd: TDD.09.04.8050  @iplan: IPLAN-09           |
//|                                                                  |
//| Detects tester/optimization/live mode and exposes policy         |
//| decisions for logging, diagnostics, profiling, and release       |
//| evidence.                                                        |
//|                                                                  |
//| During optimization ALL non-core work is silenced               |
//| unconditionally — there is no user override. This keeps          |
//| optimizer run speed independent of diagnostic configuration.     |
//|                                                                  |
//| Dependency-injectable for Tier-1 tests (injecting constructor).  |
//| Invalid reads default to conservative live-safe behavior.        |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_OPT_CONTEXT_MQH
#define TRADESPINE_OPT_CONTEXT_MQH

#include "Interfaces.mqh"

//+------------------------------------------------------------------+
//| OptContext                                                       |
//+------------------------------------------------------------------+
class OptContext
  {
  private:
    bool m_is_tester;
    bool m_is_optimization;
    bool m_is_visual;

  public:
    //--- Auto-detecting constructor (production default).
    OptContext(void)
      {
        m_is_tester       = (bool)MQLInfoInteger(MQL_TESTER);
        m_is_optimization = (bool)MQLInfoInteger(MQL_OPTIMIZATION);
        m_is_visual       = (bool)MQLInfoInteger(MQL_VISUAL_MODE);
      }

    //--- Injecting constructor (Tier-1 tests force the mode).
    OptContext(const RuntimeMode &mode)
      {
        m_is_tester       = mode.is_tester;
        m_is_optimization = mode.is_optimization;
        m_is_visual       = false;
      }

    //--- Raw mode predicates.
    bool              IsTesting(void)    const { return(m_is_tester); }
    bool              IsOptimizing(void) const { return(m_is_optimization); }
    bool              IsVisualMode(void) const { return(m_is_visual); }
    bool              IsLive(void)       const { return(!m_is_tester); }

    //--- Policy decisions.
    //--- Optimization unconditionally silences all non-core work.
    bool              AllowsHighVolumeEvidence(void) const { return(!m_is_optimization); }
    bool              AllowsDiagnostics(void)        const { return(!m_is_optimization); }
    bool              AllowsProfiler(void)           const { return(m_is_tester && !m_is_optimization); }

    //--- Snapshot for evidence records.
    RuntimeMode       Snapshot(void) const
      {
        RuntimeMode m;
        m.is_tester           = m_is_tester;
        m.is_optimization     = m_is_optimization;
        m.diagnostics_enabled = AllowsDiagnostics();
        return(m);
      }
    };

#endif // TRADESPINE_OPT_CONTEXT_MQH
//+------------------------------------------------------------------+
