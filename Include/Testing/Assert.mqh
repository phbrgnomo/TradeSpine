//+------------------------------------------------------------------+
//|                                                      Assert.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| SPEC-11 CAssert helper, evidence types, and pass/fail counters   |
//| for TradeSpine Tier-1 test scripts.                              |
//| @spec: SPEC-11  @iplan: IPLAN-11                                 |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_TESTING_ASSERT_MQH
#define TRADESPINE_TESTING_ASSERT_MQH

#define TRADESPINE_ASSERT_FAILURE_RESERVE 32

//+------------------------------------------------------------------+
//| \brief Evidence kind classification (SPEC-11 data model).        |
//+------------------------------------------------------------------+
enum ENUM_EVIDENCE_KIND
  {
   EVIDENCE_INTENT     = 0,
   EVIDENCE_EXECUTION  = 1,
   EVIDENCE_DIAGNOSTIC = 2,
   EVIDENCE_STATE      = 3,
   EVIDENCE_RELEASE    = 4
  };

//+------------------------------------------------------------------+
//| \brief One evidence assertion entry for                          |
//|        ScenarioHarness.AssertEvidence.                          |
//+------------------------------------------------------------------+
struct EvidenceAssertion
  {
   ENUM_EVIDENCE_KIND expected_kind;   // intent, execution, diagnostic, state, or release
   string             expected_trace;  // spec/req tag substring expected in captured log output
   bool               required;        // false -> optional; absence is Skip, not FAIL
  };

//+------------------------------------------------------------------+
//| \brief Manual deferred account-mode evidence pack.               |
//|        Empty artifacts field signals the pack is missing         |
//|        (blocks release gate). Not replaced by automated evidence.|
//+------------------------------------------------------------------+
struct DeferredAccountModeEvidencePack
  {
   string account_mode;  // e.g. "hedging", "netting"
   string scenario;      // deferred-mode validation scenario name
   string artifacts;     // file paths or operator notes; empty = missing
  };

//+------------------------------------------------------------------+
//| \brief Lightweight state checkpoint for controlled-failure tests.|
//+------------------------------------------------------------------+
struct AssertSnapshot
  {
   int tests_run;
   int tests_passed;
   int tests_skipped;
   int failure_count;
  };

//+------------------------------------------------------------------+
//| \brief CAssert - assertion helper for Tier-1 test scripts:       |
//|        source-located checks, pass/fail/skip counters, failure   |
//|        log, snapshots, and expect-failure (xfail) scopes. Use    |
//|        via the TS_* macros at the foot of this file.             |
//+------------------------------------------------------------------+
class CAssert
  {
  private:
    int    m_tests_run;
    int    m_tests_passed;
    int    m_tests_skipped;
    int    m_dropped_failures;
    string m_fail_msgs[];
    bool   m_verbose;        // when false, suppress PASS/FAIL/SKIP console lines (isolated probes)
    bool   m_xfail_active;   // inside a negative-assertion (expect-failure) scope
    bool   m_xfail_seen;     // at least one check failed inside the current scope
    string m_xfail_label;    // label reported once by EndExpectFailure()

    // Builds the "file:line" suffix appended to every failure message.
    string FormatLocation(const string file, const int line) const
      {
        return(StringFormat("%s:%d", file, line));
      }

    // Grows m_fail_msgs by one entry; pre-reserves TRADESPINE_ASSERT_FAILURE_RESERVE to minimise reallocs.
    // On allocation failure, increments m_dropped_failures so missing messages are visible in the summary.
    bool AppendFailure(const string failure)
      {
        int n = ArraySize(m_fail_msgs);
        int resized = ArrayResize(m_fail_msgs, n + 1, TRADESPINE_ASSERT_FAILURE_RESERVE);
        if(resized != n + 1)
          {
          m_dropped_failures++;
          PrintFormat("    unable to record failure message: ArrayResize returned %d", resized);
          return(false);
          }
        m_fail_msgs[n] = failure;
        return(true);
      }

  public:
    //+------------------------------------------------------------------+
    //| \brief Construct a clean assertion recorder with verbose output.  |
    //+------------------------------------------------------------------+
    CAssert(void) : m_tests_run(0), m_tests_passed(0), m_tests_skipped(0), m_dropped_failures(0),
                    m_verbose(true), m_xfail_active(false), m_xfail_seen(false) {}

    //+------------------------------------------------------------------+
    //| \brief Reset counters, xfail state, and recorded failure messages.|
    //|        Leaves verbose output configuration unchanged.             |
    //+------------------------------------------------------------------+
    void Reset(void)
      {
        m_tests_run        = 0;
        m_tests_passed     = 0;
        m_tests_skipped    = 0;
        m_dropped_failures = 0;
        m_xfail_active     = false;
        m_xfail_seen       = false;
        ArrayResize(m_fail_msgs, 0);
      }

    //+------------------------------------------------------------------+
    //| \brief Enable or disable PASS/FAIL/SKIP console output.           |
    //| \param v false silences output for isolated probe instances.      |
    //+------------------------------------------------------------------+
    void SetVerbose(const bool v) { m_verbose = v; }

    //+------------------------------------------------------------------+
    //| \brief Return the number of counted assertion checks.             |
    //| \return Number of checks counted as test runs.                    |
    //+------------------------------------------------------------------+
    int TestsRun(void) const { return(m_tests_run); }

    //+------------------------------------------------------------------+
    //| \brief Return the number of passed assertion checks.              |
    //| \return Number of checks counted as passed.                       |
    //+------------------------------------------------------------------+
    int TestsPassed(void) const { return(m_tests_passed); }

    //+------------------------------------------------------------------+
    //| \brief Return the number of recorded skips.                       |
    //| \return Number of skip records.                                   |
    //+------------------------------------------------------------------+
    int TestsSkipped(void) const { return(m_tests_skipped); }

    //+------------------------------------------------------------------+
    //| \brief Return the number of retained failure messages.            |
    //| \return Current retained failure-message count.                   |
    //+------------------------------------------------------------------+
    int FailureCount(void) const { return(ArraySize(m_fail_msgs)); }

    //+------------------------------------------------------------------+
    //| \brief Return a retained failure message by index.                |
    //| \param index Zero-based failure-message index.                    |
    //| \return Failure message, or "" when index is out of range.        |
    //+------------------------------------------------------------------+
    string FailureMessage(const int index) const
      {
        if(index < 0 || index >= ArraySize(m_fail_msgs))
          return("");
        return(m_fail_msgs[index]);
      }

    //+------------------------------------------------------------------+
    //| \brief Capture counters for later rollback with Restore().        |
    //| \return Snapshot of run, pass, skip, and failure-message counts.  |
    //+------------------------------------------------------------------+
    AssertSnapshot Snapshot(void) const
      {
        AssertSnapshot snapshot;
        snapshot.tests_run     = m_tests_run;
        snapshot.tests_passed  = m_tests_passed;
        snapshot.tests_skipped = m_tests_skipped;
        snapshot.failure_count = ArraySize(m_fail_msgs);
        return(snapshot);
      }

    //+------------------------------------------------------------------+
    //| \brief Restore counters and truncate failures to a snapshot.      |
    //| \param snapshot Snapshot previously returned by Snapshot().       |
    //+------------------------------------------------------------------+
    void Restore(const AssertSnapshot &snapshot)
      {
        m_tests_run     = snapshot.tests_run;
        m_tests_passed  = snapshot.tests_passed;
        m_tests_skipped = snapshot.tests_skipped;
        ArrayResize(m_fail_msgs, snapshot.failure_count, TRADESPINE_ASSERT_FAILURE_RESERVE);
      }

    //+------------------------------------------------------------------+
    //| \brief Record a skip without counting a run or failure.           |
    //| \param msg Human-readable skip reason.                            |
    //| \param file Source file captured by the TS_SKIP macro.            |
    //| \param line Source line captured by the TS_SKIP macro.            |
    //+------------------------------------------------------------------+
    void _Skip(const string msg, const string file, const int line)
      {
        m_tests_skipped++;
        if(m_verbose)
           PrintFormat("  SKIP: %s  (%s)", msg, FormatLocation(file, line));
      }

    //+------------------------------------------------------------------+
    //| \brief Open a scope where at least one assertion is expected to   |
    //|        fail without recording a real failure.                     |
    //| \param label Label printed when the expected-failure scope closes.|
    //| \param file Source file captured by the macro.                   |
    //| \param line Source line captured by the macro.                   |
    //+------------------------------------------------------------------+
    void _BeginExpectFailure(const string label, const string file, const int line)
      {
        if(m_xfail_active)            // defensive: an unterminated prior scope fails closed
           _EndExpectFailure(file, line);
        m_xfail_active = true;
        m_xfail_seen   = false;
        m_xfail_label  = label;
      }

    //+------------------------------------------------------------------+
    //| \brief Close an expected-failure scope and record its result.     |
    //| \param file Source file captured by the macro.                   |
    //| \param line Source line captured by the macro.                   |
    //| \return true for a satisfied expectation or stray no-op close.    |
    //+------------------------------------------------------------------+
    bool _EndExpectFailure(const string file, const int line)
      {
        if(!m_xfail_active)
          {
          PrintFormat("  NOTE: TS_EXPECT_FAIL_END() at %s called without a matching TS_EXPECT_FAIL_BEGIN(); ignored",
                      FormatLocation(file, line));
          return(true);
          }
        m_xfail_active = false;
        m_tests_run++;
        if(m_xfail_seen)
          {
          m_tests_passed++;
          if(m_verbose)
             PrintFormat("  PASS: %s (expected failure)", m_xfail_label);
          return(true);
          }
        string failure = StringFormat("%s — expected a failure but none occurred  (%s)",
                                      m_xfail_label, FormatLocation(file, line));
        if(!AppendFailure(failure))
           Print("    assertion failure message dropped (allocation failure)");
        if(m_verbose)
           PrintFormat("  FAIL: %s", failure);
        return(false);
      }

    //+------------------------------------------------------------------+
    //| \brief Core boolean assertion gate used by TS_CHECK.             |
    //| \param cond Assertion condition.                                 |
    //| \param msg Assertion message.                                    |
    //| \param file Source file captured by the macro.                   |
    //| \param line Source line captured by the macro.                   |
    //| \return cond, after updating assertion counters.                 |
    //+------------------------------------------------------------------+
    bool _Check(const bool cond, const string msg, const string file, const int line)
      {
        if(m_xfail_active)
          {
          if(!cond)
            {
            m_xfail_seen = true;
            if(m_verbose)
               PrintFormat("    (expected) %s  (%s)", msg, FormatLocation(file, line));
            }
          else if(m_verbose)
             PrintFormat("    (note) unexpected pass inside expect-failure: %s", msg);
          return(cond);
          }

        m_tests_run++;
        if(cond)
          {
          m_tests_passed++;
          if(m_verbose)
             PrintFormat("  PASS: %s", msg);
          return(true);
          }

        string failure = StringFormat("%s  (%s)", msg, FormatLocation(file, line));
        if(!AppendFailure(failure))
           Print("    assertion failure message dropped (allocation failure)");
        if(m_verbose)
           PrintFormat("  FAIL: %s", failure);
        return(false);
      }

    //+------------------------------------------------------------------+
    //| \brief Compare two doubles within a non-negative finite tolerance.|
    //| \param a Actual value.                                           |
    //| \param b Expected value.                                         |
    //| \param tol Maximum absolute difference.                          |
    //| \param msg Assertion message.                                    |
    //| \param file Source file captured by the macro.                   |
    //| \param line Source line captured by the macro.                   |
    //| \return true when values are finite and within tolerance.         |
    //+------------------------------------------------------------------+
    bool _CheckEqualD(const double a, const double b, const double tol, const string msg,
                      const string file, const int line)
      {
        if(!MathIsValidNumber(a) || !MathIsValidNumber(b))
          {
          PrintFormat("    non-finite operand: a=%.10g b=%.10g", a, b);
          return(_Check(false, msg, file, line));
          }
        if(!MathIsValidNumber(tol) || tol < 0.0)
          {
          PrintFormat("    invalid tolerance: tol=%.10g", tol);
          return(_Check(false, msg, file, line));
          }
        bool ok = (MathAbs(a - b) <= tol);
        if(!ok)
          PrintFormat("    expected %.10g, got %.10g (tol %.10g)", b, a, tol);
        return(_Check(ok, msg, file, line));
      }

    //+------------------------------------------------------------------+
    //| \brief Compare two long values for exact equality.               |
    //| \param a Actual value.                                           |
    //| \param b Expected value.                                         |
    //| \param msg Assertion message.                                    |
    //| \param file Source file captured by the macro.                   |
    //| \param line Source line captured by the macro.                   |
    //| \return true when values are equal.                              |
    //+------------------------------------------------------------------+
    bool _CheckEqualL(const long a, const long b, const string msg,
                      const string file, const int line)
      {
        bool ok = (a == b);
        if(!ok)
          PrintFormat("    expected %I64d, got %I64d", b, a);
        return(_Check(ok, msg, file, line));
      }

    //+------------------------------------------------------------------+
    //| \brief Compare two strings for exact equality.                   |
    //| \param a Actual value.                                           |
    //| \param b Expected value.                                         |
    //| \param msg Assertion message.                                    |
    //| \param file Source file captured by the macro.                   |
    //| \param line Source line captured by the macro.                   |
    //| \return true when strings are identical.                         |
    //+------------------------------------------------------------------+
    bool _CheckEqualStr(const string a, const string b, const string msg,
                        const string file, const int line)
      {
        bool ok = (a == b);
        if(!ok)
          PrintFormat("    expected '%s', got '%s'", b, a);
        return(_Check(ok, msg, file, line));
      }

    //+------------------------------------------------------------------+
    //| \brief Print pass/fail/skip summary and retained failures.       |
    //| \param suite Suite name printed in the summary line.             |
    //| \return true when no failures were counted or dropped.           |
    //+------------------------------------------------------------------+
    bool _ReportSummary(const string suite)
      {
        int failed_from_log    = ArraySize(m_fail_msgs);
        int failed_from_counts = m_tests_run - m_tests_passed;
        int failed    = failed_from_counts;  // counter-based; not subject to allocation failures
        bool all_pass = (failed == 0 && m_dropped_failures == 0);
        string skip_str = m_tests_skipped > 0
                          ? StringFormat(", %d skipped", m_tests_skipped) : "";
        if(all_pass)
          {
          PrintFormat("==== %s: %d of %d passed%s ====",
                      suite, m_tests_passed, m_tests_run, skip_str);
          }
        else
          {
          PrintFormat("==== %s: %d of %d passed%s  <<< %d FAILURE%s >>> ====",
                      suite, m_tests_passed, m_tests_run, skip_str,
                      failed, failed == 1 ? "" : "S");
          if(failed_from_log != failed_from_counts)
             PrintFormat("  NOTE: failure count mismatch (logged=%d, run-passed=%d); some failures may not have been recorded.",
                         failed_from_log, failed_from_counts);
          if(m_dropped_failures > 0)
             PrintFormat("  NOTE: %d failure message(s) dropped due to allocation failure.", m_dropped_failures);
          for(int i = 0; i < ArraySize(m_fail_msgs); i++)
              PrintFormat("  [FAILED] %s", m_fail_msgs[i]);
          }
        return(all_pass);
      }
    };

//+------------------------------------------------------------------+
//| \brief Public assertion macros — call these (not the underscore   |
//|        methods) so __FILE__/__LINE__ are captured automatically.  |
//+------------------------------------------------------------------+
#define TS_CHECK(cond, msg) _Check(cond, msg, __FILE__, __LINE__)
#define TS_CHECK_EQ_D(a, b, tol, msg) _CheckEqualD(a, b, tol, msg, __FILE__, __LINE__)
#define TS_CHECK_EQ_L(a, b, msg) _CheckEqualL(a, b, msg, __FILE__, __LINE__)
#define TS_CHECK_EQ_STR(a, b, msg) _CheckEqualStr(a, b, msg, __FILE__, __LINE__)
#define TS_SKIP(msg) _Skip(msg, __FILE__, __LINE__)
#define TS_EXPECT_FAIL_BEGIN(label) _BeginExpectFailure(label, __FILE__, __LINE__)
#define TS_EXPECT_FAIL_END() _EndExpectFailure(__FILE__, __LINE__)
#define TS_REPORT_SUMMARY(suite) _ReportSummary(suite)

#endif // TRADESPINE_TESTING_ASSERT_MQH
//+------------------------------------------------------------------+
