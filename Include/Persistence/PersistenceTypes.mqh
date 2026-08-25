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
//|   MarkerLease.mqh — includes the marker claim result directly.   |
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

//+------------------------------------------------------------------+
//| \brief ENUM_DUPLICATE_MARKER_STATUS - result of a token-fenced   |
//|        duplicate marker lease claim.                             |
//| \return One stable marker-claim outcome value.                    |
//|                                                                  |
//| Kept in PersistenceTypes to avoid a Persistence -> Position      |
//| include cycle when IPLAN-04 consumes the marker lease.           |
//+------------------------------------------------------------------+
enum ENUM_DUPLICATE_MARKER_STATUS
  {
   DUPLICATE_MARKER_ACTIVE          = 0, //!< Claim succeeded from a free marker.
   DUPLICATE_MARKER_STALE_RECLAIMED = 1, //!< Claim succeeded by reclaiming a stale owner.
   DUPLICATE_MARKER_CONFLICT        = 2  //!< Another owner is fresh, or CAS/write failed.
  };

#endif // TRADESPINE_PERSISTENCE_PERSISTENCETYPES_MQH
//+------------------------------------------------------------------+
