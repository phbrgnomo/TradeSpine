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
//| \brief CNewBarDetector - detects bar transitions by comparing    |
//|        the current bar open time against the stored last-bar      |
//|        time (gap-safe; not a tick counter).                      |
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
      // Binds to _Symbol/_Period (chart context). For multi-symbol use,
      // call SetSymbolAndTimeframe() before the first IsNewBar() call.
      m_symbol        = _Symbol;
      m_timeframe     = (ENUM_TIMEFRAMES)_Period;
      m_last_bar_time = 0;
    }

   //--- \brief Bind the detector to a symbol/timeframe and re-arm it.
   //--- \param symbol_     Symbol to track.
   //--- \param timeframe_  Timeframe to track.
  void SetSymbolAndTimeframe(const string symbol_, const ENUM_TIMEFRAMES timeframe_)
    {
      m_symbol        = symbol_;
      m_timeframe     = timeframe_;
      m_last_bar_time = 0;
    }

   //--- \brief Injectable overload: pure state machine, no system calls.
   //---        Used directly by Tier-1 tests for deterministic coverage.
   //--- \param t  Candidate bar-open time.
   //--- \return true on a bar transition (and updates state); false when
   //---         t=0 (unavailable), t goes backwards (sync anomaly), or t
   //---         equals the last seen bar time.
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

   //--- \brief Production overload: reads SERIES_LASTBAR_DATE from terminal
   //---        metadata (no bar-buffer copy), then delegates to the injectable
   //---        overload.
   //--- \return true on a confirmed bar transition; false when history/time
   //---         context is unavailable.
   //--- SeriesInfoInteger is preferred over iTime(s,tf,0) for hot-path use:
   //--- it reads a single metadata field rather than accessing the timeseries
   //--- buffer (pattern from CisNewBar/IsNewBar community references).
   //---
   //--- NOTE: When SeriesInfoInteger returns false (terminal not yet synced,
   //--- history not loaded), state is unchanged and false is returned.
   //--- On the first successful read after a sync gap, m_last_bar_time is 0,
   //--- so the call will return true for whatever bar is current — this is
   //--- intentional: the "first confirmed bar" event. Callers that have already
   //--- acted on a bar and then lost/regained sync should call Reset() on
   //--- reconnect to suppress a spurious re-fire.
  bool IsNewBar(void)
    {
      datetime t = 0;
      if(!SeriesInfoInteger(m_symbol, m_timeframe, SERIES_LASTBAR_DATE, t))
         return(false);
      return(IsNewBar(t));
    }

  //--- \brief Last bar-open time recorded. \return Stored last-bar time (0 if unarmed).
  datetime GetLastBarTime(void) const { return(m_last_bar_time); }

  //--- \brief Re-arm so the next valid bar is reported as new.
  void Reset(void) { m_last_bar_time = 0; }
  };

#endif // TRADESPINE_NEW_BAR_DETECTOR_MQH
//+------------------------------------------------------------------+
