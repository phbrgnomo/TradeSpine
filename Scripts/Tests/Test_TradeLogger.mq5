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
//| Evidence CSVs are deleted at the start of each test, then left  |
//| on disk after success for manual inspection.                    |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-05 - TradeLogger integration tests"

#include "../../Include/Testing/Assert.mqh"
#include "../../Include/Core/OptContext.mqh"
#include "../../Include/Persistence/TradeLogger.mqh"
#include "Support/FakeLogSink.mqh"

//+------------------------------------------------------------------+
//| Build a representative TradeEvidenceRecord for testing.          |
//| Populates all intent and execution fields so field-separation    |
//| tests can verify which columns are written vs left empty.        |
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
   // --- Intent fields ---
   r.side            = TRADE_SIDE_BUY;
   r.intended_price  = 130000.0;
   r.sl_price        = 129900.0;
   r.tp_price        = 130200.0;
   r.lots_requested  = 1.0;
   // --- Execution fields (large ulong exercises %I64u path) ---
   r.retcode         = 10009;                // TRADE_RETCODE_DONE
   r.ticket          = 123456789012345;
   r.fill_price      = 130001.0;
   r.lots_submitted  = 1.0;
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
//| Resolve the actual on-disk path TradeLogger writes for a given   |
//| test prefix + date stamp. Mirrors TradeLogger::_EnsureFile,      |
//| which prepends "TradeSpine/" to the caller-supplied prefix —     |
//| test prefixes here must therefore be relative to that root      |
//| (e.g. "Test/TL_pairing"), not include it themselves.            |
//+------------------------------------------------------------------+
string TradeLoggerPath(string prefix, string date_stamp)
  {
   return("TradeSpine/" + prefix + "_" + date_stamp + ".csv");
  }

//+------------------------------------------------------------------+
//| Delete the test file before writing fresh evidence.             |
//+------------------------------------------------------------------+
void DeleteTestFile(string prefix, string date_stamp)
  {
   FileDelete(TradeLoggerPath(prefix, date_stamp));
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
   string prefix = "Test/TL_pairing";
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
   string content = ReadFileContent(TradeLoggerPath(prefix, stamp));
   ok &= a.TS_CHECK(StringFind(content, "INTENT")      >= 0, "CSV contains INTENT row");
   ok &= a.TS_CHECK(StringFind(content, "EXECUTION")   >= 0, "CSV contains EXECUTION row");
   ok &= a.TS_CHECK(StringFind(content, run_id)        >= 0, "CSV contains shared strategy_run_id");
   ok &= a.TS_CHECK(StringFind(content, intent_id)     >= 0, "CSV contains shared order_intent_id");
   ok &= a.TS_CHECK(StringFind(content, "RETCODE=10009") >= 0, "EXECUTION row contains broker outcome");

//--- Header row must be present (only once per file).
   ok &= a.TS_CHECK(StringFind(content, "record_type") >= 0, "CSV header is present");

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
   string prefix = "Test/TL_separation";
   string stamp  = TodayStamp();
   DeleteTestFile(prefix, stamp);

   ok &= a.TS_CHECK(logger.Init(prefix, &ctx, &sink), "Init succeeds");

   TradeEvidenceRecord r = MakeRecord(TRADE_RECORD_INTENT, "run-sep", "intent-sep");
   ok &= a.TS_CHECK(logger.WriteIntent(r), "WriteIntent returns true");

//--- Write a diagnostic message through the sink directly (NOT through TradeLogger).
   sink.Write(LOG_INFO, "SomeCategory", "This is a diagnostic message, not trade evidence");

   logger.Close();

   string csv = ReadFileContent(TradeLoggerPath(prefix, stamp));

//--- The diagnostic message must NOT be in the trade CSV.
   ok &= a.TS_CHECK(StringFind(csv, "diagnostic message") < 0,
                    "Diagnostic text not mixed into trade CSV");
//--- But the sink did capture it.
   ok &= a.TS_CHECK(sink.HasMessage("diagnostic message"),
                    "Sink captured the diagnostic message");

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
   string prefix = "Test/TL_optgate";
   string stamp  = TodayStamp();
   DeleteTestFile(prefix, stamp);

   ok &= a.TS_CHECK(logger.Init(prefix, &ctx, &sink), "Init succeeds in optimization mode");

   TradeEvidenceRecord r = MakeRecord(TRADE_RECORD_INTENT, "run-opt", "intent-opt");
   ok &= a.TS_CHECK(logger.WriteIntent(r),  "WriteIntent returns true (gated, no I/O)");
   TradeEvidenceRecord e = MakeRecord(TRADE_RECORD_EXECUTION, "run-opt", "intent-opt", "RETCODE=0");
   ok &= a.TS_CHECK(logger.WriteExecution(e), "WriteExecution returns true (gated, no I/O)");
   logger.Close();

//--- No file should have been created.
   ok &= a.TS_CHECK(!FileIsExist(TradeLoggerPath(prefix, stamp)),
                    "No CSV file created in optimization mode");
//--- No error diagnostic logged through the sink.
   ok &= a.TS_CHECK(sink.Count() == 0, "No diagnostic messages from gated writes");

   return(ok);
  }

//+------------------------------------------------------------------+
//| Write failure returns false and logs a LogFailure diagnostic.    |
//| Forced deterministically: a folder is created at the exact path  |
//| TradeLogger would open as a file, so FileOpen() must fail (a     |
//| directory cannot be opened for file I/O). This avoids relying on |
//| sandbox path-rejection behavior, which MQL5's FileOpen() does not|
//| guarantee (it can create missing intermediate subfolders).      |
//+------------------------------------------------------------------+
bool Test_TradeLogger_WriteFailure(CAssert &a)
  {
   bool ok = true;
   FolderCreate("TradeSpine/Test");

   RuntimeMode mode;
   mode.is_tester = false; mode.is_optimization = false; mode.diagnostics_enabled = true;
   COptContext ctx(mode);
   FakeLogSink sink;

   TradeLogger logger;
   string prefix = "Test/TL_fail";
   string stamp  = TodayStamp();
   string path   = TradeLoggerPath(prefix, stamp);
   DeleteTestFile(prefix, stamp);

//--- Occupy the target file path with a directory so FileOpen() fails.
   FolderCreate(path);

   ok &= a.TS_CHECK(logger.Init(prefix, &ctx, &sink), "Init succeeds (failure occurs on write, not init)");

   TradeEvidenceRecord r = MakeRecord(TRADE_RECORD_INTENT, "run-fail", "intent-fail");
   bool result = logger.WriteIntent(r);

   ok &= a.TS_CHECK(!result, "WriteIntent returns false on I/O failure");
   ok &= a.TS_CHECK(sink.HasMessage("Intent write failed"),
                    "LogFailure diagnostic captured in sink");

   logger.Close();
   FolderDelete(path);
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
   string prefix = "Test/TL_count";
   string stamp  = TodayStamp();
   DeleteTestFile(prefix, stamp);

   logger.Init(prefix, &ctx, &sink);

   TradeEvidenceRecord intent = MakeRecord(TRADE_RECORD_INTENT,    "run-cnt", "int-cnt");
   TradeEvidenceRecord exec   = MakeRecord(TRADE_RECORD_EXECUTION,  "run-cnt", "int-cnt", "OK");
   logger.WriteIntent(intent);
   logger.WriteExecution(exec);
   logger.Close();

   string content = ReadFileContent(TradeLoggerPath(prefix, stamp));
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

   return(ok);
  }

//+------------------------------------------------------------------+
//| CHG-14 regression: all three data-integrity failure modes in one |
//| focused test so they can never silently regress.                 |
//| (a) magic > LONG_MAX — signed cast would produce a negative CSV  |
//| (b) broker_outcome with comma and embedded double-quote — needs  |
//|     RFC 4180 quoting or the column structure is corrupted        |
//| (c) WriteIntent called with TRADE_RECORD_EXECUTION — public API  |
//|     must override to INTENT regardless of caller-supplied type   |
//+------------------------------------------------------------------+
bool Test_TradeLogger_CSVEncoding(CAssert &a)
  {
   bool ok = true;
   FolderCreate("TradeSpine/Test");

   RuntimeMode mode;
   mode.is_tester = false; mode.is_optimization = false; mode.diagnostics_enabled = true;
   COptContext ctx(mode);
   FakeLogSink sink;

   TradeLogger logger;
   string prefix = "Test/TL_chg14";
   string stamp  = TodayStamp();
   DeleteTestFile(prefix, stamp);

   ok &= a.TS_CHECK(logger.Init(prefix, &ctx, &sink), "Init succeeds");

//--- (c) pass TRADE_RECORD_EXECUTION to WriteIntent deliberately.
   TradeEvidenceRecord r = MakeRecord(TRADE_RECORD_EXECUTION, "run-chg14", "int-chg14",
                                      "reject, reason=\"bad fill\"");
//--- (a) 0x8000000000000000 = 2^63 = 9223372036854775808; signed cast gives -9223372036854775808.
   r.magic = 0x8000000000000000;
   r.side  = TRADE_SIDE_SELL;

   ok &= a.TS_CHECK(logger.WriteIntent(r), "WriteIntent returns true despite EXECUTION record_type");
   logger.Close();

   string csv = ReadFileContent(TradeLoggerPath(prefix, stamp));

//--- (c) WriteIntent MUST override to INTENT regardless of caller input.
   ok &= a.TS_CHECK(StringFind(csv, "INTENT")    >= 0, "(c) record_type forced to INTENT by WriteIntent");
   ok &= a.TS_CHECK(StringFind(csv, "EXECUTION") <  0, "(c) EXECUTION not present in WriteIntent output");

//--- (a) %I64u must produce the unsigned decimal, not a negative signed value.
   ok &= a.TS_CHECK(StringFind(csv, "9223372036854775808")  >= 0,
                    "(a) magic > LONG_MAX formatted as unsigned");
   ok &= a.TS_CHECK(StringFind(csv, "-9223372036854775808") <  0,
                    "(a) signed corruption of magic absent");

//--- (b) RFC 4180: comma in broker_outcome forces double-quote wrap;
//---     embedded double-quote is escaped by doubling ("" inside "...").
   ok &= a.TS_CHECK(StringFind(csv, "\"reject,") >= 0,
                    "(b) broker_outcome with comma is RFC 4180 wrapped");
   ok &= a.TS_CHECK(StringFind(csv, "reason=\"\"bad fill\"\"") >= 0,
                    "(b) embedded double-quote escaped as \"\" in CSV");

   return(ok);
  }

//+------------------------------------------------------------------+
//| CHG-15: INTENT row contains intent columns; execution cols empty. |
//+------------------------------------------------------------------+
bool Test_TradeLogger_IntentFieldSeparation(CAssert &a)
  {
   bool ok = true;
   FolderCreate("TradeSpine/Test");

   RuntimeMode mode;
   mode.is_tester = false; mode.is_optimization = false; mode.diagnostics_enabled = true;
   COptContext ctx(mode);
   FakeLogSink sink;

   TradeLogger logger;
   string prefix = "Test/TL_intent_sep";
   string stamp  = TodayStamp();
   DeleteTestFile(prefix, stamp);

   ok &= a.TS_CHECK(logger.Init(prefix, &ctx, &sink), "Init succeeds");

   TradeEvidenceRecord r = MakeRecord(TRADE_RECORD_INTENT, "run-isep", "int-isep");
   ok &= a.TS_CHECK(logger.WriteIntent(r), "WriteIntent returns true");
   logger.Close();

   string csv = ReadFileContent(TradeLoggerPath(prefix, stamp));

//--- Intent columns must be present.
   ok &= a.TS_CHECK(StringFind(csv, "130000.00000") >= 0, "intended_price written on INTENT row");
   ok &= a.TS_CHECK(StringFind(csv, "129900.00000") >= 0, "sl_price written on INTENT row");
   ok &= a.TS_CHECK(StringFind(csv, "130200.00000") >= 0, "tp_price written on INTENT row");
   ok &= a.TS_CHECK(StringFind(csv, "1.00")         >= 0, "lots_requested written on INTENT row");
   ok &= a.TS_CHECK(StringFind(csv, "\"BUY\"")      >= 0, "side written on INTENT row");

//--- Execution columns must be absent (empty cells between consecutive commas).
//--- The row has ",," where retcode, ticket, fill_price, lots_submitted would be.
   ok &= a.TS_CHECK(StringFind(csv, "10009") < 0, "retcode absent from INTENT row");
   ok &= a.TS_CHECK(StringFind(csv, "123456789012345") < 0, "ticket absent from INTENT row");

   return(ok);
  }

//+------------------------------------------------------------------+
//| CHG-15: EXECUTION row contains execution cols; intent cols empty. |
//+------------------------------------------------------------------+
bool Test_TradeLogger_ExecutionFieldSeparation(CAssert &a)
  {
   bool ok = true;
   FolderCreate("TradeSpine/Test");

   RuntimeMode mode;
   mode.is_tester = false; mode.is_optimization = false; mode.diagnostics_enabled = true;
   COptContext ctx(mode);
   FakeLogSink sink;

   TradeLogger logger;
   string prefix = "Test/TL_exec_sep";
   string stamp  = TodayStamp();
   DeleteTestFile(prefix, stamp);

   ok &= a.TS_CHECK(logger.Init(prefix, &ctx, &sink), "Init succeeds");

   TradeEvidenceRecord r = MakeRecord(TRADE_RECORD_EXECUTION, "run-esep", "int-esep",
                                      "fill_ok");
   ok &= a.TS_CHECK(logger.WriteExecution(r), "WriteExecution returns true");
   logger.Close();

   string csv = ReadFileContent(TradeLoggerPath(prefix, stamp));

//--- Execution columns must be present.
   ok &= a.TS_CHECK(StringFind(csv, "10009")           >= 0, "retcode written on EXECUTION row");
   ok &= a.TS_CHECK(StringFind(csv, "123456789012345") >= 0, "ticket written as ulong on EXECUTION row");
   ok &= a.TS_CHECK(StringFind(csv, "130001.00000")    >= 0, "fill_price written on EXECUTION row");
   ok &= a.TS_CHECK(StringFind(csv, "\"BUY\"")         >= 0, "side written on EXECUTION row");

//--- Intent-only price columns must be absent.
   ok &= a.TS_CHECK(StringFind(csv, "129900.00000") < 0, "sl_price absent from EXECUTION row");
   ok &= a.TS_CHECK(StringFind(csv, "130200.00000") < 0, "tp_price absent from EXECUTION row");

   return(ok);
  }

//+------------------------------------------------------------------+
//| Out-of-domain ENUM_TRADE_SIDE must be rejected; no row written.  |
//| Regression for H1 finding: invalid side values were silently     |
//| coerced to BUY, misrepresenting trade direction in evidence CSV. |
//+------------------------------------------------------------------+
bool Test_TradeLogger_InvalidSide(CAssert &a)
  {
   bool ok = true;
   FolderCreate("TradeSpine/Test");

   RuntimeMode mode;
   mode.is_tester = false; mode.is_optimization = false; mode.diagnostics_enabled = true;
   COptContext ctx(mode);
   FakeLogSink sink;

   TradeLogger logger;
   string prefix = "Test/TL_invalid_side";
   string stamp  = TodayStamp();
   DeleteTestFile(prefix, stamp);

   ok &= a.TS_CHECK(logger.Init(prefix, &ctx, &sink), "Init succeeds");

   TradeEvidenceRecord r = MakeRecord(TRADE_RECORD_INTENT, "run-side", "int-side");
   r.side = (ENUM_TRADE_SIDE)-1; // cast a value outside the defined enum domain

   bool result = logger.WriteIntent(r);
   ok &= a.TS_CHECK(!result, "WriteIntent returns false for out-of-domain side value");
   ok &= a.TS_CHECK(sink.HasMessage("invalid trade side"),
                    "Diagnostic emitted for invalid side rejection");

   logger.Close();

//--- File may exist (header written by _EnsureFile before the side check), but must have no data rows.
   string csv = ReadFileContent(TradeLoggerPath(prefix, stamp));
   ok &= a.TS_CHECK(StringFind(csv, "INTENT")    < 0, "No INTENT row written for out-of-domain side");
   ok &= a.TS_CHECK(StringFind(csv, "EXECUTION") < 0, "No EXECUTION row written for out-of-domain side");

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
   ok &= Test_TradeLogger_IntentFieldSeparation(a);
   ok &= Test_TradeLogger_ExecutionFieldSeparation(a);
   ok &= Test_TradeLogger_CSVEncoding(a);
   ok &= Test_TradeLogger_InvalidSide(a);
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
   Test_TradeLogger_IntentFieldSeparation(asserts);
   Test_TradeLogger_ExecutionFieldSeparation(asserts);
   Test_TradeLogger_CSVEncoding(asserts);
   Test_TradeLogger_InvalidSide(asserts);
   bool pass = asserts.TS_REPORT_SUMMARY("Test_TradeLogger");
   if(!pass)
      return(1);
   if(asserts.TestsSkipped() > 0)
      return(2);
   return(0);
  }
#endif
//+------------------------------------------------------------------+
