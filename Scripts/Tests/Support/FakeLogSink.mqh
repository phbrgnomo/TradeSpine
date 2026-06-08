//+------------------------------------------------------------------+
//|                                                 FakeLogSink.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| Capturing ILogSink implementation for IPLAN-11 test scripts.    |
//| Records Write() calls in a ring buffer; query methods let tests  |
//| assert on captured messages without production logging side      |
//| effects. @spec: SPEC-11  @iplan: IPLAN-11                        |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_TEST_SUPPORT_FAKE_LOG_SINK_MQH
#define TRADESPINE_TEST_SUPPORT_FAKE_LOG_SINK_MQH

#include "../../../Include/Core/Interfaces.mqh"

#define FAKE_LOG_SINK_CAPACITY 256

//+------------------------------------------------------------------+
//| FakeLogSink                                                      |
//+------------------------------------------------------------------+
class FakeLogSink : public ILogSink
  {
private:
   ENUM_LOG_LEVEL    m_levels[FAKE_LOG_SINK_CAPACITY];
   string            m_categories[FAKE_LOG_SINK_CAPACITY];
   string            m_messages[FAKE_LOG_SINK_CAPACITY];
   int               m_count;

public:
   FakeLogSink(void) : m_count(0) {}

   void Write(const ENUM_LOG_LEVEL level, const string category, const string message) override
     {
      if(m_count >= FAKE_LOG_SINK_CAPACITY)
         return;
      m_levels[m_count]     = level;
      m_categories[m_count] = category;
      m_messages[m_count]   = message;
      m_count++;
     }

   int Count(void) const { return(m_count); }

   bool HasMessage(const string fragment) const
     {
      for(int i = 0; i < m_count; i++)
         if(StringFind(m_messages[i], fragment) >= 0)
            return(true);
      return(false);
     }

   string GetMessage(const int idx) const
     {
      if(idx < 0 || idx >= m_count)
         return("");
      return(m_messages[idx]);
     }

   ENUM_LOG_LEVEL GetLevel(const int idx) const
     {
      if(idx < 0 || idx >= m_count)
         return(LOG_DEBUG);
      return(m_levels[idx]);
     }

   void Clear(void)
     {
      m_count = 0;
     }
  };

#endif // TRADESPINE_TEST_SUPPORT_FAKE_LOG_SINK_MQH
//+------------------------------------------------------------------+
