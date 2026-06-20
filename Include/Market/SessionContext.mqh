//+------------------------------------------------------------------+
//|                                              SessionContext.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Market/SessionContext.mqh                         |
//| @spec: SPEC-06  @tdd: TDD.06.04.4796  @iplan: IPLAN-06          |
//|                                                                  |
//| Evaluates three session/time gates on every call to Evaluate():  |
//|   market_open              — caller-supplied broker session flag  |
//|   user_trading_hours_open  — time-of-day within entry window     |
//|   day_trade_close_required — close buffer reached before close   |
//| All time arithmetic uses broker/server time via IClock.          |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_MARKET_SESSION_CONTEXT_MQH
#define TRADESPINE_MARKET_SESSION_CONTEXT_MQH

#include "../Core/Interfaces.mqh"
#include "../Core/CommonInputs.mqh"

//+------------------------------------------------------------------+
//| \brief Snapshot of the three session gate states for one tick.  |
//|        Default constructor sets every flag false (most           |
//|        restrictive state).                                       |
//+------------------------------------------------------------------+
struct SessionWindow
  {
   bool market_open;              // broker market-session schedule is open
   bool user_trading_hours_open;  // current time is within operator entry window
   bool day_trade_close_required; // day-trade close sequence must run now

   //--- \brief Default constructor: all gates closed.
   SessionWindow(void) : market_open(false),
                         user_trading_hours_open(false),
                         day_trade_close_required(false)
     {
     }
  };

//+------------------------------------------------------------------+
//| \brief CSessionContext — evaluates market session, user trading  |
//|        hours, and day-trade close trigger on demand. Pure time   |
//|        logic: does not call any broker APIs; time source is      |
//|        injected via IClock. Broker session membership is supplied |
//|        by the caller each call to Evaluate().                     |
//+------------------------------------------------------------------+
class CSessionContext
  {
private:
   CommonInputs       m_inputs;
   IClock            *m_clock;              // not owned
   bool               m_session_end_warned; // true after the first per-init fallback warning

public:
   //+------------------------------------------------------------------+
   //| \brief Default constructor: context not ready (clock = NULL).    |
   //+------------------------------------------------------------------+
   CSessionContext(void) : m_clock(NULL), m_session_end_warned(false)
     {
     }

   //+------------------------------------------------------------------+
   //| \brief Initialize with framework inputs and an IClock instance.  |
   //| \param inputs  CommonInputs carrying day-trade and window config.|
   //| \param clock   Time source; must not be NULL.                   |
   //+------------------------------------------------------------------+
   void Init(const CommonInputs &inputs, IClock *clock)
     {
      m_inputs             = inputs;
      m_session_end_warned = false; // reset so the first missing-end warning fires again
      m_clock  = (CheckPointer(clock) != POINTER_INVALID) ? clock : NULL;
      if(m_clock == NULL)
         Print("[ERROR] CSessionContext::Init — null clock pointer; Evaluate() will return all-closed.");
     }

   //+------------------------------------------------------------------+
   //| \brief Compute the three session gates for the current tick.    |
   //| \param market_session_open  True when the current time is inside |
   //|         the broker market-session schedule.                      |
   //| \param market_session_end_tod End of the broker market session   |
   //|         in seconds-from-midnight, or -1 when unavailable. Only    |
   //|         consulted when close_reference == MARKET_SESSION_END.     |
   //| \return SessionWindow struct with the three gate flags set.     |
   //+------------------------------------------------------------------+
   SessionWindow Evaluate(const bool market_session_open,
                          const int  market_session_end_tod = -1)
     {
      SessionWindow w;
      if(m_clock == NULL)
         return(w); // all-closed, logged at Init

      w.market_open = market_session_open;

      datetime now = m_clock.Now();
      int      tod = (int)(now % 86400); // seconds since midnight (broker time)

      // --- user trading hours gate ---
      if(m_inputs.day_trade_mode)
        {
         int start_tod = (int)(m_inputs.entry_window_start % 86400);
         int end_tod   = (int)(m_inputs.entry_window_end   % 86400);
         w.user_trading_hours_open = (tod >= start_tod && tod < end_tod);

         // --- day-trade close trigger ---
         // The reference subtracted from is either the user window end or the
         // broker market session end, per CommonInputs.close_reference.
         int close_ref_tod = end_tod;
         if(m_inputs.close_reference == CLOSE_REF_MARKET_SESSION_END)
           {
            if(market_session_end_tod > 0)
               close_ref_tod = market_session_end_tod;
            else
              {
               if(!m_session_end_warned)
                 {
                  Print("[WARN] CSessionContext::Evaluate — close_reference=MARKET_SESSION_END "
                        "but market session end unavailable; falling back to entry_window_end.");
                  m_session_end_warned = true;
                 }
              }
           }
         int close_trigger_tod = close_ref_tod - m_inputs.close_mins_before * 60;
         w.day_trade_close_required = (tod >= close_trigger_tod);
        }
      else
        {
         // When not in day-trade mode the user window is always open
         // and forced close is never triggered.
         w.user_trading_hours_open  = true;
         w.day_trade_close_required = false;
        }

      return(w);
     }

   //+------------------------------------------------------------------+
   //| \brief Whether the context is ready to evaluate sessions.        |
   //| \return true when Init() was called with a non-null clock.      |
   //+------------------------------------------------------------------+
   bool IsReady(void) const
     {
      return(m_clock != NULL);
     }
  };

#endif // TRADESPINE_MARKET_SESSION_CONTEXT_MQH
//+------------------------------------------------------------------+
