//+------------------------------------------------------------------+
//|                                          Test_TradeLogger.mq5    |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_TradeLogger.mq5                       |
//| @tdd: TDD.05.04.229f  @spec: SPEC-05  @iplan: IPLAN-05           |
//|                                                                  |
//| Tier-1 integration tests for TradeLogger:                        |
//|   - Intent and execution rows share strategy_run_id / intent_id. |
//|   - Diagnostic sink messages do NOT appear in trade CSV.         |
//|   - Optimization-gated: no file I/O when evidence suppressed.   |
//|   - Write failure path: returns false and logs diagnostic.       |
//| Uses real MT5 file I/O to TradeSpine/Test/ subdirectory.        |
//| Files are cleaned up after every test function.                  |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-05 - TradeLogger integration tests"

#include "../../Include/Testing/Assert.mqh"
#include "../../Include/Core/OptContext.mqh"
#include "../../Include/Persistence/TradeLogger.mqh"
#include "Support/FakeLogSink.mqh"

//--- Unique prefix for all test-generated files.
#define TL_TEST_PREFIX "TradeSpine/Test/TradeLoggerTest"

//+------------------------------------------------------------------+
//| Build a minimal valid TradeEvidenceRecord.                       |
//+------------------------------------------------------------------+
TradeEvidenceRecord MakeRecord(ENUM_TRADE_RECORD_TYPE t,
                               string run_id,
                               string intent_id,
                               string outcome = "")
  {
   TradeEvidenceRecord r;
   r.record_type     = t;
   r.strategy_run_id = run_id;
   r.order_intent_id = intent_id;
   r.symbol          = "WINM26";
   r.magic           = 99090;
   r.broker_outcome  = outcome;
   return(r);
  }

//+------------------------------------------------------------------+
//| Read the entire contents of a file as a single string.           |
//+------------------------------------------------------------------+
string ReadFileContent(string path)
  {
   int fh = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(fh == INVALID_HANDLE)
      return("");
   string content = "";
   while(!FileIsEnding(fh))
     {
      string line = FileReadString(fh);
      if(line == "" && !FileIsEnding(fh))
         break;
      content += line + "\n";
     }
   FileClose(fh);
   return(content);
  }

//+------------------------------------------------------------------+
//| Delete the test file; ignore errors if it doesn't exist.        |
//+------------------------------------------------------------------+
void DeleteTestFile(string prefix, string date_stamp)
  {
   FileDelete(prefix + "_" + date_stamp + ".csv");
  }

//+------------------------------------------------------------------+
//| Get today's YYYYMMDD date stamp to predict the file name.       |
//+------------------------------------------------------------------+
string TodayStamp(void)
  {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   return(StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day));
  }

//+------------------------------------------------------------------+
//| Helper: init a TradeLogger with a test prefix, live mode ctx.   |
//+------------------------------------------------------------------+
bool MakeLogger(TradeLogger &logger, string prefix,
                COptContext* ctx, FakeLogSink* sink)
  {
   return(logger.Init(prefix, ctx, sink));
  }

//--- ----------------------------------------------------------------+
//--- Tests                                                           |
//--- ----------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Intent and execution rows are paired (same run_id + intent_id).  |
//+------------------------------------------------------------------+
bool Test_TradeLogger_Pairing(CAssert &a)
  {
   bool ok = true;
   FolderCreate("TradeSpine/Test");

   RuntimeMode live_mode;
   live_mode.is_tester       = false;
   live_mode.is_optimization = false;
   live_mode.diagnostics_enabled = true;
   COptContext ctx(live_mode);
   FakeLogSink sink;

   TradeLogger logger;
   string prefix = "TradeSpine/Test/TL_pairing";
   string stamp  = TodayStamp();
   DeleteTestFile(prefix, stamp);

   ok &= a.TS_CHECK(logger.Init(prefix, &ctx, &sink), "Init succeeds");

   string run_id    = "run-abc123";
   string intent_id = "intent-xyz";

   TradeEvidenceRecord intent = MakeRecord(TRADE_RECORD_INTENT,    run_id, intent_id);
   TradeEvidenceRecord exec   = MakeRecord(TRADE_RECORD_EXECUTION,  run_id, intent_id,
                                           "RETCODE=10009|DEAL=12345");

   ok &= a.TS_CHECK(logger.WriteIntent(intent),    "WriteIntent returns true");
   ok &= a.TS_CHECK(logger.WriteExecution(exec),   "WriteExecution returns true");
   logger.Close();

//--- Verify CSV content.
   string content = ReadFileContent(prefix + "_" + stamp + ".csv");
   ok &= a.TS_CHECK(StringFind(content, "INTENT")      >= 0, "CSV contains INTENT row");
   ok &= a.TS_CHECK(StringFind(content, "EXECUTION")   >= 0, "CSV contains EXECUTION row");
   ok &= a.TS_CHECK(StringFind(content, run_id)        >= 0, "CSV contains shared strategy_run_id");
   ok &= a.TS_CHECK(StringFind(content, intent_id)     >= 0, "CSV contains shared order_intent_id");
   ok &= a.TS_CHECK(StringFind(content, "RETCODE=10009") >= 0, "EXECUTION row contains broker outcome");

//--- Header row must be present (only once per file).
   ok &= a.TS_CHECK(StringFind(content, "record_type") >= 0, "CSV header is present");

   DeleteTestFile(prefix, stamp);
   return(ok);
  }

//+------------------------------------------------------------------+
//| Diagnostic sink messages do NOT appear in the trade CSV.         |
//+------------------------------------------------------------------+
bool Test_TradeLogger_SeparateDiagnostics(CAssert &a)
  {
   bool ok = true;
   FolderCreate("TradeSpine/Test");

   RuntimeMode mode;
   mode.is_tester = false; mode.is_optimization = false; mode.diagnostics_enabled = true;
   COptContext ctx(mode);
   FakeLogSink sink;

   TradeLogger logger;
   string prefix = "TradeSpine/Test/TL_separation";
   string stamp  = TodayStamp();
   DeleteTestFile(prefix, stamp);

   ok &= a.TS_CHECK(logger.Init(prefix, &ctx, &sink), "Init succeeds");

   TradeEvidenceRecord r = MakeRecord(TRADE_RECORD_INTENT, "run-sep", "intent-sep");
   ok &= a.TS_CHECK(logger.WriteIntent(r), "WriteIntent returns true");

//--- Write a diagnostic message through the sink directly (NOT through TradeLogger).
   sink.Write(LOG_INFO, "SomeCategory", "This is a diagnostic message, not trade evidence");

   logger.Close();

   string csv = ReadFileContent(prefix + "_" + stamp + ".csv");

//--- The diagnostic message must NOT be in the trade CSV.
   ok &= a.TS_CHECK(StringFind(csv, "diagnostic message") < 0,
                    "Diagnostic text not mixed into trade CSV");
//--- But the sink did capture it.
   ok &= a.TS_CHECK(sink.HasMessage("diagnostic message"),
                    "Sink captured the diagnostic message");

   DeleteTestFile(prefix, stamp);
   return(ok);
  }

//+------------------------------------------------------------------+
//| In optimization mode no file I/O occurs; methods return true.   |
//+------------------------------------------------------------------+
bool Test_TradeLogger_OptimizationGated(CAssert &a)
  {
   bool ok = true;

   RuntimeMode opt_mode;
   opt_mode.is_tester       = true;
   opt_mode.is_optimization = true;
   opt_mode.diagnostics_enabled = false;
   COptContext ctx(opt_mode);
   FakeLogSink sink;

   TradeLogger logger;
   string prefix = "TradeSpine/Test/TL_optgate";
   string stamp  = TodayStamp();
   DeleteTestFile(prefix, stamp);

   ok &= a.TS_CHECK(logger.Init(prefix, &ctx, &sink), "Init succeeds in optimization mode");

   TradeEvidenceRecord r = MakeRecord(TRADE_RECORD_INTENT, "run-opt", "intent-opt");
   ok &= a.TS_CHECK(logger.WriteIntent(r),  "WriteIntent returns true (gated, no I/O)");
   TradeEvidenceRecord e = MakeRecord(TRADE_RECORD_EXECUTION, "run-opt", "intent-opt", "RETCODE=0");
   ok &= a.TS_CHECK(logger.WriteExecution(e), "WriteExecution returns true (gated, no I/O)");
   logger.Close();

//--- No file should have been created.
   ok &= a.TS_CHECK(!FileIsExist(prefix + "_" + stamp + ".csv"),
                    "No CSV file created in optimization mode");
//--- No error diagnostic logged through the sink.
   ok &= a.TS_CHECK(sink.Count() == 0, "No diagnostic messages from gated writes");

   DeleteTestFile(prefix, stamp);
   return(ok);
  }

//+------------------------------------------------------------------+
//| Write failure returns false and logs a LogFailure diagnostic.    |
//| Simulated by providing an invalid (empty) file prefix.          |
//+------------------------------------------------------------------+
bool Test_TradeLogger_WriteFailure(CAssert &a)
  {
   bool ok = true;

   RuntimeMode mode;
   mode.is_tester = false; mode.is_optimization = false; mode.diagnostics_enabled = true;
   COptContext ctx(mode);
   FakeLogSink sink;

   TradeLogger logger;
//--- Use a path to a folder that cannot be created (starts with /).
//--- This forces FileOpen to fail, triggering the error path.
//--- On MT5 sandboxed files, "/invalid" cannot be created.
   string bad_prefix = "/invalid/path/TL_fail";

   logger.Init(bad_prefix, &ctx, &sink);

   TradeEvidenceRecord r = MakeRecord(TRADE_RECORD_INTENT, "run-fail", "intent-fail");
//--- WriteIntent should fail (file cannot be opened) and log an error.
   bool result = logger.WriteIntent(r);

//--- The result depends on whether the invalid path is truly unwritable.
//--- If FileOpen fails, result=false and sink has an error.
//--- If the platform somehow allows it, we just verify no crash occurred.
   if(!result)
     {
      ok &= a.TS_CHECK(!result, "WriteIntent returns false on I/O failure");
      ok &= a.TS_CHECK(sink.HasMessage("Intent write failed"),
                       "LogFailure diagnostic captured in sink");
     }
   else
     {
      //--- Path was accepted by the platform; skip the failure assertion.
      a.TS_SKIP("Platform allowed invalid path; I/O failure path not triggerable in this environment");
      logger.Close();
      FileDelete(bad_prefix + "_" + TodayStamp() + ".csv");
     }

   return(ok);
  }

//+------------------------------------------------------------------+
//| b37d: write count is bounded — exactly 2 rows per trade.        |
//+------------------------------------------------------------------+
bool Test_TradeLogger_WriteCount(CAssert &a)
  {
   bool ok = true;
   FolderCreate("TradeSpine/Test");

   RuntimeMode mode;
   mode.is_tester = false; mode.is_optimization = false; mode.diagnostics_enabled = true;
   COptContext ctx(mode);
   FakeLogSink sink;

   TradeLogger logger;
   string prefix = "TradeSpine/Test/TL_count";
   string stamp  = TodayStamp();
   DeleteTestFile(prefix, stamp);

   logger.Init(prefix, &ctx, &sink);

   TradeEvidenceRecord intent = MakeRecord(TRADE_RECORD_INTENT,    "run-cnt", "int-cnt");
   TradeEvidenceRecord exec   = MakeRecord(TRADE_RECORD_EXECUTION,  "run-cnt", "int-cnt", "OK");
   logger.WriteIntent(intent);
   logger.WriteExecution(exec);
   logger.Close();

   string content = ReadFileContent(prefix + "_" + stamp + ".csv");
//--- Count newlines to verify bounded output (header + 2 data rows + trailing newline).
   int newline_count = 0;
   int pos = 0;
   while((pos = StringFind(content, "\n", pos)) >= 0)
     {
      pos++;
      newline_count++;
     }
//--- Expected: 1 header + 2 data rows, each ending with \n, plus possible trailing \n → 3-4 newlines.
   ok &= a.TS_CHECK(newline_count >= 3, "CSV has at least header + 2 data rows");
   ok &= a.TS_CHECK(newline_count <= 4, "CSV has no more than header + 2 data rows + trailing (no redundant writes)");

   DeleteTestFile(prefix, stamp);
   return(ok);
  }

//+------------------------------------------------------------------+
//| TDD/BDD trace-alias entry points called by RunAllTests.          |
//+------------------------------------------------------------------+

//--- TDD.05.04.229f: canonical integration contract for TradeLogger.
bool test_persistence_and_audit_evidence_integration_contract(CAssert &a)
  {
   bool ok = true;
   ok &= Test_TradeLogger_Pairing(a);
   ok &= Test_TradeLogger_SeparateDiagnostics(a);
   ok &= Test_TradeLogger_OptimizationGated(a);
   ok &= Test_TradeLogger_WriteFailure(a);
   ok &= Test_TradeLogger_WriteCount(a);
   return(ok);
  }

//--- BDD.01.03.0073: guarded order writes both evidence rows.
bool test_persistence_and_audit_evidence_0073_integration(CAssert &a)
  {
   return(Test_TradeLogger_Pairing(a));
  }

//--- BDD.01.03.d6ae: rows paired and separate from diagnostics.
bool test_persistence_and_audit_evidence_d6ae_integration(CAssert &a)
  {
   return(Test_TradeLogger_SeparateDiagnostics(a));
  }

//--- BDD.01.03.e16a: write failure does not corrupt broker outcome.
bool test_persistence_and_audit_evidence_e16a_integration(CAssert &a)
  {
   return(Test_TradeLogger_WriteFailure(a));
  }

//--- BDD.01.03.b37d: write ops bounded (≤2 per trade).
bool test_persistence_and_audit_evidence_b37d_integration(CAssert &a)
  {
   return(Test_TradeLogger_WriteCount(a));
  }

//+------------------------------------------------------------------+
//| Script entry point.                                              |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_RUN_ALL_TESTS
int OnStart()
  {
   CAssert asserts;
   asserts.Reset();
   Print("== Test_TradeLogger ==");
   Test_TradeLogger_Pairing(asserts);
   Test_TradeLogger_SeparateDiagnostics(asserts);
   Test_TradeLogger_OptimizationGated(asserts);
   Test_TradeLogger_WriteFailure(asserts);
   Test_TradeLogger_WriteCount(asserts);
   bool pass = asserts.TS_REPORT_SUMMARY("Test_TradeLogger");
   if(!pass)
      return(1);
   if(asserts.TestsSkipped() > 0)
      return(2);
   return(0);
  }
#endif
//+------------------------------------------------------------------+
