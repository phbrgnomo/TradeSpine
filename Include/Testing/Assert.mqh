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
//| Evidence kind classification (SPEC-11 data model).               |
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
//| One evidence assertion entry for ScenarioHarness.AssertEvidence. |
//+------------------------------------------------------------------+
struct EvidenceAssertion
  {
   ENUM_EVIDENCE_KIND expected_kind;   // intent, execution, diagnostic, state, or release
   string             expected_trace;  // spec/req tag substring expected in captured log output
   bool               required;        // false -> optional; absence is Skip, not FAIL
  };

//+------------------------------------------------------------------+
//| Manual deferred account-mode evidence pack.                      |
//| Empty artifacts field signals the pack is missing (blocks        |
//| release gate). Not replaced by automated evidence.               |
//+------------------------------------------------------------------+
struct DeferredAccountModeEvidencePack
  {
   string account_mode;  // e.g. "hedging", "netting"
   string scenario;      // deferred-mode validation scenario name
   string artifacts;     // file paths or operator notes; empty = missing
  };

//+------------------------------------------------------------------+
//| Lightweight state checkpoint for controlled-failure tests.        |
//+------------------------------------------------------------------+
struct AssertSnapshot
  {
   int tests_run;
   int tests_passed;
   int tests_skipped;
   int failure_count;
  };

//+------------------------------------------------------------------+
//| CAssert                                                          |
//+------------------------------------------------------------------+
class CAssert
  {
  private:
    int    m_tests_run;
    int    m_tests_passed;
    int    m_tests_skipped;
    string m_fail_msgs[];

    // Builds the "file:line" suffix appended to every failure message.
    string FormatLocation(const string file, const int line) const
      {
        return(StringFormat("%s:%d", file, line));
      }

    // Grows m_fail_msgs by one entry; pre-reserves TRADESPINE_ASSERT_FAILURE_RESERVE to minimise reallocs.
    bool AppendFailure(const string failure)
      {
        int n = ArraySize(m_fail_msgs);
        int resized = ArrayResize(m_fail_msgs, n + 1, TRADESPINE_ASSERT_FAILURE_RESERVE);
        if(resized != n + 1)
          {
          PrintFormat("    unable to record failure message: ArrayResize returned %d", resized);
          return(false);
          }
        m_fail_msgs[n] = failure;
        return(true);
      }

  public:
    // Initialises all counters to zero; failure message array starts empty.
    CAssert(void) : m_tests_run(0), m_tests_passed(0), m_tests_skipped(0) {}

    // Zeroes all counters and releases the failure message array; call before each test function.
    void Reset(void)
      {
        m_tests_run     = 0;
        m_tests_passed  = 0;
        m_tests_skipped = 0;
        ArrayResize(m_fail_msgs, 0);
      }

    // Counter accessors — read these in snapshot/restore patterns to verify assertion outcomes.
    int TestsRun(void) const { return(m_tests_run); }
    int TestsPassed(void) const { return(m_tests_passed); }
    int TestsSkipped(void) const { return(m_tests_skipped); }
    int FailureCount(void) const { return(ArraySize(m_fail_msgs)); }

    // Returns the recorded failure message at the given index, or "" if out of range.
    string FailureMessage(const int index) const
      {
        if(index < 0 || index >= ArraySize(m_fail_msgs))
          return("");
        return(m_fail_msgs[index]);
      }

    // Captures all four counters so a controlled-failure sub-test can be rolled back with Restore().
    AssertSnapshot Snapshot(void) const
      {
        AssertSnapshot snapshot;
        snapshot.tests_run     = m_tests_run;
        snapshot.tests_passed  = m_tests_passed;
        snapshot.tests_skipped = m_tests_skipped;
        snapshot.failure_count = ArraySize(m_fail_msgs);
        return(snapshot);
      }

    // Rewinds counters and truncates the failure array to the snapshot state, erasing intervening results.
    void Restore(const AssertSnapshot &snapshot)
      {
        m_tests_run     = snapshot.tests_run;
        m_tests_passed  = snapshot.tests_passed;
        m_tests_skipped = snapshot.tests_skipped;
        ArrayResize(m_fail_msgs, snapshot.failure_count, TRADESPINE_ASSERT_FAILURE_RESERVE);
      }

    // Increments the skip counter and prints a SKIP line; does not count as a run or failure.
    void _Skip(const string msg, const string file, const int line)
      {
        m_tests_skipped++;
        PrintFormat("  SKIP: %s  (%s)", msg, FormatLocation(file, line));
      }

    // Core assertion gate: increments run, increments passed on true, records failure message on false.
    bool _Check(const bool cond, const string msg, const string file, const int line)
      {
        m_tests_run++;
        if(cond)
          {
          m_tests_passed++;
          PrintFormat("  PASS: %s", msg);
          return(true);
          }

        string failure = StringFormat("%s  (%s)", msg, FormatLocation(file, line));
        AppendFailure(failure);
        PrintFormat("  FAIL: %s", failure);
        return(false);
      }

    // Compares two doubles within tol; rejects non-finite operands or a negative/NaN tolerance.
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

    // Compares two longs for exact equality; prints the expected/got pair on mismatch.
    bool _CheckEqualL(const long a, const long b, const string msg,
                      const string file, const int line)
      {
        bool ok = (a == b);
        if(!ok)
          PrintFormat("    expected %I64d, got %I64d", b, a);
        return(_Check(ok, msg, file, line));
      }

    // Compares two strings for exact equality; prints the expected/got pair on mismatch.
    bool _CheckEqualStr(const string a, const string b, const string msg,
                        const string file, const int line)
      {
        bool ok = (a == b);
        if(!ok)
          PrintFormat("    expected '%s', got '%s'", b, a);
        return(_Check(ok, msg, file, line));
      }

    // Prints the pass/fail/skip summary line and all failure messages; returns true if zero failures.
    bool _ReportSummary(const string suite)
      {
        int failed = m_tests_run - m_tests_passed;
        bool all_pass = (failed == 0);
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
          for(int i = 0; i < ArraySize(m_fail_msgs); i++)
              PrintFormat("  [FAILED] %s", m_fail_msgs[i]);
          }
        return(all_pass);
      }
    };

#define TS_CHECK(cond, msg) _Check(cond, msg, __FILE__, __LINE__)
#define TS_CHECK_EQ_D(a, b, tol, msg) _CheckEqualD(a, b, tol, msg, __FILE__, __LINE__)
#define TS_CHECK_EQ_L(a, b, msg) _CheckEqualL(a, b, msg, __FILE__, __LINE__)
#define TS_CHECK_EQ_STR(a, b, msg) _CheckEqualStr(a, b, msg, __FILE__, __LINE__)
#define TS_SKIP(msg) _Skip(msg, __FILE__, __LINE__)
#define TS_REPORT_SUMMARY(suite) _ReportSummary(suite)

#endif // TRADESPINE_TESTING_ASSERT_MQH
//+------------------------------------------------------------------+
