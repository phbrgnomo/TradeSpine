//+------------------------------------------------------------------+
//|                                                NewBarDetector.mqh |
//|              Copyright 2026, Paulo Henrique Barreto Reboucas      |
//|                                                                  |
//| @code: Include/Core/NewBarDetector.mqh                           |
//| @spec: SPEC-09  @iplan: IPLAN-09                                 |
//|                                                                  |
//| Bar-transition detector for strategy hook code. Compares the     |
//| current bar's open time against the stored last-bar time, so it  |
//| survives connection-drop gaps (it is NOT a tick counter).        |
//| Returns false when history/time context is unavailable. Runtime  |
//| state only - no GV persistence. No broker execution APIs.        |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_NEW_BAR_DETECTOR_MQH
#define TRADESPINE_NEW_BAR_DETECTOR_MQH

//+------------------------------------------------------------------+
//| CNewBarDetector                                                  |
//+------------------------------------------------------------------+
class CNewBarDetector
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   datetime          m_last_bar_time;

public:
                     CNewBarDetector(void)
     {
      m_symbol        = _Symbol;
      m_timeframe     = (ENUM_TIMEFRAMES)_Period;
      m_last_bar_time = 0;
     }

   //--- Bind the detector to a symbol/timeframe and re-arm it.
   void              SetSymbolAndTimeframe(const string symbol_, const ENUM_TIMEFRAMES timeframe_)
     {
      m_symbol        = symbol_;
      m_timeframe     = timeframe_;
      m_last_bar_time = 0;
     }

   //--- True only on a bar-boundary transition. The first call after
   //--- (re)arming returns true once a valid bar time is available.
   bool              IsNewBar(void)
     {
      datetime t = iTime(m_symbol, m_timeframe, 0);
      if(t == 0)
         return(false); // history/time context unavailable
      if(t != m_last_bar_time)
        {
         m_last_bar_time = t;
         return(true);
        }
      return(false);
     }

   datetime          GetLastBarTime(void) const { return(m_last_bar_time); }

   //--- Re-arm so the next valid bar is reported as new.
   void              Reset(void) { m_last_bar_time = 0; }
  };

#endif // TRADESPINE_NEW_BAR_DETECTOR_MQH
//+------------------------------------------------------------------+
