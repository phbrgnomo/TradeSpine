//+------------------------------------------------------------------+
//|                                              PositionTypes.mqh   |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Position/PositionTypes.mqh                        |
//| @spec: SPEC-04  @tdd: TDD.04.04.8b79  @iplan: IPLAN-04           |
//|                                                                  |
//| Shared position/account-mode enums for the TradeSpine position   |
//| layer. Persistence-owned marker types remain in Persistence.     |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_POSITION_POSITIONTYPES_MQH
#define TRADESPINE_POSITION_POSITIONTYPES_MQH

//+------------------------------------------------------------------+
//| \brief Default pending-entry fill timeout in seconds.            |
//+------------------------------------------------------------------+
#define POSITION_FILL_TIMEOUT_SECS_DEFAULT 5

//+------------------------------------------------------------------+
//| \brief Maximum wait for broker cancellation confirmation.       |
//+------------------------------------------------------------------+
#define POSITION_CANCEL_CONFIRM_TIMEOUT_SECS 5

//+------------------------------------------------------------------+
//| \brief ENUM_CLOSE_REASON - why an open position was closed.      |
//+------------------------------------------------------------------+
enum ENUM_CLOSE_REASON
  {
   CR_NONE              = 0, //!< No close reason recorded.
   CR_STRATEGY_EXIT     = 1, //!< Strategy-authored exit signal.
   CR_DAY_TRADE_CLOSE   = 2, //!< Day-trade close gate.
   CR_PANIC             = 3, //!< Emergency close path.
   CR_EXTERNAL          = 4, //!< Position closed outside TradeSpine.
   CR_EXTERNAL_REPAIRED = 5  //!< External SL/TP intervention was repaired.
  };

//+------------------------------------------------------------------+
//| \brief ENUM_STATE_TRIGGER - normalized state-machine trigger.    |
//+------------------------------------------------------------------+
enum ENUM_STATE_TRIGGER
  {
   STATE_TRIGGER_NONE          = 0,
   STATE_TRIGGER_ENTRY_SENT    = 1,
   STATE_TRIGGER_FILL          = 2,
   STATE_TRIGGER_REJECT        = 3,
   STATE_TRIGGER_CANCEL_SENT   = 4,
   STATE_TRIGGER_CANCELLED     = 5,
   STATE_TRIGGER_POSITION_DONE = 6,
   STATE_TRIGGER_HALT          = 7
  };

//+------------------------------------------------------------------+
//| \brief ENUM_RECOVERY_DECISION - restart reconciliation outcome.  |
//+------------------------------------------------------------------+
enum ENUM_RECOVERY_DECISION
  {
   RECOVERY_NONE             = 0,
   RECOVERY_FLAT            = 1,
   RECOVERY_ACTIVE          = 2,
   RECOVERY_PENDING_ENTRY   = 3,
   RECOVERY_PENDING_CANCEL  = 4,
   RECOVERY_HALT            = 5
  };

//+------------------------------------------------------------------+
//| \brief ENUM_EXIT_ROLE - role of an exit/cancel action.           |
//+------------------------------------------------------------------+
enum ENUM_EXIT_ROLE
  {
   EXIT_ROLE_NONE            = 0,
   EXIT_ROLE_STRATEGY_EXIT   = 1,
   EXIT_ROLE_TIMEOUT_CANCEL  = 2,
   EXIT_ROLE_EXTERNAL_CANCEL = 3,
   EXIT_ROLE_MANUAL_CLOSE    = 4
  };

#endif // TRADESPINE_POSITION_POSITIONTYPES_MQH
//+------------------------------------------------------------------+
