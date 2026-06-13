//+------------------------------------------------------------------+
//|                                                   OptContext.mqh |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Core/OptContext.mqh                               |
//| @spec: SPEC-09  @tdd: TDD.09.04.8050  @iplan: IPLAN-09           |
//|                                                                  |
//| Detects tester/optimization/live mode and exposes policy         |
//| decisions for logging, diagnostics, profiling, and release       |
//| evidence.                                                        |
//|                                                                  |
//| During optimization ALL non-core work is silenced                |
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
//| \brief COptContext - runtime-mode detection and the logging,     |
//|        diagnostics, profiling, and evidence policy derived from  |
//|        it. Auto-detects in production; injectable for tests.     |
//+------------------------------------------------------------------+
class COptContext
  {
  private:
    bool m_is_tester;
    bool m_is_optimization;
    bool m_is_visual;
    bool m_diagnostics_enabled;

  public:
    //--- \brief Auto-detecting constructor (production default); reads
    //---        MQL_TESTER / MQL_OPTIMIZATION / MQL_VISUAL_MODE.
    COptContext(void)
      {
        m_is_tester           = (bool)MQLInfoInteger(MQL_TESTER);
        m_is_optimization     = (bool)MQLInfoInteger(MQL_OPTIMIZATION);
        m_is_visual           = (bool)MQLInfoInteger(MQL_VISUAL_MODE);
        m_diagnostics_enabled = !m_is_optimization;
      }

    //--- \brief Injecting constructor (Tier-1 tests force the mode).
    //--- \param mode  Forced runtime-mode snapshot.
    //--- \note  Optimization unconditionally wins; outside of optimization,
    //---        mode.diagnostics_enabled is honored so harnesses can disable it.
    COptContext(const RuntimeMode &mode)
      {
        m_is_tester           = mode.is_tester;
        m_is_optimization     = mode.is_optimization;
        // Optimization can only occur inside the tester; normalize contradictory input.
        if(m_is_optimization) m_is_tester = true;
        m_is_visual           = false;
        m_diagnostics_enabled = mode.is_optimization ? false : mode.diagnostics_enabled;
      }

    //--- Raw mode predicates.
    bool IsTesting(void)    const { return(m_is_tester); }       //!< \return true inside the Strategy Tester.
    bool IsOptimizing(void) const { return(m_is_optimization); } //!< \return true during an optimization pass.
    bool IsVisualMode(void) const { return(m_is_visual); }       //!< \return true in visual tester mode.
    bool IsLive(void)       const { return(!m_is_tester); }      //!< \return true on a live/demo chart (not the tester).

    //--- Policy decisions. Optimization unconditionally silences all non-core work.
    bool AllowsHighVolumeEvidence(void) const { return(!m_is_optimization); }            //!< \return true when bulky evidence I/O is permitted.
    bool AllowsDiagnostics(void)        const { return(m_diagnostics_enabled); }         //!< \return true when diagnostic logging is permitted.
    bool AllowsProfiler(void)           const { return(m_is_tester && !m_is_optimization); } //!< \return true when profiling is permitted.

    //--- \brief Capture the current mode as a RuntimeMode evidence record.
    //--- \return Snapshot with diagnostics_enabled reflecting active policy.
    RuntimeMode Snapshot(void) const
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
