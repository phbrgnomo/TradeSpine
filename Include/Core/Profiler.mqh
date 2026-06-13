//+------------------------------------------------------------------+
//|                                                     Profiler.mqh |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Core/Profiler.mqh                                 |
//| @spec: SPEC-09  @tdd: TDD.09.04.8050  @iplan: IPLAN-09           |
//|                                                                  |
//| Low-overhead timing and memory-budget evidence helper gated by   |
//| an injected COptContext. When the runtime policy disables         |
//| profiling (BDD.01.03.b37d), Start/Stop return without any I/O or |
//| persistent writes. Memory evidence uses a baseline-and-delta     |
//| harness (EARS.01.03.8044). No broker execution APIs.             |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_PROFILER_MQH
#define TRADESPINE_PROFILER_MQH

#include "Interfaces.mqh"
#include "OptContext.mqh"

#define PROFILER_MAX_SCOPES 64

//+------------------------------------------------------------------+
//| \brief CProfiler - low-overhead scope timing and memory-budget   |
//|        evidence, gated by an injected COptContext policy. All    |
//|        public calls are no-ops when profiling is inactive.       |
//+------------------------------------------------------------------+
class CProfiler
  {
private:
   COptContext      *m_ctx;       // runtime-mode policy (not owned)
   ILogSink         *m_sink;      // optional diagnostics sink (not owned)
   bool              m_enabled;   // master switch (still subject to policy)

   string            m_scope[PROFILER_MAX_SCOPES];
   ulong             m_start_us[PROFILER_MAX_SCOPES];
   long              m_elapsed_us[PROFILER_MAX_SCOPES];
   bool              m_sample_on[PROFILER_MAX_SCOPES];
   int               m_count;
   bool              m_overflow; // true once scope cap was exceeded; guards one-time diagnostic

   //--- Active when both the master switch and the runtime policy agree.
   bool Active(void) const
     {
      if(!m_enabled)
         return(false);
      if(m_ctx == NULL)
         return(false);
      return(m_ctx.AllowsProfiler());
     }

   int FindScope(const string scope) const
     {
      for(int i = 0; i < m_count; i++)
         if(m_scope[i] == scope)
            return(i);
      return(-1);
     }

   int EnsureScope(const string scope)
     {
      int idx = FindScope(scope);
      if(idx >= 0)
         return(idx);
      if(m_count >= PROFILER_MAX_SCOPES)
        {
         if(!m_overflow)
           {
            m_overflow    = true;
            string msg    = StringFormat("Scope cap (%d) reached; '%s' and further scopes dropped",
                                         PROFILER_MAX_SCOPES, scope);
            if(m_sink != NULL)
               m_sink.Write(LOG_WARN, "profiler", msg);
            else
               Print("profiler WARNING: ", msg);
           }
         return(-1);
        }
      idx               = m_count++;
      m_scope[idx]      = scope;
      m_start_us[idx]   = 0;
      m_elapsed_us[idx] = 0;
      m_sample_on[idx]  = false;
      return(idx);
     }

public:
   //--- \brief Construct over a runtime-mode policy and optional sink.
   //--- \param ctx   Runtime-mode policy that gates profiling (not owned).
   //--- \param sink  Optional diagnostics sink for results (not owned).
   CProfiler(COptContext *ctx, ILogSink *sink = NULL)
     {
      m_ctx      = ctx;
      m_sink     = sink;
      m_enabled  = true;
      m_count    = 0;
      m_overflow = false;
     }

   //--- \brief Master enable switch (still subject to runtime policy). \param v New enabled state.
   void SetEnabled(const bool v) { m_enabled = v; }
   //--- \brief Whether profiling is currently collecting. \return true when enabled and policy allows it.
   bool IsActive(void) const     { return(Active()); }

   //--- \brief Begin a measurement block. No-op when inactive.
   //--- \param scope  Scope name (paired with the matching Stop()).
   void              Start(const string scope)
     {
      if(!Active())
         return;
      int idx = EnsureScope(scope);
      if(idx < 0)
         return;
      m_start_us[idx] = GetMicrosecondCount();
     }

   //--- \brief End a measurement block; record the sample. No-op when inactive.
   //--- \param scope  Scope name matching a prior Start().
   //--- Clears m_start_us after recording so a duplicate Stop() sees the
   //--- zero-guard and exits without inflating the sample.
   void Stop(const string scope)
     {
      if(!Active())
         return;
      int idx = FindScope(scope);
      if(idx < 0 || m_start_us[idx] == 0)
         return;
      ulong now_us = GetMicrosecondCount();
      if(now_us < m_start_us[idx])   // clock anomaly / wrap (extremely rare on modern OS)
        { m_start_us[idx] = 0; return; }
      m_elapsed_us[idx] = (long)(now_us - m_start_us[idx]);
      m_sample_on[idx]  = true;
      m_start_us[idx]   = 0; // prevent duplicate Stop() from overwriting the sample
     }

   //--- \brief Retrieve a recorded sample.
   //--- \param scope  Scope name to look up.
   //--- \return The sample; when inactive or unknown, carries enabled=false
   //---         and elapsed_us=0.
   ProfileSample GetSample(const string scope) const
     {
      ProfileSample s;
      s.scope      = scope;
      s.elapsed_us = 0;
      s.enabled    = false;
      int idx = FindScope(scope);
      if(idx >= 0 && m_sample_on[idx] && Active())
        {
         s.elapsed_us = m_elapsed_us[idx];
         s.enabled    = true;
        }
      return(s);
     }

   //--- \brief Human-readable dump of recorded samples.
   //--- \return A "scope=Nus " space-separated summary string.
   string GetResults(void) const
     {
      string out = "";
      for(int i = 0; i < m_count; i++)
         if(m_sample_on[i])
            out += StringFormat("%s=%I64dus ", m_scope[i], m_elapsed_us[i]);
      return(out);
     }

   //--- \brief Print results to the sink (or Print()). No persistent write when inactive.
   void PrintResults(void)
     {
      if(!Active())
         return;
      string r = GetResults();
      if(m_sink != NULL)
         m_sink.Write(LOG_INFO, "profiler", r);
      else
         Print("profiler: ", r);
     }

   //--- \brief Capture the current per-program memory baseline (MB).
   //--- \return MQL_MEMORY_USED, or 0 when inactive.
   //--- Memory evidence (baseline-and-delta harness, in MB).
   //--- Uses MQLInfoInteger(MQL_MEMORY_USED) for per-program attribution;
   //--- TerminalInfoInteger(TERMINAL_MEMORY_USED) tracks the whole agent and
   //--- is too noisy for per-EA budget evidence (SPEC-09 / EARS.01.03.8044).
   //--- MQL_MEMORY_USED is MB-granular; component_memory_delta CAN be negative
   //--- when the runtime GC or an unrelated module releases memory between the
   //--- two reads. A negative value is measurement noise, not a meaningful
   //--- "component saved memory" event. Callers should treat delta <= 0 as
   //--- a no-growth confirmation rather than a signed budget figure.
   long CaptureBaselineMemory(void)
     {
      if(!Active())
         return(0);
      return((long)MQLInfoInteger(MQL_MEMORY_USED));
     }

   //--- \brief Memory growth since a baseline (MB).
   //--- \param baseline  Value from CaptureBaselineMemory().
   //--- \return now - baseline (0 when inactive); delta<=0 means no growth, not savings.
   long RecordMemoryDelta(const long baseline)
     {
      if(!Active())
         return(0);
      long now = (long)MQLInfoInteger(MQL_MEMORY_USED);
      return(now - baseline);
     }

   //--- \brief Assemble a BenchmarkBaseline evidence record for a scenario.
   //--- \param scenario  Benchmark scenario name.
   //--- \param baseline  Value from CaptureBaselineMemory().
   //--- \return Populated BenchmarkBaseline (scenario, baseline, delta, timing source).
   BenchmarkBaseline GetBenchmarkData(const string scenario, const long baseline)
     {
      BenchmarkBaseline b;
      b.scenario               = scenario;
      b.baseline_memory        = baseline;
      b.component_memory_delta = RecordMemoryDelta(baseline);
      b.timing_source          = StringFormat("GetMicrosecondCount|build=%d",
                                              (int)TerminalInfoInteger(TERMINAL_BUILD));
      return(b);
     }
  };

//+------------------------------------------------------------------+
//| Optional macro front-end over a shared instance.                |
//|                                                                 |
//| OWNERSHIP CONTRACT for g_profiler:                              |
//|  - Assign in OnInit() to a heap-allocated or OnInit-scoped      |
//|    CProfiler instance (never a transient local variable).       |
//|  - Set g_profiler = NULL before the pointed-to instance is      |
//|    destroyed (latest in OnDeinit). The macros null-guard so an  |
//|    unassigned pointer is a safe no-op, but a dangling pointer   |
//|    is undefined behavior.                                       |
//|  - All macros short-circuit on IsActive()==false; the scope     |
//|    argument is not evaluated when the profiler is inactive.     |
//+------------------------------------------------------------------+
CProfiler *g_profiler = NULL;

#define PROFILER_START(scope) do { if(g_profiler != NULL && g_profiler.IsActive()) g_profiler.Start(scope); } while(false)
#define PROFILER_STOP(scope)  do { if(g_profiler != NULL && g_profiler.IsActive()) g_profiler.Stop(scope);  } while(false)
#define PROFILER_PRINT()      do { if(g_profiler != NULL && g_profiler.IsActive()) g_profiler.PrintResults(); } while(false)

#endif // TRADESPINE_PROFILER_MQH
//+------------------------------------------------------------------+
