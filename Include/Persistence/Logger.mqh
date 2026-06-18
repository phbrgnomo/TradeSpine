//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Persistence/Logger.mqh                            |
//| @spec: SPEC-05  @tdd: TDD.05.04.ed21  @iplan: IPLAN-05           |
//|                                                                  |
//| Leveled diagnostic logger — a thin, gated wrapper over ILogSink.|
//| Produces diagnostic text only; MUST NOT write to trade evidence  |
//| CSV files (that is TradeLogger's responsibility).               |
//|                                                                  |
//| Gating rules:                                                    |
//|   - Debug / Info / Warn : only when AllowsDiagnostics() is true.|
//|   - Error               : always emitted regardless of mode     |
//|                           (safety signal; operator must see it). |
//|   - All methods         : silenced in optimization mode via ctx. |
//|                                                                  |
//| If sink is NULL the fallback is Print() for Error level;        |
//| other levels are silently dropped when the sink is absent.      |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_PERSISTENCE_LOGGER_MQH
#define TRADESPINE_PERSISTENCE_LOGGER_MQH

#include "../../Include/Core/Interfaces.mqh"
#include "../../Include/Core/OptContext.mqh"

//+------------------------------------------------------------------+
//| \brief Logger - leveled diagnostic writer with runtime-mode gate.|
//|        Separate from TradeLogger; never writes to trade CSV.    |
//+------------------------------------------------------------------+
class Logger
  {
  private:
   COptContext*   m_ctx;
   ILogSink*      m_sink;

   //--- Core emit path.
   void           _Emit(ENUM_LOG_LEVEL level, const string category, const string msg);

  public:
                  Logger(void) : m_ctx(NULL), m_sink(NULL) {}

   //--- \brief Bind the logger to a runtime context and output sink.
   //--- \param ctx   Runtime mode gate (non-null; caller owns lifetime).
   //--- \param sink  Output destination; if NULL, Error falls back to Print().
   void           Init(COptContext* ctx, ILogSink* sink = NULL);

   //--- \brief Emit a DEBUG-level diagnostic (gated by AllowsDiagnostics).
   void           Debug(const string category, const string msg);

   //--- \brief Emit an INFO-level diagnostic (gated by AllowsDiagnostics).
   void           Info(const string category, const string msg);

   //--- \brief Emit a WARN-level diagnostic (gated by AllowsDiagnostics).
   void           Warn(const string category, const string msg);

   //--- \brief Emit an ERROR-level diagnostic — never gated; always reaches operator.
   void           Error(const string category, const string msg);
  };

//+------------------------------------------------------------------+
void Logger::_Emit(ENUM_LOG_LEVEL level, const string category, const string msg)
  {
   if(m_sink != NULL)
      m_sink.Write(level, category, msg);
   else if(level >= LOG_ERROR)
      Print("[ERROR][" + category + "] " + msg);
  }

//+------------------------------------------------------------------+
void Logger::Init(COptContext* ctx, ILogSink* sink)
  {
   m_ctx  = ctx;
   m_sink = sink;
  }

//+------------------------------------------------------------------+
void Logger::Debug(const string category, const string msg)
  {
   if(m_ctx == NULL || !m_ctx.AllowsDiagnostics()) return;
   _Emit(LOG_DEBUG, category, msg);
  }

//+------------------------------------------------------------------+
void Logger::Info(const string category, const string msg)
  {
   if(m_ctx == NULL || !m_ctx.AllowsDiagnostics()) return;
   _Emit(LOG_INFO, category, msg);
  }

//+------------------------------------------------------------------+
void Logger::Warn(const string category, const string msg)
  {
   if(m_ctx == NULL || !m_ctx.AllowsDiagnostics()) return;
   _Emit(LOG_WARN, category, msg);
  }

//+------------------------------------------------------------------+
void Logger::Error(const string category, const string msg)
  {
//--- Error always emits regardless of mode (except optimization silences everything).
   if(m_ctx != NULL && m_ctx.IsOptimizing()) return;
   _Emit(LOG_ERROR, category, msg);
  }

#endif // TRADESPINE_PERSISTENCE_LOGGER_MQH
//+------------------------------------------------------------------+
