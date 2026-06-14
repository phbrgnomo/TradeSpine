//+------------------------------------------------------------------+
//|                                                   AlertSink.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Persistence/AlertSink.mqh                         |
//| @spec: SPEC-05  @tdd: TDD.05.04.ed21  @iplan: IPLAN-05           |
//|                                                                  |
//| HALT and operator alert routing by runtime mode (SPEC-05 alert  |
//| sink contract). Degrades gracefully to log-only when no UI is   |
//| available. Silent in optimization mode to protect run speed.    |
//|                                                                  |
//| Routing table:                                                   |
//|   Live / Visual tester  → Alert() + logger.Error()             |
//|   Non-visual tester     → logger.Error() only                  |
//|   Optimization          → silent                                |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_PERSISTENCE_ALERTSINK_MQH
#define TRADESPINE_PERSISTENCE_ALERTSINK_MQH

#include "StateStore.mqh"
#include "Logger.mqh"

//+------------------------------------------------------------------+
//| \brief IAlertSink - operator alert routing seam.                 |
//|        Implementations may call Alert(), Print(), or log-only   |
//|        depending on the runtime mode.                            |
//+------------------------------------------------------------------+
interface IAlertSink
  {
   //--- \brief Raise a HALT alert. Carries the full HaltEvidence payload.
   void Halt(const HaltEvidence &ev);

   //--- \brief Raise a non-fatal operator warning.
   void Warn(string category, string msg);
  };

//+------------------------------------------------------------------+
//| \brief CAlertSink - production implementation of IAlertSink.     |
//|        Routing is determined from the injected COptContext.      |
//+------------------------------------------------------------------+
class CAlertSink : public IAlertSink
  {
  private:
   COptContext*   m_ctx;
   Logger*        m_logger;

  public:
                  CAlertSink(void) : m_ctx(NULL), m_logger(NULL) {}

   //--- \brief Bind the alert sink to the runtime context and diagnostic logger.
   //--- \param ctx     Runtime mode gate (non-null; caller owns lifetime).
   //--- \param logger  Fallback diagnostic channel (non-null; caller owns lifetime).
   void           Init(COptContext* ctx, Logger* logger);

   //--- \brief Route a HALT alert per the active runtime mode.
   void           Halt(const HaltEvidence &ev) override;

   //--- \brief Route an operator warning per the active runtime mode.
   void           Warn(string category, string msg) override;
  };

//+------------------------------------------------------------------+
void CAlertSink::Init(COptContext* ctx, Logger* logger)
  {
   m_ctx    = ctx;
   m_logger = logger;
  }

//+------------------------------------------------------------------+
void CAlertSink::Halt(const HaltEvidence &ev)
  {
   if(m_ctx == NULL) return;
   if(m_ctx.IsOptimizing()) return; // silent in optimization

   string msg = "TRADESPINE HALT: " + ev.reason
              + " | Action: " + ev.operator_action;

   if(m_ctx.IsLive() || m_ctx.IsVisualMode())
      Alert(msg); // blocks until dismissed; acceptable for HALT conditions

   if(m_logger != NULL)
      m_logger.Error("HALT", msg + " [state=" + IntegerToString(ev.last_known_state) + "]");
  }

//+------------------------------------------------------------------+
void CAlertSink::Warn(string category, string msg)
  {
   if(m_ctx == NULL) return;
   if(m_ctx.IsOptimizing()) return;

   if(m_ctx.IsLive())
      Print("[TRADESPINE WARN][" + category + "] " + msg);

   if(m_logger != NULL)
      m_logger.Warn(category, msg);
  }

#endif // TRADESPINE_PERSISTENCE_ALERTSINK_MQH
//+------------------------------------------------------------------+
