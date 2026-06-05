//+------------------------------------------------------------------+
//|                                                      Profiler.mqh |
//|              Copyright 2026, Paulo Henrique Barreto Reboucas      |
//|                                                                  |
//| @code: Include/Core/Profiler.mqh                                 |
//| @spec: SPEC-09  @tdd: TDD.09.04.8050  @iplan: IPLAN-09           |
//|                                                                  |
//| Low-overhead timing and memory-budget evidence helper gated by   |
//| an injected OptContext. When the runtime policy disables          |
//| profiling (BDD.01.03.b37d), Start/Stop return without any I/O or  |
//| persistent writes. Memory evidence uses a baseline-and-delta      |
//| harness (EARS.01.03.8044). No broker execution APIs.             |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_PROFILER_MQH
#define TRADESPINE_PROFILER_MQH

#include "Interfaces.mqh"
#include "OptContext.mqh"

#define PROFILER_MAX_SCOPES 64

//+------------------------------------------------------------------+
//| Profiler                                                         |
//+------------------------------------------------------------------+
class Profiler
  {
private:
   OptContext       *m_ctx;       // runtime-mode policy (not owned)
   ILogSink         *m_sink;      // optional diagnostics sink (not owned)
   bool              m_enabled;   // master switch (still subject to policy)

   string            m_scope[PROFILER_MAX_SCOPES];
   ulong             m_start_us[PROFILER_MAX_SCOPES];
   long              m_elapsed_us[PROFILER_MAX_SCOPES];
   bool              m_sample_on[PROFILER_MAX_SCOPES];
   int               m_count;

   //--- Active when both the master switch and the runtime policy agree.
   bool              Active(void) const
     {
      if(!m_enabled)
         return(false);
      if(m_ctx == NULL)
         return(false);
      return(m_ctx.AllowsProfiler());
     }

   int               FindScope(const string scope) const
     {
      for(int i = 0; i < m_count; i++)
         if(m_scope[i] == scope)
            return(i);
      return(-1);
     }

   int               EnsureScope(const string scope)
     {
      int idx = FindScope(scope);
      if(idx >= 0)
         return(idx);
      if(m_count >= PROFILER_MAX_SCOPES)
         return(-1);
      idx               = m_count++;
      m_scope[idx]      = scope;
      m_start_us[idx]   = 0;
      m_elapsed_us[idx] = 0;
      m_sample_on[idx]  = false;
      return(idx);
     }

public:
                     Profiler(OptContext *ctx, ILogSink *sink = NULL)
     {
      m_ctx     = ctx;
      m_sink    = sink;
      m_enabled = true;
      m_count   = 0;
     }

   void              SetEnabled(const bool v) { m_enabled = v; }
   bool              IsActive(void) const     { return(Active()); }

   //--- Begin a measurement block. No-op when inactive.
   void              Start(const string scope)
     {
      if(!Active())
         return;
      int idx = EnsureScope(scope);
      if(idx < 0)
         return;
      m_start_us[idx] = GetMicrosecondCount();
     }

   //--- End a measurement block; record the sample. No-op when inactive.
   void              Stop(const string scope)
     {
      if(!Active())
         return;
      int idx = FindScope(scope);
      if(idx < 0 || m_start_us[idx] == 0)
         return;
      m_elapsed_us[idx] = (long)(GetMicrosecondCount() - m_start_us[idx]);
      m_sample_on[idx]  = true;
     }

   //--- Retrieve a recorded sample. When inactive or unknown, the
   //--- returned sample carries enabled=false and elapsed_us=0.
   ProfileSample     GetSample(const string scope) const
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

   //--- Human-readable dump of recorded samples.
   string            GetResults(void) const
     {
      string out = "";
      for(int i = 0; i < m_count; i++)
         if(m_sample_on[i])
            out += StringFormat("%s=%I64dus ", m_scope[i], m_elapsed_us[i]);
      return(out);
     }

   //--- Print results. No persistent write when inactive.
   void              PrintResults(void)
     {
      if(!Active())
         return;
      string r = GetResults();
      if(m_sink != NULL)
         m_sink.Write(LOG_INFO, "profiler", r);
      else
         Print("profiler: ", r);
     }

   //--- Memory evidence (baseline-and-delta harness, in MB).
   long              CaptureBaselineMemory(const string scenario)
     {
      return((long)TerminalInfoInteger(TERMINAL_MEMORY_USED));
     }

   long              RecordMemoryDelta(const long baseline, const string scenario)
     {
      long now = (long)TerminalInfoInteger(TERMINAL_MEMORY_USED);
      return(now - baseline);
     }

   BenchmarkBaseline GetBenchmarkData(const string scenario, const long baseline)
     {
      BenchmarkBaseline b;
      b.scenario               = scenario;
      b.baseline_memory        = baseline;
      b.component_memory_delta = RecordMemoryDelta(baseline, scenario);
      b.timing_source          = "GetMicrosecondCount";
      return(b);
     }
  };

//+------------------------------------------------------------------+
//| Optional macro front-end over a shared instance. All calls are   |
//| guarded so a disabled hot path does zero work.                   |
//+------------------------------------------------------------------+
Profiler *g_profiler = NULL;

#define PROFILER_START(scope) do { if(g_profiler != NULL) g_profiler.Start(scope); } while(false)
#define PROFILER_STOP(scope)  do { if(g_profiler != NULL) g_profiler.Stop(scope);  } while(false)
#define PROFILER_PRINT()      do { if(g_profiler != NULL) g_profiler.PrintResults(); } while(false)

#endif // TRADESPINE_PROFILER_MQH
//+------------------------------------------------------------------+
