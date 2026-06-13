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
//| \brief FakeClock - deterministic IClock for tests; time advances |
//|        only via Set()/Advance(), never from TimeCurrent().       |
//+------------------------------------------------------------------+
class FakeClock : public IClock
  {
private:
   datetime m_now;

public:
   // Starts at epoch 0 so tests begin from a known, unambiguous baseline.
   FakeClock(void)
     {
      m_now = 0;
     }

   // Jumps the clock to an absolute timestamp, replacing any prior state.
   void Set(const datetime t)
     {
      m_now = t;
     }

   // Moves the clock forward by N seconds; negative values are rejected — backward movement is
   // unsupported and likely a test authoring error.
   void Advance(const int seconds)
     {
      if(seconds < 0)
        {
        PrintFormat("FakeClock::Advance(%d) rejected — negative advance is unsupported.", seconds);
        return;
        }
      m_now += seconds;
     }

   // Returns the last value set via Set() or accumulated via Advance(); never calls TimeCurrent().
   datetime Now(void) override
     {
      return(m_now);
     }
  };

#endif // TRADESPINE_TEST_SUPPORT_FAKE_CLOCK_MQH
//+------------------------------------------------------------------+
