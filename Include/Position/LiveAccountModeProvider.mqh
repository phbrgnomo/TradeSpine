//+------------------------------------------------------------------+
//| @code: Include/Position/LiveAccountModeProvider.mqh              |
//| @spec: SPEC-04 @tdd: TDD.04.04.c6e1 @iplan: IPLAN-04            |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_POSITION_LIVEACCOUNTMODEPROVIDER_MQH
#define TRADESPINE_POSITION_LIVEACCOUNTMODEPROVIDER_MQH

#include "Interfaces.mqh"
#include "../StdLib/Trade/AccountInfo.mqh"

//+------------------------------------------------------------------+
//| \brief Read-only terminal-backed account-mode provider.          |
//+------------------------------------------------------------------+
class CLiveAccountModeProvider : public IAccountModeProvider
  {
  private:
   CAccountInfo m_account;
  public:
   //--- \brief Return the current terminal account margin mode.
   //--- \return Terminal ACCOUNT_MARGIN_MODE value.
   ENUM_ACCOUNT_MARGIN_MODE MarginMode() override { return(m_account.MarginMode()); }
  };

#endif
//+------------------------------------------------------------------+
