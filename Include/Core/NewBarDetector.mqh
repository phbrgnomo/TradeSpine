//+------------------------------------------------------------------+
//|                                               NewBarDetector.mqh |
//|              Copyright 2026, phbr                                |
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
  void SetSymbolAndTimeframe(const string symbol_, const ENUM_TIMEFRAMES timeframe_)
    {
      m_symbol        = symbol_;
      m_timeframe     = timeframe_;
      m_last_bar_time = 0;
    }

   //--- Injectable overload: pure state machine, no system calls.
   //--- t=0          → unavailable context     → false (state unchanged).
   //--- t backwards  → sync anomaly            → false (state unchanged).
   //--- t new        → bar transition          → true  (m_last_bar_time updated).
   //--- t same       → within same bar         → false.
   //--- Used directly by Tier-1 tests for deterministic coverage.
  bool IsNewBar(datetime t)
    {
      if(t == 0)
         return(false);
      if(m_last_bar_time > 0 && t < m_last_bar_time)
         return(false); // backwards-time: sync anomaly, state unchanged
      if(t != m_last_bar_time)
        {
         m_last_bar_time = t;
         return(true);
        }
      return(false);
    }

   //--- Production overload: reads SERIES_LASTBAR_DATE from terminal
   //--- metadata (no bar-buffer copy), then delegates to the injectable
   //--- overload. SeriesInfoInteger is preferred over iTime(s,tf,0) for
   //--- hot-path use: it reads a single metadata field rather than
   //--- accessing the timeseries buffer (pattern from CisNewBar/IsNewBar
   //--- community reference implementations).
  bool IsNewBar(void)
    {
      datetime t = 0;
      if(!SeriesInfoInteger(m_symbol, m_timeframe, SERIES_LASTBAR_DATE, t))
         return(false);
      return(IsNewBar(t));
    }

  datetime GetLastBarTime(void) const { return(m_last_bar_time); }

  //--- Re-arm so the next valid bar is reported as new.
  void Reset(void) { m_last_bar_time = 0; }
  };

#endif // TRADESPINE_NEW_BAR_DETECTOR_MQH
//+------------------------------------------------------------------+
