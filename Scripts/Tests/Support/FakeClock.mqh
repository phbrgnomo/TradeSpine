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
   //+------------------------------------------------------------------+
   //| \brief Construct a fake clock at epoch 0.                         |
   //+------------------------------------------------------------------+
   FakeClock(void)
     {
      m_now = 0;
     }

   //+------------------------------------------------------------------+
   //| \brief Set the fake clock to an absolute timestamp.               |
   //| \param t Timestamp to return from subsequent Now() calls.         |
   //+------------------------------------------------------------------+
   void Set(const datetime t)
     {
      m_now = t;
     }

   //+------------------------------------------------------------------+
   //| \brief Advance the fake clock by a non-negative number of seconds.|
   //| \param seconds Seconds to add; negative values are rejected.      |
   //+------------------------------------------------------------------+
   void Advance(const int seconds)
     {
      if(seconds < 0)
        {
        PrintFormat("FakeClock::Advance(%d) rejected — negative advance is unsupported.", seconds);
        return;
        }
      m_now += seconds;
     }

   //+------------------------------------------------------------------+
   //| \brief Return the deterministic fake-clock value.                 |
   //| \return Last value set by Set() or accumulated by Advance().      |
   //+------------------------------------------------------------------+
   datetime Now(void) override
     {
      return(m_now);
     }
  };

#endif // TRADESPINE_TEST_SUPPORT_FAKE_CLOCK_MQH
//+------------------------------------------------------------------+
