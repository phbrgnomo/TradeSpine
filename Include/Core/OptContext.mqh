//+------------------------------------------------------------------+
//|                                                    OptContext.mqh |
//|              Copyright 2026, Paulo Henrique Barreto Reboucas      |
//|                                                                  |
//| @code: Include/Core/OptContext.mqh                               |
//| @spec: SPEC-09  @tdd: TDD.09.04.8050  @iplan: IPLAN-09           |
//|                                                                  |
//| Detects tester/optimization/live mode and exposes policy         |
//| decisions for logging, diagnostics, profiling, and release       |
//| evidence. Implements EARS.01.03.c5b7: optimization-mode logging  |
//| and profiling avoid high-I/O work unless audit is enabled.       |
//|                                                                  |
//| Dependency-injectable for Tier-1 tests; falls back to the MQL    |
//| runtime flags otherwise. Invalid reads default to conservative   |
//| live-safe behavior (no INIT_FAILED).                             |
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
   bool m_audit_in_optimization;

public:
   //--- Auto-detecting constructor (production default).
                     OptContext(void)
     {
      m_is_tester             = (bool)MQLInfoInteger(MQL_TESTER);
      m_is_optimization       = (bool)MQLInfoInteger(MQL_OPTIMIZATION);
      m_is_visual             = (bool)MQLInfoInteger(MQL_VISUAL_MODE);
      m_audit_in_optimization = false;
     }

   //--- Injecting constructor (Tier-1 tests force the mode).
                     OptContext(const RuntimeMode &mode, const bool audit_in_optimization)
     {
      m_is_tester             = mode.is_tester;
      m_is_optimization       = mode.is_optimization;
      m_is_visual             = false;
      m_audit_in_optimization = audit_in_optimization;
     }

   //--- Late binding of the audit flag from CommonInputs.
   void              SetAuditInOptimization(const bool v) { m_audit_in_optimization = v; }

   //--- Raw mode predicates.
   bool              IsTesting(void)    const { return(m_is_tester); }
   bool              IsOptimizing(void) const { return(m_is_optimization); }
   bool              IsVisualMode(void) const { return(m_is_visual); }
   bool              IsLive(void)       const { return(!m_is_tester); }

   //--- Policy decisions (EARS.01.03.c5b7).
   //--- High-volume evidence: blocked during optimization unless audit on.
   bool              AllowsHighVolumeEvidence(void) const
     {
      if(m_is_optimization)
         return(m_audit_in_optimization);
      return(true);
     }

   //--- Diagnostics (logging): same gate - silent under optimization
   //--- unless audit on; allowed live and in plain tester.
   bool              AllowsDiagnostics(void) const
     {
      if(m_is_optimization)
         return(m_audit_in_optimization);
      return(true);
     }

   //--- Profiler: on by default only in plain tester; off live by
   //--- default; off in optimization unless explicitly audited.
   bool              AllowsProfiler(void) const
     {
      if(m_is_optimization)
         return(m_audit_in_optimization);
      if(m_is_tester)
         return(true);
      return(false); // live: opt-in only
     }

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
