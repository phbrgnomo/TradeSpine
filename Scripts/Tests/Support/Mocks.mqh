//+------------------------------------------------------------------+
//|                                                       Mocks.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| Shared mock aliases and helpers for IPLAN-11 component tests.   |
//| Imports FakeClock and FakeLogSink and exposes convenience        |
//| typedefs for owner-plan test scripts.                            |
//| @spec: SPEC-11  @iplan: IPLAN-11                                 |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_TESTING_MOCKS_MQH
#define TRADESPINE_TESTING_MOCKS_MQH

#include "FakeClock.mqh"
#include "FakeLogSink.mqh"

typedef FakeClock*   TestClock_t;
typedef FakeLogSink* TestLogSink_t;

#endif // TRADESPINE_TESTING_MOCKS_MQH
//+------------------------------------------------------------------+
