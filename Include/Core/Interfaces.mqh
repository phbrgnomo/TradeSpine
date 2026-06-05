//+------------------------------------------------------------------+
//|                                                    Interfaces.mqh |
//|              Copyright 2026, Paulo Henrique Barreto Reboucas      |
//|                                                                  |
//| @code: Include/Core/Interfaces.mqh                               |
//| @spec: SPEC-09  @iplan: IPLAN-09                                 |
//|                                                                  |
//| Stable shared seams for the core runtime: a time-source clock,   |
//| a diagnostics log sink (primitive params only), the runtime/     |
//| profiling data models, and concrete test doubles.                |
//|                                                                  |
//| SPEC-09 faithful, minimal scope. Trade/position/state seams      |
//| (ITradePort, IPositionView, IStateStore) are intentionally       |
//| DEFERRED to their owning SPECs because their payload types        |
//| (TradeIntent, GuardResult, ledger snapshots) are not built yet:  |
//|   - ITradePort / GuardResult / TradeIntent -> @spec: SPEC-03     |
//|   - IPositionView                          -> @spec: SPEC-04     |
//|   - IStateStore                            -> @spec: SPEC-05     |
//| They will be added by those SPECs' IPLANs to avoid churn here.   |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_INTERFACES_MQH
#define TRADESPINE_INTERFACES_MQH

//+------------------------------------------------------------------+
//| Log levels for the diagnostics sink.                             |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
  {
   LOG_DEBUG = 0,
   LOG_INFO  = 1,
   LOG_WARN  = 2,
   LOG_ERROR = 3
  };

//+------------------------------------------------------------------+
//| IClock - time-source seam. Lets tests inject deterministic time  |
//| without depending on TimeCurrent() directly.                     |
//+------------------------------------------------------------------+
interface IClock
  {
   datetime Now(void);
  };

//+------------------------------------------------------------------+
//| ILogSink - diagnostics seam (primitive params only). Concrete    |
//| CSV/journal sinks arrive with the evidence IPLANs (IPLAN-10+).   |
//+------------------------------------------------------------------+
interface ILogSink
  {
   void Write(const int level, const string category, const string message);
  };

//+------------------------------------------------------------------+
//| RuntimeMode - injectable runtime-mode snapshot (SPEC-09 model).  |
//+------------------------------------------------------------------+
struct RuntimeMode
  {
   bool is_tester;          // inside Strategy Tester
   bool is_optimization;    // optimization pass
   bool diagnostics_enabled;// detailed diagnostics allowed for this mode
  };

//+------------------------------------------------------------------+
//| ProfileSample - one timing measurement (SPEC-09 model).          |
//+------------------------------------------------------------------+
struct ProfileSample
  {
   string scope;       // measured component or operation
   long   elapsed_us;  // elapsed microseconds
   bool   enabled;     // collected under the active profiling policy
  };

//+------------------------------------------------------------------+
//| BenchmarkBaseline - memory baseline-and-delta evidence record.   |
//+------------------------------------------------------------------+
struct BenchmarkBaseline
  {
   string scenario;               // benchmark scenario name
   long   baseline_memory;        // memory before component under test
   long   component_memory_delta; // measured delta for per-EA budget
   string timing_source;          // runtime timing source used
  };

//+------------------------------------------------------------------+
//| FakeClock - deterministic IClock test double.                    |
//+------------------------------------------------------------------+
class FakeClock : public IClock
  {
private:
   datetime m_now;
public:
                     FakeClock(void) { m_now = 0; }
   void              Set(const datetime t) { m_now = t; }
   void              Advance(const int seconds) { m_now += seconds; }
   datetime          Now(void) override { return(m_now); }
  };

//+------------------------------------------------------------------+
//| CapturingLogSink - ILogSink test double that counts writes so    |
//| tests can prove "no persistent writes" when diagnostics gated.   |
//+------------------------------------------------------------------+
class CapturingLogSink : public ILogSink
  {
private:
   int    m_count;
   string m_last;
public:
                     CapturingLogSink(void) { m_count = 0; m_last = ""; }
   void              Write(const int level, const string category, const string message) override
     {
      m_count++;
      m_last = StringFormat("[%d] %s: %s", level, category, message);
     }
   int               Count(void) const { return(m_count); }
   string            Last(void) const  { return(m_last); }
   void              Reset(void)       { m_count = 0; m_last = ""; }
  };

#endif // TRADESPINE_INTERFACES_MQH
//+------------------------------------------------------------------+
