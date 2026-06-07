//+------------------------------------------------------------------+
//|                                                    FakeClock.mqh |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| Deterministic IClock implementation for MQL5 test scripts.       |
//| Implements the Core IClock contract without entering production  |
//| execution paths.                                                 |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_TEST_SUPPORT_FAKE_CLOCK_MQH
#define TRADESPINE_TEST_SUPPORT_FAKE_CLOCK_MQH

#include "../../../Include/Core/Interfaces.mqh"

//+------------------------------------------------------------------+
//| FakeClock                                                        |
//+------------------------------------------------------------------+
class FakeClock : public IClock
  {
private:
   datetime m_now;

public:
   FakeClock(void)
     {
      m_now = 0;
     }

   void Set(const datetime t)
     {
      m_now = t;
     }

   void Advance(const int seconds)
     {
      m_now += seconds;
     }

   datetime Now(void) override
     {
      return(m_now);
     }
  };

#endif // TRADESPINE_TEST_SUPPORT_FAKE_CLOCK_MQH
//+------------------------------------------------------------------+
