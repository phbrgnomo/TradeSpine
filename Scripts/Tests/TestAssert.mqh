//+------------------------------------------------------------------+
//|                                                   TestAssert.mqh  |
//|              Copyright 2026, Paulo Henrique Barreto Reboucas      |
//|                                                                  |
//| Minimal Tier-1 assertion harness for TradeSpine test scripts.    |
//| Modeled on the MetaTrader stdlib test convention (OnStart +      |
//| bool-returning tests + manual counters). No broker APIs.         |
//| Not part of an SDD SPEC contract - pure test scaffolding for     |
//| IPLAN-09 (TDD-09).                                               |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_TEST_ASSERT_MQH
#define TRADESPINE_TEST_ASSERT_MQH

int g_tests_run    = 0;   // total assertions evaluated
int g_tests_passed = 0;   // assertions that passed

//+------------------------------------------------------------------+
//| Reset the global counters (call at the start of OnStart).        |
//+------------------------------------------------------------------+
void ResetAsserts()
  {
   g_tests_run    = 0;
   g_tests_passed = 0;
  }

//+------------------------------------------------------------------+
//| Core boolean assertion. Logs PASS/FAIL and bumps counters.       |
//+------------------------------------------------------------------+
bool Check(const bool cond, const string msg)
  {
   g_tests_run++;
   if(cond)
     {
      g_tests_passed++;
      PrintFormat("  PASS: %s", msg);
      return(true);
     }
   PrintFormat("  FAIL: %s", msg);
   return(false);
  }

//+------------------------------------------------------------------+
//| Convenience wrappers.                                            |
//+------------------------------------------------------------------+
bool CheckTrue(const bool cond, const string msg)
  {
   return(Check(cond, msg));
  }

bool CheckFalse(const bool cond, const string msg)
  {
   return(Check(!cond, msg));
  }

//+------------------------------------------------------------------+
//| Double comparison within tolerance (never use == on doubles).    |
//+------------------------------------------------------------------+
bool CheckEqualD(const double a, const double b, const double tol, const string msg)
  {
   bool ok = (MathAbs(a - b) <= tol);
   if(!ok)
      PrintFormat("    expected %.10g, got %.10g (tol %.10g)", b, a, tol);
   return(Check(ok, msg));
  }

bool CheckEqualL(const long a, const long b, const string msg)
  {
   bool ok = (a == b);
   if(!ok)
      PrintFormat("    expected %I64d, got %I64d", b, a);
   return(Check(ok, msg));
  }

bool CheckEqualStr(const string a, const string b, const string msg)
  {
   bool ok = (a == b);
   if(!ok)
      PrintFormat("    expected '%s', got '%s'", b, a);
   return(Check(ok, msg));
  }

//+------------------------------------------------------------------+
//| Print the suite summary. Returns true when all assertions passed.|
//+------------------------------------------------------------------+
bool ReportSummary(const string suite)
  {
   bool all_pass = (g_tests_passed == g_tests_run);
   PrintFormat("==== %s: %d of %d passed%s ====",
               suite, g_tests_passed, g_tests_run,
               all_pass ? "" : "  <<< FAILURES >>>");
   return(all_pass);
  }

#endif // TRADESPINE_TEST_ASSERT_MQH
//+------------------------------------------------------------------+
