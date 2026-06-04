# EARS-01: TradeSpine Formal Requirements

> Human-readable rendering generated from `EARS-01_tradespine_formal_requirements.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | EARS-01 |
| Title | TradeSpine Formal Requirements |
| Status | Approved |
| Version | 1.0 |
| BDD-ready score | 100/100 |
| Source PRD | @prd: PRD.01.09.9e71 |
| BRD reference | @brd: BRD.01.03.d116 |
| Created | 2026-06-01T19:30:00-03:00 |
| Updated | 2026-06-01T20:01:34-03:00 |

### Revision History

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.0 | 2026-06-01T19:30:00-03:00 | Codex | Initial EARS generated from approved PRD-01 and TradeSpine source brief. |
| 1.0.1 | 2026-06-01T19:49:37-03:00 | Codex | Clarified two-session behavior, one-day session-open expiration warnings, mandatory symbol-information validation, and day-trade no-overnight close. |
| 1.0.2 | 2026-06-01T20:01:34-03:00 | phbr | Approved EARS-01 for downstream BDD generation. |

## Purpose and Context

TradeSpine EARS formalizes approved PRD-01 product capabilities into atomic, testable statements for downstream BDD scenarios.

Scope covers v1 strategy authoring, guarded execution, runtime risk controls, account-mode ownership, B3 futures market context, audit evidence, release governance, and performance gates.

Audience: system architects, MQL5 developers, QA reviewers, and release reviewers.

## Requirements

### Event-Driven

| ID | Name | Statement | Traceability |
| --- | --- | --- | --- |
| EARS.01.03.4c3f | Shipped strategy packaging | WHEN a shipped v1 strategy artifact is compiled, THE strategy artifact SHALL consist of one strategy mq5 file plus shared TradeSpine includes WITHIN the v1 release compile gate. | @brd: BRD.01.07.88a6 \| @prd: PRD.01.09.5ef1 |
| EARS.01.03.b784 | Strategy helper routing | WHEN a strategy requests an entry or exit helper, THE strategy artifact SHALL route the request through documented TradeSpine helper calls WITHIN the strategy lifecycle hook that raised the request. | @brd: BRD.01.07.88a6 \| @prd: PRD.01.09.eaf3 |
| EARS.01.03.0c0a | Strategy implementation guide | WHEN a strategy author starts a new v1 strategy or ports an existing hedging strategy, THE documentation set SHALL provide file structure, lifecycle hooks, helper calls, common inputs, logging expectations, compile checklist, simple-sample walkthrough, and hedging-port expectations WITHIN the authoring guide. | @brd: BRD.01.07.88a6 \| @prd: PRD.01.09.eaf3 |
| EARS.01.03.222f | Catastrophic safety rejection | WHEN a framework-mediated order request violates catastrophic safety constraints, THE guarded execution path SHALL reject the request before broker handoff WITHIN the submit pipeline. | @brd: BRD.01.07.a94e \| @prd: PRD.01.09.d74e |
| EARS.01.03.375b | Runtime risk trip | WHEN daily loss, max open lots, max trades per day, or panic stop trips for a strategy instance, THE runtime risk controls SHALL refuse new entries and trigger strategy-scoped close behavior WITHIN the current strategy lifecycle. | @brd: BRD.01.07.a94e \| @prd: PRD.01.09.4fb4 |
| EARS.01.03.4e80 | Indicator readiness entry block | WHEN a registered indicator is not ready, THE coordinator SHALL block new entries WITHIN the entry request. | @brd: BRD.01.07.a94e \| @prd: PRD.01.09.5963 |
| EARS.01.03.a0fa | Intent evidence before submission | WHEN a framework-mediated entry is accepted for submission, THE audit evidence component SHALL write intent evidence before broker submission WITHIN the submit pipeline. | @brd: BRD.01.07.8e15 \| @prd: PRD.01.09.9d68 |
| EARS.01.03.6c85 | Execution evidence after broker outcome | WHEN the broker returns an order or deal outcome, THE audit evidence component SHALL write execution evidence WITHIN the reconciliation pipeline. | @brd: BRD.01.07.8e15 \| @prd: PRD.01.09.9d68 |
| EARS.01.03.7669 | Day-trade close trigger | WHEN day-trade mode enters the close buffer before market trade session close, THE framework SHALL close all strategy-owned positions and cancel strategy-owned pending orders WITHIN the day-trade close sequence. | @brd: BRD.01.07.69ef \| @prd: PRD.01.09.d722 |
| EARS.01.03.db97 | Expiration warning trigger | WHEN the market trade session opens and a supported futures contract expires in one broker day, THE market context component SHALL surface a contract-expiration warning WITHIN the session-open lifecycle event. | @brd: BRD.01.07.69ef \| @prd: PRD.01.09.42eb \| @fixed-threshold: PRD.01.market.expiration_warning_one_broker_day |
| EARS.01.03.03b2 | Symbol metadata initialization | WHEN a strategy instance initializes, THE market context component SHALL load required symbol information for lot step, lot limits, price grid, tick size, tick value, contract size, digits, and trade mode WITHIN init. | @brd: BRD.01.07.69ef \| @prd: PRD.01.09.fada |
| EARS.01.03.ec72 | Order definition symbol validation | WHEN a framework-mediated order is defined, THE order definition path SHALL validate sizing, lots, stop prices, and price grid against initialized symbol information WITHIN the order calculation pipeline. | @brd: BRD.01.07.69ef \| @prd: PRD.01.09.60ad |
| EARS.01.03.d7e9 | Deferred account-mode evidence gate | WHEN release sign-off validates v1 account-mode behavior, THE release reviewer SHALL require evidence that netting and exchange-netting modes fail initialization with a deferred-mode diagnostic WITHIN the v1 release gate. | @brd: BRD.01.07.b44d \| @prd: PRD.01.09.0764 |
| EARS.01.03.1d60 | Documentation release gate | WHEN a v1 release candidate is reviewed, THE release reviewer SHALL verify required docs, same-change documentation updates, Doxygen coverage if retained, and CHANGELOG decision record WITHIN release sign-off. | @brd: BRD.01.07.717b \| @prd: PRD.01.09.4c66 |

### State-Driven

| ID | Name | Statement | Traceability |
| --- | --- | --- | --- |
| EARS.01.03.1a3e | User trading-hours entry gate | WHILE a strategy is evaluating a new entry, THE session context SHALL allow the entry only when the market trade session is open and the user-defined strategy trading-hours window both hold WITHIN broker server time. | @brd: BRD.01.07.69ef \| @prd: PRD.01.09.efcd |
| EARS.01.03.5d1b | Netting/exchange deferred-mode invariant | WHILE an account is netting or exchange-netting in v1, THE account-mode adapter SHALL fail initialization before any trade path, virtual ledger, pending-exit tracker, or execution mutex becomes active. | @brd: BRD.01.07.b44d \| @prd: PRD.01.09.7767 |
| EARS.01.03.fb67 | Hedging ownership invariant | WHILE an account is hedging, THE account-mode adapter SHALL record strategy ownership against relevant broker tickets or orders WITHIN every ownership update. | @brd: BRD.01.07.b44d \| @prd: PRD.01.09.a252 |
| EARS.01.03.a71c | Diagnostic log separation | WHILE diagnostic logging is enabled, THE logging components SHALL keep strategy and framework diagnostic logs separate from trade evaluation records WITHIN all evidence outputs. | @brd: BRD.01.07.8e15 \| @prd: PRD.01.09.c622 |
| EARS.01.03.6bda | Halt safety state | WHILE a strategy instance is in HALT, THE framework SHALL block non-emergency trading helpers and preserve last-known state WITHIN the persisted strategy lifecycle. | @brd: BRD.01.07.a94e \| @prd: PRD.01.09.7608 |
| EARS.01.03.c5b7 | Idle path low I/O | WHILE the framework processes idle ticks without trade work, THE runtime SHALL perform no GV writes, history scans, chart redraws, or order scans WITHIN the idle tick path. | @brd: BRD.01.07.bf02 \| @prd: PRD.01.09.3092 |
| EARS.01.03.5e92 | Futures risk percent sizing | WHILE calculating SIZING_RISK_PERCENT for a v1 futures strategy, THE position sizer SHALL use initialized symbol information to calculate broker-valid lots from risk percent and stop-loss distance WITHIN the order calculation pipeline. | @brd: BRD.01.07.69ef \| @prd: PRD.01.09.60ad |
| EARS.01.03.bc8b | Fixed lot sizing | WHILE calculating SIZING_FIXED_LOT for a v1 futures strategy, THE position sizer SHALL normalize fixed lots against initialized symbol information WITHIN the order calculation pipeline. | @brd: BRD.01.07.69ef \| @prd: PRD.01.09.60ad |

### Optional

| ID | Name | Statement | Traceability |
| --- | --- | --- | --- |
| EARS.01.03.932d | Equity sizing placeholder | WHERE SIZING_FIXED_CASH or SIZING_PCT_EQUITY is selected in v1, THE position sizer SHALL reject the sizing request as a visible v2 placeholder. | @brd: BRD.01.07.69ef \| @prd: PRD.01.09.60ad |
| EARS.01.03.f562 | Strategy-scoped panic | WHERE InpPanicStop is true for a v1 hedging strategy instance, THE kill-switch SHALL close only that strategy instance's owned tickets. | @brd: BRD.01.07.a94e \| @prd: PRD.01.09.4fb4 |
| EARS.01.03.9abb | Doxygen coverage gate | WHERE Doxygen remains part of the implementation standard, THE release reviewer SHALL verify API documentation coverage before v1 release sign-off. | @brd: BRD.01.07.717b \| @prd: PRD.01.09.4c66 |

### Unwanted Behavior

| ID | Name | Statement | Traceability |
| --- | --- | --- | --- |
| EARS.01.03.7a9c | Unsafe broker handoff prevented | IF catastrophic guard validation fails, THE guarded execution path SHALL return a rejection reason and prevent broker submission WITHIN the submit pipeline. | @brd: BRD.01.07.a94e \| @prd: PRD.01.09.d74e |
| EARS.01.03.588b | Ambiguous async outcome halt | IF async fill, cancel, or reconciliation state is ambiguous, THE state manager SHALL enter HALT rather than infer ownership WITHIN reconciliation. | @brd: BRD.01.07.a94e \| @prd: PRD.01.09.7608 |
| EARS.01.03.7d34 | Duplicate magic collision | IF another live strategy instance owns the same account symbol magic identity in the same terminal, THE duplicate magic guard SHALL fail or safely recover initialization WITHIN init. | @brd: BRD.01.07.b44d \| @prd: PRD.01.09.3f12 |
| EARS.01.03.e152 | Missing symbol metadata | IF required symbol metadata is missing or invalid at init, THE market context component SHALL fail initialization WITHIN init. | @brd: BRD.01.07.69ef \| @prd: PRD.01.09.fada |
| EARS.01.03.368c | Unsupported symbol scope | IF a symbol is outside the validated v1 futures scope, THE market context component SHALL block release validation for that symbol WITHIN symbol validation. | @brd: BRD.01.07.69ef \| @prd: PRD.01.09.fada |
| EARS.01.03.45ed | Day-trade close failure | IF day-trade forced close cannot complete before market trade session end, THE framework SHALL enter HALT and preserve unresolved strategy-owned exposure evidence WITHIN the day-trade close sequence. | @brd: BRD.01.07.69ef \| @prd: PRD.01.09.d722 |
| EARS.01.03.e06b | Contract expired warning | IF a supported futures contract is at or past expiration at session open, THE market context component SHALL surface an expired-contract warning WITHIN the session-open lifecycle event. | @brd: BRD.01.07.69ef \| @prd: PRD.01.09.42eb |
| EARS.01.03.e1ae | Deferred account-mode evidence missing | IF netting or exchange-netting deferred-mode init-failure evidence is missing, THE release gate SHALL block v1 sign-off WITHIN release review. | @brd: BRD.01.07.b44d \| @prd: PRD.01.09.0764 |

### Ubiquitous

| ID | Name | Statement | Traceability |
| --- | --- | --- | --- |
| EARS.01.03.a023 | Trade evidence pairing | THE audit evidence component SHALL pair intent and execution records for each accepted framework-mediated entry for post-trade evaluation. | @brd: BRD.01.07.8e15 \| @prd: PRD.01.09.9d68 |
| EARS.01.03.fef3 | Slippage fields | THE trade evaluation record SHALL include intended price, actual fill price, and slippage points for entries and exits. | @brd: BRD.01.07.8e15 \| @prd: PRD.01.09.c1fc |
| EARS.01.03.2be9 | User trading-hours entry-only scope | THE session model SHALL keep market-session close handling independent from the user-defined strategy trading-hours entry window for v1 day-trade operation. | @brd: BRD.01.07.69ef \| @prd: PRD.01.09.efcd |
| EARS.01.03.3f57 | Day-trade no overnight roll | THE day-trade mode SHALL prevent strategy-owned positions from rolling into the next trading day for v1 day-trade operation. | @brd: BRD.01.07.69ef \| @prd: PRD.01.09.d722 |
| EARS.01.03.4f9d | Hedging-first account mode boundary | THE account-mode abstraction SHALL support hedging execution in v1 and expose netting and exchange-netting as deferred modes that fail initialization before trading. | @brd: BRD.01.07.b44d \| @prd: PRD.01.09.5cce |
| EARS.01.03.dcc4 | One chart symbol scope | THE strategy runtime SHALL bind each strategy instance to one chart symbol for v1 strategy execution. | @brd: BRD.01.10.b11c \| @prd: PRD.01.12.9a32 |
| EARS.01.03.95ea | Multiple strategies per symbol | THE framework SHALL support multiple same-symbol strategy instances with distinct magic numbers on hedging accounts in v1. | @brd: BRD.01.07.b44d \| @prd: PRD.01.09.5cce |
| EARS.01.03.b11a | Vendored dependency policy | THE framework source SHALL use the vendored standard-library dependency foundation for reproducible builds. | @brd: BRD.01.04.3030 \| @prd: PRD.01.12.e9ec |
| EARS.01.03.e20a | Repository broker bypass check | THE repository checks SHALL detect prohibited direct broker submission in strategy files for release sign-off. | @brd: BRD.01.07.a94e \| @prd: PRD.01.09.d74e |
| EARS.01.03.8044 | Performance budget release evidence | THE release evidence SHALL cover tester overhead, memory per EA, idle-tick overhead, and low-I/O write budgets for v1 performance sign-off. | @brd: BRD.01.07.bf02 \| @prd: PRD.01.09.3092 \| @threshold: PRD.01.perf.tester_overhead \| @threshold: PRD.01.perf.memory_per_ea \| @threshold: PRD.01.perf.idle_tick |

## Quality Attributes

| ID | Area | Statement | Target | Traceability |
| --- | --- | --- | --- | --- |
| EARS.01.04.7c85 | Performance | THE framework benchmark SHALL keep matched tester overhead at or below the PRD tester overhead threshold for v1 release. | p50 <=10%, p95 <=10%, p99 reported | @brd: BRD.01.07.bf02 \| @prd: PRD.01.09.3092 \| @threshold: PRD.01.perf.tester_overhead |
| EARS.01.04.fc86 | Performance | THE framework runtime SHALL keep memory overhead at or below the PRD per-EA memory threshold for v1 release. | p50 <=2 MB, p95 <=2 MB, p99 reported | @brd: BRD.01.07.bf02 \| @prd: PRD.01.09.3092 \| @threshold: PRD.01.perf.memory_per_ea |
| EARS.01.04.9c45 | Performance | THE framework idle path SHALL keep idle-tick overhead at or below the PRD idle tick threshold for v1 release. | p50 <=50 us, p95 <=50 us, p99 reported | @brd: BRD.01.07.bf02 \| @prd: PRD.01.09.3092 \| @threshold: PRD.01.perf.idle_tick |
| EARS.01.04.9de6 | Reliability | THE audit evidence component SHALL preserve paired intent and execution records for accepted entries with zero missing pairs in release tests. | p50 100%, p95 100%, p99 100% | @brd: BRD.01.07.8e15 \| @prd: PRD.01.09.9d68 |
| EARS.01.04.68e2 | Reliability | THE HALT state SHALL survive restart and clear only through reconcile-safe recovery in release tests. | p50 pass, p95 pass, p99 pass across release scenarios | @brd: BRD.01.07.a94e \| @prd: PRD.01.09.7608 |
| EARS.01.04.93fd | Security | THE release package SHALL trace every P1 EARS requirement to BRD and PRD sources before BDD generation. | aidoc-flow cumulative tag hierarchy | @brd: BRD.01.03.d116 \| @prd: PRD.01.09.841a |

## Traceability

### Upstream PRD References

- @prd: PRD.01.09.9e71
- @prd: PRD.01.09.88e3
- @prd: PRD.01.09.aaf8
- @prd: PRD.01.09.9cac
- @prd: PRD.01.09.baed
- @prd: PRD.01.09.841a

### Upstream BRD References

- @brd: BRD.01.03.d116
- @brd: BRD.01.07.88a6
- @brd: BRD.01.07.a94e
- @brd: BRD.01.07.b44d
- @brd: BRD.01.07.69ef
- @brd: BRD.01.07.8e15
- @brd: BRD.01.07.717b
- @brd: BRD.01.07.bf02

### Threshold References

| Tag | Value |
| --- | --- |
| @threshold: PRD.01.perf.tester_overhead | <=10% matched tester overhead |
| @threshold: PRD.01.perf.memory_per_ea | <=2 MB memory per EA |
| @threshold: PRD.01.perf.idle_tick | <=50 us idle tick |
| @fixed-threshold: PRD.01.market.expiration_warning_one_broker_day | 1 broker day before contract expiration |

## Glossary

| Term | Definition |
| --- | --- |
| EARS | Easy Approach to Requirements Syntax. |
| BDD-Ready | Score measuring EARS maturity for BDD transition. |
| Framework-mediated trade | Trade action requested through TradeSpine helper and safety paths. |
| Runtime risk controls | Per-EA daily loss, max open lots, max trades per day, and strategy-scoped panic stop controls. |
| Two-layer session model | Entry gate requiring market trade-session availability and configured user trading-hours window. |
| Manual netting evidence pack | Deferred v2+ live or demo evidence for concurrent same-symbol netting behavior that Strategy Tester cannot automate. |
| Trade evaluation record | Structured intent and execution evidence used to evaluate strategy trading outcomes. |
