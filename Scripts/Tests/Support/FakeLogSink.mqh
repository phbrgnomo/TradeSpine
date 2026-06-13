//+------------------------------------------------------------------+
//|                                                 FakeLogSink.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| Capturing ILogSink implementation for IPLAN-11 test scripts.    |
//| Records Write() calls in a fixed-capacity capture buffer; query  |
//| assert on captured messages without production logging side      |
//| effects. @spec: SPEC-11  @iplan: IPLAN-11                        |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_TEST_SUPPORT_FAKE_LOG_SINK_MQH
#define TRADESPINE_TEST_SUPPORT_FAKE_LOG_SINK_MQH

#include "../../../Include/Core/Interfaces.mqh"

// Fixed test buffer limit: keeps evidence capture deterministic and bounded.
// Overflow is observable via HasOverflow(); this is not a system memory limit.
#define FAKE_LOG_SINK_CAPACITY 256

//+------------------------------------------------------------------+
//| \brief FakeLogSink - capturing ILogSink for tests; records       |
//|        Write() calls in a fixed buffer for query/assertion with  |
//|        no production logging side effects.                        |
//+------------------------------------------------------------------+
class FakeLogSink : public ILogSink
  {
private:
  ENUM_LOG_LEVEL    m_levels[FAKE_LOG_SINK_CAPACITY];
  string            m_categories[FAKE_LOG_SINK_CAPACITY];
  string            m_messages[FAKE_LOG_SINK_CAPACITY];
  int               m_count;
  bool              m_overflow;
  bool              m_overflow_warning_logged;

public:
  FakeLogSink(void) : m_count(0), m_overflow(false), m_overflow_warning_logged(false) {}

   // Captures the write into the fixed buffer, or sets the overflow flag and discards if full.
   void Write(const ENUM_LOG_LEVEL level, const string category, const string message) override
     {
      if(m_count >= FAKE_LOG_SINK_CAPACITY)
      {
      m_overflow = true;
      if(!m_overflow_warning_logged)
        {
        Print("FakeLogSink capacity exceeded; discarding subsequent log messages");
        m_overflow_warning_logged = true;
        }
      return;
      }
      m_levels[m_count]     = level;
      m_categories[m_count] = category;
      m_messages[m_count]   = message;
      m_count++;
     }

   // Returns the number of messages retained (capped at FAKE_LOG_SINK_CAPACITY).
   int Count(void) const { return(m_count); }

   // True if any Write() call was discarded due to buffer exhaustion.
  bool HasOverflow(void) const { return(m_overflow); }

   // Searches all retained messages for fragment; empty fragment always returns false.
   bool HasMessage(const string fragment) const
     {
      if(StringLen(fragment) == 0)
         return(false);
      for(int i = 0; i < m_count; i++)
         if(StringFind(m_messages[i], fragment) >= 0)
            return(true);
      return(false);
     }

   // Returns the captured message text at the given index, or "" if out of range.
   string GetMessage(const int idx) const
     {
      if(idx < 0 || idx >= m_count)
         return("");
      return(m_messages[idx]);
     }

   // Returns the log level of the entry at idx; returns (ENUM_LOG_LEVEL)-1 if out of range.
   ENUM_LOG_LEVEL GetLevel(const int idx) const
     {
      if(idx < 0 || idx >= m_count)
         return((ENUM_LOG_LEVEL) - 1);
      return(m_levels[idx]);
     }

   // Returns the category string of the entry at idx, or "" if out of range.
   string GetCategory(const int idx) const
     {
      if(idx < 0 || idx >= m_count)
         return("");
      return(m_categories[idx]);
     }

   // True only when a retained entry matches both exact category and contains trace_fragment.
   bool HasMessageInCategory(const string category, const string trace_fragment) const
     {
      if(StringLen(trace_fragment) == 0)
         return(false);
      for(int i = 0; i < m_count; i++)
         if(m_categories[i] == category && StringFind(m_messages[i], trace_fragment) >= 0)
            return(true);
      return(false);
     }

   // Resets count, overflow flag, and warning guard so the sink can be reused between sub-tests.
   void Clear(void)
     {
    m_count                   = 0;
    m_overflow                = false;
    m_overflow_warning_logged = false;
     }
  };

#endif // TRADESPINE_TEST_SUPPORT_FAKE_LOG_SINK_MQH
//+------------------------------------------------------------------+
