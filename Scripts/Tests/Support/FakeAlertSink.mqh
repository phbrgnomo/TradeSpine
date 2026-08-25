//+------------------------------------------------------------------+
//|                                              FakeAlertSink.mqh   |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Support/FakeAlertSink.mqh                  |
//| @spec: SPEC-04,SPEC-05  @tdd: TDD.04.04.8b79  @iplan: IPLAN-04   |
//|                                                                  |
//| Reusable IAlertSink fake. It captures payloads and can forward   |
//| HALT to a composed FakeStateStore to mirror production routing.  |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_TEST_SUPPORT_FAKEALERTSINK_MQH
#define TRADESPINE_TEST_SUPPORT_FAKEALERTSINK_MQH

#include "../../../Include/Persistence/AlertSink.mqh"
#include "FakeStateStore.mqh"

//+------------------------------------------------------------------+
//| \brief FakeAlertSink - capturing alert sink with optional store. |
//+------------------------------------------------------------------+
class FakeAlertSink : public IAlertSink
  {
  private:
   FakeStateStore* m_store;

  public:
   int             halt_calls;
   int             warn_calls;
   HaltEvidence    last_halt;
   string          last_warn_category;
   string          last_warn_message;

                   FakeAlertSink(void) : m_store(NULL),
                                         halt_calls(0),
                                         warn_calls(0),
                                         last_warn_category(""),
                                         last_warn_message("") {}

   //--- \brief Bind optional fake state store for HALT forwarding.
   //--- \param store Optional store receiving SetHalt(ev).
   void            Init(FakeStateStore* store = NULL) { m_store = store; }
   //--- \brief Capture HALT evidence and forward to bound fake store.
   //--- \param ev HALT evidence payload.
   //--- \return true when the bound fake store persists HALT evidence.
   bool            Halt(const HaltEvidence &ev) override;
   //--- \brief Capture warning category and message.
   //--- \param category Warning category.
   //--- \param msg Warning message.
   void            Warn(string category, string msg) override;
  };

//+------------------------------------------------------------------+
bool FakeAlertSink::Halt(const HaltEvidence &ev)
  {
   halt_calls++;
   last_halt = ev;
   if(m_store != NULL)
      return(m_store.SetHalt(ev));
   return(false);
  }

//+------------------------------------------------------------------+
void FakeAlertSink::Warn(string category, string msg)
  {
   warn_calls++;
   last_warn_category = category;
   last_warn_message = msg;
  }

#endif // TRADESPINE_TEST_SUPPORT_FAKEALERTSINK_MQH
//+------------------------------------------------------------------+
