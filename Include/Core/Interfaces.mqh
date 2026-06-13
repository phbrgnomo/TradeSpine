//+------------------------------------------------------------------+
//|                                                   Interfaces.mqh |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Core/Interfaces.mqh                               |
//| @spec: SPEC-09  @iplan: IPLAN-09                                 |
//|                                                                  |
//| Stable shared seams for the core runtime: a time-source clock,   |
//| a diagnostics log sink (primitive params only), and the runtime/ |
//| profiling data models consumed by production and test modules.   |
//|                                                                  |
//| SPEC-09 faithful, minimal scope. Trade/position/state seams      |
//| (ITradePort, IPositionView, IStateStore) are intentionally       |
//| DEFERRED to their owning SPECs because their payload types       |
//| (TradeIntent, GuardResult, ledger snapshots) are not built yet:  |
//|   - ITradePort / GuardResult / TradeIntent -> @spec: SPEC-03     |
//|   - IPositionView                          -> @spec: SPEC-04     |
//|   - IStateStore                            -> @spec: SPEC-05     |
//| They will be added by those SPECs' IPLANs to avoid churn here.   |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_INTERFACES_MQH
#define TRADESPINE_INTERFACES_MQH

//+------------------------------------------------------------------+
//| \brief Log levels for the diagnostics sink.                      |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
  {
   LOG_DEBUG = 0,
   LOG_INFO  = 1,
   LOG_WARN  = 2,
   LOG_ERROR = 3
  };

//+------------------------------------------------------------------+
//| \brief IClock - time-source seam. Lets tests inject              |
//|        deterministic time without depending on TimeCurrent().    |
//+------------------------------------------------------------------+
interface IClock
  {
   //--- \brief  Current time. \return Now per the implementation's source.
   datetime Now(void);
  };

//+------------------------------------------------------------------+
//| \brief ILogSink - diagnostics seam (primitive params only).      |
//|        Concrete CSV/journal sinks arrive with the evidence       |
//|        IPLANs (IPLAN-10+).                                       |
//+------------------------------------------------------------------+
interface ILogSink
  {
   //--- \brief  Emit one diagnostic line.
   //--- \param  level     Severity (LOG_DEBUG..LOG_ERROR).
   //--- \param  category  Short routing/topic tag.
   //--- \param  message   Human-readable message text.
   void Write(const ENUM_LOG_LEVEL level, const string category, const string message);
  };

//+------------------------------------------------------------------+
//| \brief RuntimeMode - injectable runtime-mode snapshot            |
//|        (SPEC-09 model).                                          |
//+------------------------------------------------------------------+
struct RuntimeMode
  {
   bool is_tester;          // inside Strategy Tester
   bool is_optimization;    // optimization pass
   bool diagnostics_enabled;// detailed diagnostics allowed for this mode
  };

//+------------------------------------------------------------------+
//| \brief ProfileSample - one timing measurement (SPEC-09 model).   |
//+------------------------------------------------------------------+
struct ProfileSample
  {
   string scope;       // measured component or operation
   long   elapsed_us;  // elapsed microseconds
   bool   enabled;     // collected under the active profiling policy
  };

//+------------------------------------------------------------------+
//| \brief BenchmarkBaseline - memory baseline-and-delta evidence    |
//|        record.                                                  |
//+------------------------------------------------------------------+
struct BenchmarkBaseline
  {
   string scenario;               // benchmark scenario name
   long   baseline_memory;        // memory before component under test
   long   component_memory_delta; // measured delta (MB); negative = noise/GC, not savings
   string timing_source;          // runtime timing source used
  };

#endif // TRADESPINE_INTERFACES_MQH
//+------------------------------------------------------------------+
