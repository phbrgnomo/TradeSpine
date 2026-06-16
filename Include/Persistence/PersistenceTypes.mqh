//+------------------------------------------------------------------+
//|                                             PersistenceTypes.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Persistence/PersistenceTypes.mqh                  |
//| @spec: SPEC-05  @tdd: TDD.05.04.229f  @iplan: IPLAN-05           |
//|                                                                  |
//| Shared type definitions used by more than one Persistence module.|
//| Kept here to avoid spurious coupling between modules that share  |
//| a type but have no other dependency on each other.               |
//|                                                                  |
//| Consumers:                                                       |
//|   StateStore.mqh  — transitively re-exports for compatibility.   |
//|   TradeLogger.mqh — includes directly (no StateStore dependency).|
//+------------------------------------------------------------------+
#ifndef TRADESPINE_PERSISTENCE_PERSISTENCETYPES_MQH
#define TRADESPINE_PERSISTENCE_PERSISTENCETYPES_MQH

//+------------------------------------------------------------------+
//| \brief ENUM_TRADE_RECORD_TYPE - discriminates CSV evidence rows. |
//|        Shared by StateStore and TradeLogger; defined here to     |
//|        avoid TradeLogger depending on the full StateStore header.|
//+------------------------------------------------------------------+
enum ENUM_TRADE_RECORD_TYPE
  {
   TRADE_RECORD_INTENT    = 0, //!< Pre-submit intent row.
   TRADE_RECORD_EXECUTION = 1  //!< Post-result execution row.
  };

#endif // TRADESPINE_PERSISTENCE_PERSISTENCETYPES_MQH
//+------------------------------------------------------------------+
