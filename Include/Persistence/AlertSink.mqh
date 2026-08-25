//+------------------------------------------------------------------+
//|                                                   AlertSink.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Persistence/AlertSink.mqh                         |
//| @spec: SPEC-05  @tdd: TDD.05.04.ed21  @iplan: IPLAN-05           |
//|                                                                  |
//| HALT and operator alert routing by runtime mode (SPEC-05 alert  |
//| sink contract). Degrades gracefully to log-only when no UI is   |
//| available. UI/log output is silent in optimization mode, but    |
//| HALT persistence still runs as the safety circuit breaker.      |
//|                                                                  |
//| Routing table:                                                   |
//|   Live / Visual tester  → SetHalt() + logger.Error() + Alert() |
//|   Non-visual tester     → SetHalt() + logger.Error()           |
//|   Optimization          → SetHalt() only                        |
//|                                                                  |
//| Circuit-breaker: when Init() is called with a non-NULL          |
//| IStateStore*, Halt() calls SetHalt(ev) before Alert(). If      |
//| SetHalt() returns false the failure is returned and logged when |
//| a runtime context permits logs (outside optimization); the      |
//| state machine still keeps its in-memory HALT absorbing.         |
//| Resume requires explicit operator action (CHG-16).              |
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
   //--- \param ev HALT evidence payload.
   //--- \return true only when durable HALT evidence was committed.
   bool Halt(const HaltEvidence &ev);

   //--- \brief Raise a non-fatal operator warning.
   //--- \param category Warning category.
   //--- \param msg Human-readable warning message.
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
   IStateStore*   m_store;

  public:
                  CAlertSink(void) : m_ctx(NULL), m_logger(NULL), m_store(NULL) {}

   //--- \brief Bind the alert sink to the runtime context, diagnostic logger, and optional state store.
   //--- \param ctx     Runtime mode gate (non-null; caller owns lifetime).
   //--- \param logger  Fallback diagnostic channel (non-null; caller owns lifetime).
   //--- \param store   State store for persistent GV HALT flag (optional; NULL = no flag written).
   //---                If SetHalt() fails, Halt returns false and emits a secondary Error.
   void           Init(COptContext* ctx, Logger* logger, IStateStore* store = NULL);

   //--- \brief Route a HALT alert per the active runtime mode.
   //--- \param ev HALT evidence payload.
   //--- \return true only when durable HALT evidence was committed.
   bool           Halt(const HaltEvidence &ev) override;

   //--- \brief Route an operator warning per the active runtime mode.
   //--- \param category Warning category.
   //--- \param msg Human-readable warning message.
   void           Warn(string category, string msg) override;
  };

//+------------------------------------------------------------------+
void CAlertSink::Init(COptContext* ctx, Logger* logger, IStateStore* store)
  {
   m_ctx    = ctx;
   m_logger = logger;
   m_store  = store;
  }

//+------------------------------------------------------------------+
bool CAlertSink::Halt(const HaltEvidence &ev)
  {
   bool persist_failed = (m_store == NULL);
   if(m_store != NULL)
      persist_failed = !m_store.SetHalt(ev); // persistent circuit breaker

   string msg = "TRADESPINE HALT: " + ev.reason
              + " | Action: " + ev.operator_action
              + " | Symbol: " + ev.symbol
              + " | Magic: " + StringFormat("%I64u", ev.magic)
              + " | Ticket: " + StringFormat("%I64u", ev.ticket);

   if(m_ctx == NULL) return(!persist_failed);
   if(m_ctx.IsOptimizing()) return(!persist_failed); // UI/log silent; persistence already attempted above.

   if(m_logger != NULL)
      m_logger.Error("HALT", msg + " [state=" + IntegerToString(ev.last_known_state) + "]");

   if(persist_failed)
     {
      string fail_msg = "HALT persistence failed; persistent circuit breaker may not be set";
      if(m_logger != NULL)
         m_logger.Error("HALT", fail_msg);
      else
         Print("[ERROR][HALT] " + fail_msg);
     }

   if(m_ctx.IsLive() || m_ctx.IsVisualMode())
      Alert(msg); // blocks until dismissed; log and flag written above
   return(!persist_failed);
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
