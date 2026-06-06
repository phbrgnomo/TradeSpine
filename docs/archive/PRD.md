# TradeSpine — MQL5 Strategy Framework — Product Requirements Document

| | |
|---|---|
| **Document version** | 3.75 |
| **Date** | June 2, 2026 |
| **Author** | _(redacted)_ |
| **Status** | Architecture approved; MQL5 feasibility verified against standard-library source; ready to begin phased build |
| **Target** | Phased build: v0.1 → v0.9 → v1.0 |
| **Changelog** | Canonical decision log in CHANGELOG.md. Current entry: v3.75 (June 2, 2026). |

> **Project name:** **TradeSpine**. Root `MQL5/Experts/Main/TradeSpine/` (so EAs appear in the MT5 UI); framework code under `Include/`; quoted relative includes throughout (no symlink needed).

---

## 1. Executive Summary

A reusable MQL5 framework for designing, testing, and deploying trading strategies on MetaTrader 5, focused on Brazilian B3 futures for v1, with B3 equities planned for v2. Central premise: **every strategy file contains only strategy logic** — signal generation plus selection of pluggable stop/sizing/trailing behaviors — while all cross-cutting infrastructure lives in shared `MQL5/Experts/Main/TradeSpine/Include/` modules.

Strategies call imperative helpers (`OpenLong`/`OpenShort`/`CloseAll`/etc.) from whichever hook fits their cadence — `OnNewBar` for bar signals, `OnTickEvent` for tick signals (volatility spikes, spread capture, news). **All entries flow through a single `CTradeCoordinator` pipeline**: optional explicit SL/TP → stop policy (when SL/TP unset) → position sizing → catastrophic guard + execution → audit logging. This decouples *intent* from *execution*, produces a complete paired audit record per trade for Python/SQLite post-mortems, lets the optimizer sweep stop and sizing strategies against identical entry logic, and — because the coordinator depends on its collaborators through interfaces — makes the entry pipeline unit-testable with mocks.

The framework replaces both the 4,000-line monolith (current state, ~70% infrastructure) and the MQL5 standard-library `CExpert` family (known bugs, complexity, upstream-change risk). v1 executable account-mode scope is **hedging-first**: `RETAIL_HEDGING` is the supported/default runtime mode and strategy ownership is broker-native through magic-filtered tickets. Account mode remains explicit and selectable/diagnostic, but `RETAIL_NETTING` and `EXCHANGE` are deferred to v2+: selecting them in v1 fails initialization with an operator-facing "deferred account mode" error rather than running an incomplete virtual-ledger model. Futures sizing ships in v1, equity sizing is planned for v2, and multi-layer catastrophic protection prevents framework helpers from bypassing safety checks. The standard-library classes it builds on are **vendored and frozen** inside the repository for reproducibility.

## 2. Problem Statement

The author currently writes one EA per strategy, each reimplementing symbol caching, session windowing, state persistence, async fill reconciliation, externally-closed-position detection, filling-mode selection, stop/freeze clamping, margin-mode validation, chart lifecycle, restart recovery, and parameter validation. In the reference Turtle EA (4,081 lines, 65 functions, 39 inputs), ~70% is reusable infrastructure and only ~30% is strategy logic. This makes new strategies slow, error-prone, and dangerous: a sizing or filling-mode bug in any one EA can compromise a real-money account.

The framework collapses infrastructure to one audited layer, reducing a new strategy to ~80–200 lines of logic in a single file.

## 3. Goals

**G-1.** A new strategy is a single `.mq5` file under `MQL5/Experts/Main/TradeSpine/Experts/`. No companion file.

**G-2.** The strategy file contains: strategy inputs, a class derived from `CStrategyBase` (overriding a small set of hooks and declaring member sizer/stop/trail objects), and the MT5 entry-point shims.

**G-3.** Multi-layer catastrophic-error protection that **framework-provided helpers cannot bypass**. (Language-level bypass via raw `OrderSend` remains possible in any `.mq5`; repository policy forbids it and NF-11 grep-checks for it.) A catastrophic event is an execution-time logic flip exposing the account to losses substantially larger than the user-specified per-trade risk — e.g., a 1066-lot order when 1 lot was intended. The framework guarantees such an order never reaches the broker through framework helpers.

**G-4.** v1 executable account-mode support is **hedging-first** via `IAccountModeAdapter`: `RETAIL_HEDGING` is the default/supported mode and strategy ownership maps to broker tickets/orders. Strategy code remains mode-agnostic above the adapter boundary.

**G-4a.** Multiple TradeSpine EAs MUST be able to run on the same symbol in v1 **on hedging accounts** when `(account, symbol, InpMagicNumber)` is unique per strategy instance. `RETAIL_NETTING` and `EXCHANGE` remain selectable/detectable account-mode values but are **deferred v2+ executable modes**. In v1, selecting either mode returns `INIT_FAILED` with a clear deferred-mode diagnostic before live trading. The former virtual gross-position ledger and framework-owned pending SL/TP exit model is retained only as v2 design context, not as v1 release scope.

**G-5.** v1 supports **futures sizing** via `SIZING_RISK_PERCENT` (margin-based, sized by potential loss at SL distance) and `SIZING_FIXED_LOT` (backtest A/B). v1 does NOT implement equity sizing — the framework focuses on futures for v1. Equity sizing is a v2 deliverable with TWO planned modes, both at strategy-level definition: (a) **fixed-cash risk** — `lots = risk_brl / sl_distance_brl`, requires SL; "cash" is the fixed monetary risk ceiling per trade. (b) **pct-equity position-value** — `lots = (equity × pct) / price`, does not require SL, for cash-allocation strategies. The `SIZING_FIXED_CASH` and `SIZING_PCT_EQUITY` enum values exist as v1 placeholders to freeze the naming. SL/TP may be defined by the strategy (explicit) or delegated to a pluggable stop policy — flexibility of definition is a v1 requirement that holds across futures and (in v2) equities.

**G-6.** Optimization passes avoid unnecessary I/O, drawing, logging, persistence writes. `OptContext::IsOptimizing()` is the single source of truth.

**G-7.** Entries flow through one `CTradeCoordinator` pipeline; every entry emits a unified intent→execution audit payload. Strategies call imperative helpers (`OpenLong`/`OpenShort`/`CloseAll`/etc.) from whichever hook fits their cadence (`OnNewBar` for bar signals, `OnTickEvent` for tick signals such as volatility spikes, spread capture, or news).

**G-8.** A reference template plus FOUR v1 shipped strategy artifacts ship with v1: two simple implementation samples — Donchian breakout (primary) and Moving-Average crossing (secondary) — and two additional hedging strategy ports from existing EAs: `1minscalpv3_hedging.mq5` and `BullishBearish Engulfing all v7 hedging.mq5`. The simple samples remain the primary authoring walkthroughs; the ports prove migration of real existing strategy code into the hedging-first TradeSpine surface.

**G-9.** Documentation ships with v1: a developer can write a strategy from the docs without reading framework source.

**G-10.** The framework is unit-testable: pure-logic modules and the coordinator pipeline are testable without a live broker, via dependency injection and mocks.

**G-11.** The framework is reproducible: the standard-library classes it depends on are vendored and frozen in the repository, immune to silent MetaQuotes updates.

## 4. Non-Goals (v1)

| Item | Status | Rationale |
|---|---|---|
| Multi-symbol strategies | v4+ | One EA = one chart = one symbol for v1–v3. |
| Multi-timeframe orchestration | v3 | Strategy may call `CopyBuffer` on a higher TF manually in v1. |
| Netting / exchange-netting executable mode | v2+ | v1 defaults to hedging; netting/exchange remain selectable/diagnostic but fail initialization as deferred modes. Virtual-ledger ownership, pending-exit OCO, execution mutex, and manual concurrent netting evidence move to v2+. |
| Pyramiding / scaling-in | v2 | Needs unit accounting beyond v1 single-position hedging behavior; state machine designed to extend for it. |
| Partial-close manager (behavior module) | v2 | Partial-close *mechanics* exist in adapters for v1; the strategic *manager* is v2. |
| `ISignalFilter` + concrete filters | v2 | Defer interface until a concrete filter exists. |
| Adaptive / drawdown-scaled sizer | v2 | Good idea (from v2.2.0 draft); needs running-drawdown figure (kill-switch will have it). |
| Kelly sizer | v3+ | Requires accumulated track record. |
| Portfolio EA (multi-strategy) | v4+ | Different paradigm; base class designed to enable it later. |
| Custom `OnTester` criteria | v2 | v1 ships default `STAT_PROFIT`; overridable. |
| WebRequest / external APIs | v3+ | Synchronous, tester-hostile; needs async pattern. |
| UI panels | v3+ | Chart-comment + Print sufficient. |
| News blackout | v3+ | Needs reliable data source. |
| In-EA advanced analytics (Sharpe/Sortino/walk-forward/DSR) | Python | Framework reports data; Python ETL analyzes it. See §11b for the PSR-in-loop / DSR-in-Python statistical-validation division. |
| B3Defaults fallback constants | Rejected | All symbol data from `CSymbolInfo`; fail loudly on bad data. |
| MQL4 compatibility | Rejected | MT5 only. |

## 5. Target Users

**Primary** — _(redacted)_; author and operator; intermediate-to-advanced MQL5. **Secondary (future)** — an average MQL5 developer who can read classes and `input`s but should not need expertise in async transactions, hedging ticket ownership, or filling modes (all encapsulated). Netting/exchange ownership math is deferred to v2+.

## 6. Market Scope

B3 primary for v1: WIN/WDO/IND/DOL futures. B3 equities (including fractional) are planned v2 scope and may appear in enums/docs as placeholders only. Account modes are detected from MT5 (`EXCHANGE`, `RETAIL_NETTING`, `RETAIL_HEDGING`), but v1 executable scope is `RETAIL_HEDGING` only. `EXCHANGE` and `RETAIL_NETTING` are deferred v2+ modes and fail initialization in v1 with an explicit diagnostic. Currency primarily BRL (not hard-coded). Forex/US/CFD not actively prevented but not hardened in v1.

## 7. Architectural Principles

**P-1. Single execution chokepoint.** All framework order flow passes through `CGuardedTrade`, which uses **composition** (owns a private `CTrade`) — because `CTrade`'s `Buy/Sell/PositionClose/...` are non-virtual (verified from source); only `OrderSend/OrderCheck/CheckVolume` are virtual. Strategies cannot reach the inner `CTrade`.

**P-2. Defense in depth on sizing.** Three independent layers: (a) sizer snaps to broker step + broker min/max; (b) `CGuardedTrade` applies user catastrophic caps; (c) final pre-submit sanity check (finite, side, SL/TP topology, margin).

**P-3. Strategies are classes; the framework owns the lifecycle.** `CStrategyBase` provides the lifecycle (inheritance for strategy variation) and **composes** its components (sizer, stop policy, position context, coordinator) per the "compose components, inherit variation" principle. `CStrategyBase` creates and owns the single `CPositionStateMachine` instance and passes references to it at construction: one reference to `CPositionContext` (so `CTradeTxRouter` can fire transitions from the `OnTradeTransaction` path) and one reference to `CTradeCoordinator` (so the reconciliation pump can drive the same instance). No other object creates or owns the state machine.

**P-4. Pluggable behavior over conditional code.** Sizer, stop policy, trailing — declared as members, wired by overriding `Get...()` hooks; not `if(InpFeature)` branches.

**P-5. Optimization is a first-class mode.** `OptContext::IsOptimizing()` consulted everywhere; heavy paths early-return.

**P-6. Lifecycle staging is explicit and enforced.** Four phases, each logged at INFO: (1) Construct — no framework services; (2) Framework-init — modules built, adapter selected, queries safe, *no trading*; (3) Strategy-init — `OnStrategyInit()`, install dependencies, *no trading*; (4) Live — event loop, trading allowed. Trade attempts before phase 4 fail fast (ERROR + return 0).

**P-7. Intent is separated from execution.** Strategies call imperative entry helpers; internally those construct a canonical `Signal` and run the `CTradeCoordinator` pipeline, which computes stops/size, guards, executes, and logs a unified payload. The strategy never authors `Signal` directly — it's the framework's internal intent representation, not a strategy contract.

**P-8. Testability through seams.** The coordinator depends on collaborators (`IPositionSizer`, `IStopPolicy`, `ITradePort`) through interfaces, so the entry pipeline is unit-testable with mock implementations, without a live broker.

**P-9. Reproducibility through vendoring.** The standard-library subtree the framework depends on is copied (vendored) into `MQL5/Experts/Main/TradeSpine/Include/StdLib/`, frozen, and git-tracked. Framework code includes only from the vendored path. Updates are deliberate, tested, and committed — never silent terminal updates.

**P-10. Paradigm by fit, not dogma.** Use classes where state or polymorphism is fundamental (the position state machine, kill-switch, coordinator, account-mode adapters, indicator wrappers, sizers/stops/trails as swappable policies). Write pure logic as free functions in namespaces even within the framework (`SafeMath`, sizing formulas, stop-distance math, slippage computation) — anything that is input→output with no retained state. Do NOT wrap pure functions in classes merely for consistency, and do NOT thread state through function arguments to avoid a class where state is genuinely intrinsic. MQL5 lacks the tooling (REPL, rich value-printing, immutable structures) that makes pure-functional style pay off elsewhere, so the split is pragmatic: classes for stateful/polymorphic concerns, free functions for pure computation. This principle governs every module's internal implementation.

## 7b. Standard Library Policy

Criterion: *does our use require assuming internal behavior that could change?*

| Item | Policy | Rationale |
|---|---|---|
| `CTrade` | **Vendor + compose** (private member inside `CGuardedTrade`). | Convenience methods non-virtual (verified); composition gives one validated path; vendoring freezes behavior. |
| `CSymbolInfo` | Vendor; inherit/wrap inside `CSymbolContext`. | Public-method use; vendored to freeze. |
| `CAccountInfo` | Vendor; inherit/wrap inside `CAccountContext`. | Same. |
| `CPositionInfo` | Vendor; inherit/wrap inside adapters. | Same. |
| `CDealInfo`, `COrderInfo`, `CHistoryOrderInfo` | Vendor; use directly. | Small, stable, read-only. |
| `Object.mqh` (`CObject`) + `StdLibErr.mqh` | **Vendor**; seven vendored `Trade/*.mqh` files that include `<Object.mqh>` are edited to `#include "../Object.mqh"` (total-freeze Option A). | `Object.mqh` is the base class and includes sibling `StdLibErr.mqh`; both are vendored so the freeze is complete. |
| `CExpert`, `CExpertSignal`, `CExpertMoney`, `CExpertTrailing` | **Do not use, do not vendor.** | Conflict with chokepoint; known `CExpertMoney` margin bug; replaced by our modules. |
| `Indicators/Indicators.mqh` | **Do not use.** | God-class; replaced by per-file `TradeSpine/Include/Indicators/`. |
| `CTrade::PositionClosePartial` | **Use only in hedging mode.** | Hedging-only — returns false when `!IsHedging()` (verified from source). Netting/exchange execution is deferred to v2+. |

NF-9 / NF-11 grep-check: framework includes only from the framework's own vendored `Include/StdLib/` (via quoted relative includes) (never `<Trade/...>` or `<Expert/...>`); strategy files contain no `<Trade/Trade.mqh>` include and no raw `OrderSend(`.

## 7c. Vendored Standard Library (`MQL5/Experts/Main/TradeSpine/Include/StdLib/`)

- Contents: `Object.mqh`, `StdLibErr.mqh`, and `Trade/{Trade, SymbolInfo, AccountInfo, OrderInfo, HistoryOrderInfo, PositionInfo, DealInfo}.mqh`. `TerminalInfo.mqh` also includes `<Object.mqh>` in the live terminal StdLib, but is not vendored in v1 because no v1 requirement uses `CTerminalInfo`.
- `VERSION.md` records the source terminal build and copy date.
- Seven vendored trade files (`Trade.mqh`, `SymbolInfo.mqh`, `AccountInfo.mqh`, `OrderInfo.mqh`, `HistoryOrderInfo.mqh`, `PositionInfo.mqh`, `DealInfo.mqh`) have their line-6 `#include <Object.mqh>` edited to `#include "../Object.mqh"` so the freeze is total (Option A). `Object.mqh` keeps its sibling include `#include "StdLibErr.mqh"`. All other internal includes are already relative and resolve among vendored siblings.
- Framework code includes the vendored standard-library files through quoted file-relative paths such as `#include "../StdLib/Trade/Trade.mqh"`; never the terminal's `<Trade/...>`.
- **Update procedure** (documented in `VERSION.md`): re-copy the selected subtree from a known terminal build → re-apply the seven `Object.mqh` include edits → run the full Tier-1 + Tier-2 test suite → commit. Updates are never automatic.

## 7d. Signal / Intent Pipeline

Types (in `TradeSpine/Include/Strategy/Signal.mqh`):

```
enum ENUM_SIGNAL_TYPE { SIGNAL_NONE, SIGNAL_LONG, SIGNAL_SHORT, SIGNAL_CLOSE };
enum ENUM_ENTRY_MODE  { ENTRY_MARKET, ENTRY_STOP, ENTRY_LIMIT };

struct Signal {
   ENUM_SIGNAL_TYPE type;
   ENUM_ENTRY_MODE  entry_mode;     // default ENTRY_MARKET
   double           entry_price;    // ignored when ENTRY_MARKET; required otherwise
   double           sl_price;       // 0 = let stop policy compute (layered, not exclusive)
   double           tp_price;       // 0 = let stop policy compute (or none)
   string           comment;        // human-readable reason (-> CSV)
   string           metadata;       // "key=val;key=val" (-> CSV/ETL)
};

// v1 honors ENTRY_MARKET only. ENTRY_STOP/ENTRY_LIMIT are reject-with-ERROR
// in v1 ("pending entries are v2"); the enum exists now so Signal is
// forward-compatible and every entry declares its mode explicitly.
// Topology guard (v2): ENTRY_STOP long requires entry_price > ask (short < bid);
// ENTRY_LIMIT long requires entry_price < ask (short > bid). Wrong-side price
// for the declared mode is REJECTED, never reinterpreted.

struct StopLevels { double sl_price; double tp_price; double sl_distance; };
// v1: ONE sl + ONE tp per position (the broker holds one of each anyway).
// Multi-level TP ladders (scale out 1/3 at TP1, 1/3 at TP2, runner) are a
// v2 partial-close-manager concern, NOT an entry-intent array: intermediate
// TPs are MANAGEMENT actions (close X lots at price Y), not properties of the
// entry. Keeping StopLevels single-valued avoids speculative structure for a
// deferred feature.
// Failure sentinel: IStopPolicy.ComputeStops signals failure by returning
// sl_distance <= 0 (e.g. {0,0,0}). The §7d step-5 gate rejects the trade on
// sl_distance <= 0 — no exception or out-of-band error return is required.

struct TradeIntent {                // unified, serializable audit payload
   Signal     signal;
   double     entry;
   StopLevels stops;
   double     risk_percent;
   double     lots_requested;
   datetime   ts;
   string     symbol;
   ulong      magic;
};
```

Strategy → pipeline. The strategy calls `OpenLong(comment, ...)` / `OpenShort(comment, ...)` from inside any hook (`OnNewBar` for bar signals, `OnTickEvent` for tick signals); the helper constructs a `Signal` from its arguments and the framework's resolved defaults (entry mode = MARKET, sl/tp = 0 → stop policy will compute, risk = `GetRiskPercent()` unless overridden), then calls `CTradeCoordinator::ProcessSignal(Signal)`. Only raw `CTrade` is forbidden.

Pipeline steps in `ProcessSignal`:
1. `SIGNAL_CLOSE` → close ONLY this EA's owned exposure via the active `IAccountModeAdapter` close path. In v1 the only executable adapter is **hedging**, so this iterates this EA's tickets/orders by magic+symbol. If the account is `RETAIL_NETTING` or `EXCHANGE`, the strategy never reaches live trading because v1 initialization fails with a deferred-mode diagnostic. Close helpers (`CloseAll`/`CloseLots`/`ClosePosition`) route through the COORDINATOR — so the audit trail is unified for this strategy's entries and exits — but they do NOT pass through the entry sizing/stop sub-pipeline (no `IStopPolicy`/`IPositionSizer` step; closing needs neither). The `SIGNAL_CLOSE` path described here is the coordinator's close branch, distinct from the entry branch. Done.
2. State-machine gate: accept entry only if `FLAT` (else reject + DEBUG).
3. entry: if `signal.entry_mode == ENTRY_MARKET` → use market price for side (ignore `signal.entry_price`); if `ENTRY_STOP`/`ENTRY_LIMIT` (v2) → use `signal.entry_price` AFTER wrong-side rejection per §7d topology guard. Resolution by entry-mode (not by `entry_price>0`) prevents a typo'd market-order price from accidentally becoming a pending stop order.
4. stops (independent layers, NOT exclusive): start with `sl_price`/`tp_price` from the Signal where the strategy supplied them; for any field still 0, call `GetStopPolicy().ComputeStops(signal, entry)` and use its result. Trailing (modifies the SL over the position's life, F-TRAIL-3/4) and exit-signal closes (`CloseAll` from strategy code) are SEPARATE LAYERS that operate AFTER entry — they coexist with the entry SL/TP, do not replace it. See F-TRAIL-4 for the layered-exit coexistence model.
5. reject + ERROR if a stop is required but the resolved `sl_distance <= 0` (neither the Signal nor the stop policy produced a usable SL).
6. risk = `GetRiskPercent()` — the strategy's sizing module is the sole authority on risk per trade; per-call overrides would undermine that abstraction.
7. lots = `GetSizer().CalcLots({side, entry, sl_price, risk})`; reject + ERROR if `<=0`.
8. build `TradeIntent`; `TradeLogger.LogIntent(intent)` (before execution).
9. `result = ITradePort.Submit(intent)` (production: `CGuardedTrade`; tests: mock).
10. `TradeLogger.LogExecution(intent, result)`; advance state machine.

## 8. Folder Structure

EAs must live under `MQL5/Experts/` to appear in the MT5 Navigator UI, so the project root is `MQL5/Experts/Main/TradeSpine/`. Everything (framework code, docs, strategies, scripts, tests, logs, journals) lives beneath this root. Python ETL tooling lives in a separate repository entirely — there is NO `Backtests/` folder inside the MQL5 tree.

```
MQL5/Experts/Main/TradeSpine/
  Include/              framework libraries (Core, Market, Risk, Execution,
                        Position, Coordination, Persistence, Indicators,
                        Strategy/Stops, Strategy/Trailing, Optional, Testing,
                        External, StdLib (vendored)) — see §9 for modules
  Docs/                 README, ARCHITECTURE, AUTHORING, RECIPES,
                        INPUTS_REFERENCE, TESTING, MODULES/*.md
  Experts/              shipped strategy artifacts: simple samples
                        (DonchianBreakout.mq5, MovingAverageCross.mq5),
                        hedging ports (1minscalpv3_hedging.mq5,
                        BullishBearish Engulfing all v7 hedging.mq5),
                        and _Template/
    _Template/          StrategyTemplate.mq5 + README.md
    Logs/               per-EA execution logs (rolling, gitignored)
  Scripts/              one-use scripts (data utilities, maintenance)
    Tests/              framework Tier-1 and Tier-1.5 tests (Test_*.mq5, RunAllTests.mq5)
  TradeJournals/        per-EA trade CSVs from TradeLogger
                        (physical path: MQL5/Files/TradeJournals/ — MQL5 file-I/O sandbox)
    {EAName}/{Symbol}_{Timeframe}/   one folder per strategy/symbol/TF
  Experts/Logs/         per-EA execution logs — rolling, gitignored
                        (physical path: MQL5/Files/Logs/ — MQL5 file-I/O sandbox)
```

**Include resolution.** Per MQL5 docs (`mql5.com/en/book/basis/preprocessor/preprocessor_include`), angle-bracket `<X>` includes resolve from `MQL5/Include/` only, while quoted `"X"` includes resolve relative to the file using the `#include` statement and may walk subdirectories (or up the tree with `..`). TradeSpine uses **quoted relative includes throughout**, with forward slashes (MQL5 normalizes them on Windows; docs confirm forward slashes are valid and more portable than escaped backslashes). No install-time symlink required.

Concrete include syntax examples:

- A strategy at `MQL5/Experts/Main/TradeSpine/Experts/MyStrategy.mq5` reaches the framework base class with `#include "../Include/Strategy/StrategyBase.mqh"`.
- A strategy one level deeper at `MQL5/Experts/Main/TradeSpine/Experts/SubFolder/MyStrategy.mq5` uses `#include "../../Include/Strategy/StrategyBase.mqh"`.
- Framework files including sibling framework files use ordinary relative paths: `#include "Signal.mqh"` for same-folder, `#include "../Core/Logger.mqh"` for cross-folder.
- The vendored StdLib path becomes (from `Include/Strategy/StrategyBase.mqh`) `#include "../StdLib/Trade/Trade.mqh"`. The `Object.mqh` relative-include edit (`"../Object.mqh"`) inside the vendored `Trade.mqh` is unaffected by the project's root location — it is file-relative by construction.

This decision has one operational cost worth naming: framework files (`.mqh`) embed relative paths to their dependencies, so moving a file inside the framework tree means updating the paths in files that included it. In return: zero install-time setup, fully self-contained source tree, no symlink permission issues on shared/locked systems, and clean `git clone` → compile workflow.

**File I/O sandbox.** MQL5 `FileOpen`/`FileWrite` writes only into `MQL5/Files/` (or the common-files folder with `FILE_COMMON`). The paths shown for `TradeJournals/` and `Logs/` above describe the logical structure within the project; at runtime they resolve to `MQL5/Files/TradeJournals/` and `MQL5/Files/Logs/` respectively. This means these folders are outside the git tree by construction.

**Git:** repo rooted at `MQL5/Experts/Main/TradeSpine/`. `.gitignore` includes `MQL5/Files/Logs/`, `MQL5/Files/TradeJournals/`, `*.ex5`, and terminal-generated files. Python analytics tooling has its own repository outside the MQL5 tree.

## 9. Functional Requirements

### Core
- **F-CORE-1** `OptContext`: `IsOptimizing/IsTesting/IsVisualMode/IsLive`.
- **F-CORE-2** `Logger`: leveled (DEBUG/INFO/WARN/ERROR), auto-off in optimization, level controlled by the `InpLogLevel` common input plus master `InpEnableLogs` (both in `CommonInputs`, F-STRAT-6), logs 4 lifecycle transitions; system/debug → Journal. Trade-execution + state-change data → CSV via `TradeLogger` (F-CORE-7); files physically under `MQL5/Files/TradeJournals/` and `MQL5/Files/Logs/` per the MQL5 file sandbox.
- **F-CORE-3** `SafeMath`: `EqualDoubles`, `NormalizePrice`, `NormalizeLot` (strict `SYMBOL_VOLUME_MIN/MAX/STEP`), `IsValidLot`.
- **F-CORE-4** `Profiler`: `PROFILER_START/STOP/PRINT` macros wrap a code block and record its execution time, reporting only blocks exceeding a threshold (5 ms default). PURPOSE: it is the instrument that makes the NF-1 performance target (≤10% overhead) verifiable — wrap the framework's hot paths, run a representative backtest, confirm nothing exceeds budget. Auto-off in optimization (never slows what it measures); off by default in live. Scoped to **v0.1** — the macros are implemented from the start as thin stubs (compile correctly, record nothing); the profiling backend (timing measurement + threshold reporting) activates in early builds to validate NF-1 (≤10% overhead) and NF-3 (≤50 µs idle tick) targets before problems accumulate.
- **F-CORE-5** Slippage: every executed entry logs `intended_price` (from `TradeIntent.entry`) and `actual_fill_price` (from the DEAL record) plus their signed difference in points (`slippage_points`). For exits (close-all, day-trade-close, kill-switch close): same fields logged on the close DEAL. Slippage is a CSV column in `TradeLogger`'s execution record (F-CORE-7) — the framework reports it, Python ETL analyzes distributions. TradeSpine adds no application-level slippage gate beyond what `InpDeviation` (passed to the underlying vendored `CTrade`) already enforces at the broker layer; excessive slippage produces a `REQUOTE`/`PRICE_OFF` retcode handled by the retry loop (F-EXEC-8).
- **F-CORE-6** `CKeyBuilder` / `KeyHash`: deterministic framework-owned key generation for GV namespaces, duplicate markers, execution locks, and virtual-ledger fields. Canonical identity string format: `account|symbol|magic|scope|field`. GV names use `TS_<16hex_hash>_<short_field>`; raw account/symbol/magic identity appears only in logs/docs, not in GV names. Hash algorithm is a pure MQL5 implementation of 64-bit FNV-1a over UTF-8/ASCII-normalized identity strings, stable across terminal restarts and builds. Collision policy: every marker/ledger namespace stores a diagnostic identity hash (FNV-1a over the canonical identity string) as a GV field (`identity_check_hi/lo`); on init/reconciliation, the recomputed hash of the expected identity must match the stored value — mismatch means key collision or namespace corruption and causes `INIT_FAILED` before trading or `HALT` if detected live. (A second independent hash algorithm provides stronger collision independence but is deferred to v2 when the key namespace grows to a size where it matters.)

- **F-CORE-7** `TradeLogger`: defines two paired CSV records written per trade (before and after broker submission). Both files are append-only; a header row is written on first open. File pair is rolled at session start (one pair per calendar day).
  - **File paths** (within the `MQL5/Files/` sandbox): `TradeJournals/{EAName}/{Symbol}_{Timeframe}/YYYY-MM-DD_intent.csv` and `…_execution.csv`.
  - **LogIntent row** (written in pipeline step 8, before `ITradePort.Submit`):
    `ts_utc, symbol, magic, virtual_position_id, signal_type, entry_mode, side, intended_price, sl_price, tp_price, risk_percent, lots_requested, ledger_state_before, comment, metadata`
  - **LogExecution row** (written in pipeline step 10, after broker result):
    `ts_utc, symbol, magic, strategy_position_id, side, ticket, retcode, retry_count, lots_submitted, actual_fill_price, slippage_points, exit_role, close_reason, parent_order_ticket, sibling_order_ticket, ledger_state_before, ledger_state_after, margin_level` (on success) or `balance, equity, margin, margin_free, margin_level` (on rejection, per F-EXEC-4 stage 6). v1 hedging rows use ticket-backed strategy position identity; v2-only netting/OCO fields are empty where they do not apply.
  - No writes in optimization passes unless `InpAuditInOptimization` is true.
  - Cross-references: AC-14 (paired record per entry), AC-28 (slippage columns from F-CORE-5).

### Market
- **F-MKT-1** `SymbolContext` wraps vendored `CSymbolInfo`. Static attrs cached once; dynamic restrictions (stops/freeze level, spread, trade-allowed) queried fresh near submission.
- **F-MKT-2** Instrument classification (`FUTURES/EQUITY/FOREX/OTHER`) is derived from `CSymbolInfo` (`SYMBOL_CALC_MODE`, `SYMBOL_TRADE_MODE`); the sizer formula is parameterized entirely by symbol info — tick size, tick value, contract size, digits — never hard-coded per-instrument constants.
- **F-MKT-3** `NormalizeLot` and `NormalizePrice` snap to the symbol's grid (`SYMBOL_VOLUME_MIN/MAX/STEP` for lots; `SYMBOL_POINT`/`DIGITS`/`SYMBOL_TRADE_TICK_SIZE` for prices), all values read from `CSymbolInfo`. v1 validation targets B3 futures (including IND/DOL higher minimums); the same generic symbol-grid code is intended to support equity step sizes when equity sizing enters v2, without per-symbol special-casing.
- **F-MKT-4** Missing/invalid static attr at init → `INIT_FAILED` + ERROR. No fallback constants.
- **F-MKT-5** `AccountContext` wraps vendored `CAccountInfo`; exposes `IsNetting()` (true for both `RETAIL_NETTING` and `EXCHANGE`), `IsHedging()`, `MarginMode()` (raw `ENUM_ACCOUNT_MARGIN_MODE` for diagnostics/logs), and `IsSupportedForV1()`. v1 support returns true only for `RETAIL_HEDGING`; `RETAIL_NETTING` and `EXCHANGE` are deferred v2+ modes and fail initialization before trading.
- **F-MKT-6** `SessionContext` uses TWO layers. **(a) Market-open (broker-provided schedule):** `SymbolInfoSessionTrade(symbol, day, session, from, to)` supplies the broker/terminal session schedule for the symbol. TradeSpine treats it as scheduled-session data in the terminal/server context, not as a guaranteed exchange-calendar oracle for every B3 holiday, half-day, auction, or ad hoc halt. If broker returns no session data, fall back to "assume open" + WARN once. `OrderCheck`, trade retcodes, and symbol trade flags remain authoritative for real-time closures and halts. **(b) Strategy-active window (user inputs):** `InpSessionStart`/`InpSessionEnd` further restrict trading to a sub-window the strategy author chooses (e.g. trade only 10:00–16:00 even though the broker session is broader). Both values are entered in broker/server time; all session comparisons use `TimeCurrent()` directly — no offset input is used in v1. The user-input strategy-active window is REQUIRED — setting both to cover the full broker session is an explicit choice, not a missing input. `AllowsNewEntries()` returns true only if BOTH layers hold. `IsSessionOpen()` reflects layer (a) only. Broker-session read happens in Framework-init and refreshes at session boundaries.
- **F-MKT-7** Day-trade mode (`InpDayTradeMode`) with `InpCloseMinsBefore` buffer measured against the broker session close (layer a). When within the buffer, `ShouldForceDayTradeClose()` returns true and the framework executes a **complete strategy stop** in this order: (1) if this EA's state is `PENDING_ENTRY`, cancel the pending entry order immediately; if cancellation is ambiguous (fill race), reconcile canonical state: if the order filled in the race the state is now ACTIVE and the sequence continues to step 2; if canonical state is unresolvable → HALT (→ F-POS-13c); (2) close this EA's hedging tickets via the same path as `CloseAll`; (3) drive the state machine to `FLAT`; (4) `AllowsNewEntries()` returns false for the remainder of the session. Close reason is logged as `CR_DAY_TRADE_CLOSE`. If the close fails, the framework enters `HALT` for this strategy lifecycle. v2 netting pending-exit cancellation is not part of the v1 day-trade path.
- **F-MKT-8** Contract expiration warning. On init and at session-open, `SymbolContext` checks `SYMBOL_EXPIRATION_TIME`. If expiration is in one broker day, display a persistent chart comment "Symbol expiring on YYYY-MM-DD" and log WARN; if expiration is already past, display "Symbol EXPIRED" and log WARN. The warning threshold is fixed in v1 and has no operator input. v1 is warning-only; rollover detection (e.g. switching from `WINM26` to `WINQ26`) and continuous-contract handling are v3+. The EA continues trading regardless — the operator owns the rollover decision.

### Risk
- **F-RISK-1** `IPositionSizer.CalcLots(SizingRequest)` → broker-valid lots or `0.0` (abort). Sizer snaps to broker step/min/max but does NOT apply user catastrophic caps (the guard does).
- **F-RISK-2** `CRiskSizer` (the single concrete sizer) selects its calculation by `InpSizingMode` (`ENUM_SIZING_MODE`).
  - **v1 IMPLEMENTED (futures only):**
    - `SIZING_RISK_PERCENT` (default) — % equity at SL distance, futures-specific formula using `CSymbolInfo.TickValue()/TickSize()` to convert SL distance into BRL.
    - `SIZING_FIXED_LOT` — returns `InpFixedLot`, for backtest A/B and known-quantity strategies.
  - **v1 ENUM PLACEHOLDERS (declared, return `0.0` with WARN "sizing mode not implemented in v1", v2 deliverables):**
    - `SIZING_FIXED_CASH` and `SIZING_PCT_EQUITY` — v2 equity-sizing modes; formulas and scope defined in G-5.
  Each implemented branch returns `0.0` on its own anomaly (CP-9); the broker-snap and clamp are a single post-branch step. The optimizer can sweep `InpSizingMode` as an enum (placeholders harmlessly reject any pass that selects them). Future modes (v2 `SIZING_ADAPTIVE` for drawdown-scaled sizing) add an enum value, not a class.
- **F-RISK-3** `CKillSwitch`: daily P&L %, open lots, trades/day, panic flag. `IsTripped()` → refuse entries; close-all on loss/panic breaches. **v1 defaults are permissive (effectively opt-in):** the mechanism is present and ready, but every threshold input ships with a value that disables the trip until the operator chooses a real limit (see F-RISK-4 defaults). This honors the safety-mechanism-must-exist principle while making the kill-switch non-mandatory in practice.
- **F-RISK-4** Per-EA limits and their **v1 default values (permissive — opt-in)**: `InpDailyLossPct` (default 0 = disabled; positive value enables daily-loss trip), `InpMaxOpenLots` (default 0 = unlimited; positive value caps cumulative open lots), `InpMaxTradesPerDay` (default 0 = unlimited; positive value caps daily trade count), `InpPanicStop` (default false = inactive; flipping to true at runtime triggers CP-6 close-all). With all defaults at their ship values the kill-switch never trips — the operator opts in by setting any threshold to a non-zero limit. This gives v1 a real safety mechanism without imposing risk thresholds the operator hasn't chosen.

### Execution
- **F-EXEC-1** `ITradePort` interface: **submission only** — `Submit(TradeIntent)→GuardResult`. Production impl `CGuardedTrade`; test impl `MockTradePort`. Position queries are NOT on this seam (see F-EXEC-3) so execution and position-state responsibilities stay separate and mocks stay narrow.
- **F-EXEC-2** The `GuardResult` returned by `ITradePort.Submit` includes the `OrderCheck` outcome (retcode + projected `MqlTradeCheckResult` fields) so the coordinator can log it without a second call.
- **F-EXEC-3** `IPositionView` interface: read-only position queries (`HasMyPosition`, `Side`, `TotalLots`, `NetAvgPrice`, `PositionCount`, `TicketAt`). Production impl `CPositionContext`; test impl `MockPositionView`. The coordinator depends on `ITradePort` and `IPositionView` as two narrow seams, allowing tests to vary position state independently of submission. Mock implementation grows by demand: the v1 `MockPositionView` only implements the methods the v1 coordinator tests actually exercise; unused methods stub-return defaults until a test needs them.
- **F-EXEC-4** `CGuardedTrade` composes a private vendored `CTrade`. `Submit()` stages (each logged): (1) symbolic validation; (2) catastrophic caps — CP-1 per `InpAboveMaxAction` (default `SKIP_TRADE`, optional `CLAMP_DOWN`); CP-2 per `InpBelowMinAction` (default `SKIP_TRADE`, optional `CLAMP_UP`); (3) environmental gates (kill-switch, spread, session, market open); (4) `OrderCheck` pre-flight — broker formal validation, trading-disabled detection (terminal AND program level, → CP-17), and cumulative-account-state margin/level projection (a non-fatal advisory layer: its generic retcode does not replace our own diagnostics, but a hard trading-disabled or insufficient-cumulative-margin verdict rejects the order); (5) explicit `OrderCalcMargin ≤ MARGIN_FREE×safety` for this order in isolation (authoritative for opposite-direction ops, where `OrderCheck`'s margin is only approximate); (6) audit record — on SUCCESS, include only `MqlTradeCheckResult.margin_level` (the most diagnostic single field for "how close to the edge"); on REJECTION, include the full projection (balance/equity/margin/margin_free/margin_level) since that's where forensic value lives; full or slim, the record is paired with the LogIntent line. Counters only in optimization unless `InpAuditInOptimization`; (7) filling-mode-aware execution; (8) retcode interpretation; (9) state-machine/reconciliation update.
- **F-EXEC-5** `GuardResult{outcome, ticket, reason, lots_submitted}`.
- **F-EXEC-6** `FillingPolicy.Select(symbol, order_type)` validates the order kind, symbol execution mode, and broker-supported `SYMBOL_FILLING_MODE` flags before choosing a filling type. Market/deal orders prefer FOK, then IOC, only when the symbol allows them; RETURN is used only where MQL5 permits it for that execution mode/order kind. Pending orders use the MQL5-required pending-order filling behavior. If no valid filling type exists, reject the trade with ERROR rather than blindly falling back to RETURN. The selected policy is logged INFO.
- **F-EXEC-7** `SpreadGuard` rejects entries when spread > `InpMaxSpread` (0 = disabled).
- **F-EXEC-8** Retryable retcode handling. `CGuardedTrade.Submit` classifies the returned retcode in three buckets:
  - **Terminal failure** (reject + return) — `TRADE_RETCODE_REJECT (10006)`, `TRADE_RETCODE_INVALID* (10013-10016, 10022)`, `TRADE_RETCODE_NO_MONEY (10019)`, `TRADE_RETCODE_MARKET_CLOSED (10018)`, `TRADE_RETCODE_TRADE_DISABLED (10017)` (→ CP-17), `TRADE_RETCODE_LIMIT_* (10033-10034, 10040)`, `TRADE_RETCODE_LONG/SHORT/CLOSE_ONLY (10042-10044)`, `TRADE_RETCODE_FIFO_CLOSE (10045)`, `TRADE_RETCODE_HEDGE_PROHIBITED (10046)`, `TRADE_RETCODE_SERVER/CLIENT_DISABLES_AT (10026-10027)`.
  - **Retryable — refresh price/quote and retry immediately** (no sleep, up to `InpMaxRetries`, default 3) — `TRADE_RETCODE_REQUOTE (10004)`, `TRADE_RETCODE_PRICE_CHANGED (10020)`, `TRADE_RETCODE_PRICE_OFF (10021)`.
  - **Retryable — brief delay then retry** (`Sleep(InpRetryDelayMs)`, default 250 ms, up to `InpMaxRetries`) — `TRADE_RETCODE_CONNECTION (10031)`, `TRADE_RETCODE_TIMEOUT (10012)`, `TRADE_RETCODE_FROZEN (10029)`, `TRADE_RETCODE_LOCKED (10028)`, `TRADE_RETCODE_TOO_MANY_REQUESTS (10024)`. The `Sleep()` call is gated to `OptContext.IsLive() || (IsTesting() && !IsOptimizing())`; in optimization passes the delay is skipped (these retcodes do not occur in the tester anyway, and `Sleep` in optimization is wasted CPU even where it doesn't error).
  Additional terminal/successful codes (verified against the official enum):
  - `TRADE_RETCODE_DONE (10009)` — success.
  - `TRADE_RETCODE_PLACED (10008)` — pending → state machine `PENDING_ENTRY`, await `DEAL_ADD` (F-POS-10).
  - `TRADE_RETCODE_DONE_PARTIAL (10010)` — only part filled → reconcile canonical state (actual filled volume from the deal), log WARN; treat the position as the actually-filled volume, do NOT re-submit the remainder in v1.
  - `TRADE_RETCODE_CANCEL (10007)` — canceled; classify by ownership flag per F-POS-13 (broker-origin → FLAT; framework-origin → PENDING_CANCEL).
  - `TRADE_RETCODE_ORDER_CHANGED (10023)`, `NO_CHANGES (10025)` — modify/no-op outcomes on `ModifySL`/`ModifyTP`; log INFO, no state change.
  - `TRADE_RETCODE_INVALID_FILL` , `INVALID_ORDER`, `POSITION_CLOSED`, `ONLY_REAL (10032)` (live-only operation) — terminal failures → reject + ERROR.
  - **MANDATORY FAILSAFE for any unlisted/unknown retcode:** reconcile canonical state first (`PositionSelect`/`HistoryDealGet*` per F-POS-14/15 — did a position actually open?), then reject + log ERROR; if canonical state is ambiguous (cannot determine whether a position exists) → `HALT` + kill-switch rather than guessing `FLAT`. Never silently treat an unrecognized code as success or as a safe re-arm.
  After exhausting retries → reject + WARN; state machine returns to `FLAT` (per CP-18). Every retry attempt is logged with retcode and attempt number. All retcode constants are sourced from `https://www.mql5.com/en/docs/constants/errorswarnings/enum_trade_return_codes`.

### Position
- **F-POS-1** `IAccountModeAdapter`; v1 executable adapter is `CHedgingAdapter` only. `CNettingAdapter` / exchange-netting ownership logic is deferred v2+ design scope. The adapter boundary remains so strategy code is mode-agnostic and v2 can add netting/exchange without changing strategy helper calls.
- **F-POS-2** Interface: queries, operations, capabilities (`SupportsMultiplePositions/AllowsAddVolume`).
- **F-POS-3** `CPositionContext` selects the active adapter at init: `RETAIL_HEDGING → CHedgingAdapter`; `RETAIL_NETTING` or `EXCHANGE → INIT_FAILED` with an explicit deferred-v2 account-mode error. The raw `ACCOUNT_MARGIN_MODE` is logged INFO and exposed via `CAccountContext.MarginMode()` for diagnostics. No netting/exchange trade path is invoked in v1.
- **F-POS-4** `CHedgingAdapter.CloseLots` = iterate this EA's magic+symbol tickets via `PositionClosePartial` or full ticket close as appropriate. Netting/exchange partial-close mechanics are deferred to v2+.
- **F-POS-5** `CHedgingAdapter` operations iterate "my" tickets (magic+symbol).
- **F-POS-6** `TrailSL` tightens only; honors stop/freeze; reverses ignored (DEBUG). In v1 hedging mode it modifies this EA's ticket SL. Netting linked-pending-exit trailing is deferred to v2+.
- **F-POS-7** `CTradeTxRouter` demultiplexes `OnTradeTransaction`, filters by magic + symbol, fires hooks and drives the state machine for v1 hedging ticket ownership. Because v1 attaches one strategy instance to one chart symbol, the symbol filter is expected to match that strategy's configured symbol; multiple hedging strategies may still run on the same symbol as long as their magic numbers differ. v4 multi-symbol work will need to revisit this. **Ownership and wiring:** `CTradeTxRouter` is a member of `CPositionContext` (not a standalone top-level object). `CStrategyBase` creates and owns the single `CPositionStateMachine` instance; it passes a reference to `CPositionContext` (so `CTradeTxRouter` can fire transitions on it) and a separate reference to `CTradeCoordinator` (for the reconciliation pump). No other object creates a state machine — both paths receive shared references, not ownership. `CTradeTxRouter` owns the `OnTradeTransaction`-driven path; `CTradeCoordinator.Update()` owns the reconciliation/fill-timeout path — both paths drive one machine with no duplication of state. **OnTradeTransaction dispatch chain:** The MT5 entry-point shim in the strategy's `.mq5` file calls `strategy_instance.OnTradeTransactionEvent(trans, request, result)` → `CStrategyBase::OnTradeTransactionEvent` delegates to `CPositionContext.OnTradeTransaction(...)` → `CPositionContext` routes to its member `CTradeTxRouter::Route(...)` → `CTradeTxRouter` filters by magic + symbol and fires state machine transitions. `CTradeCoordinator` is NOT on this path. `OnTradeTransaction` is framework-internal — strategy authors MUST NOT add processing for it in their derived class or in the MT5 shim beyond the framework delegation call. See also F-COORD-1.
- **F-POS-8** Externally-closed detection → `OnPositionClosed(reason="External")`, WARN. This applies when a hedging ticket this EA tracks is closed by something other than the framework's own actions. The string `"External"` passed to the hook corresponds canonically to `ENUM_CLOSE_REASON::CR_EXTERNAL` — same event, same audit-log close-reason. The hook receives the string form for convenience; the CSV log uses the enum form.
- **F-POS-9** v1 Hedging operation matrix. CORE PRINCIPLE: each EA's position management is fully independent from other EAs through magic+symbol+ticket ownership. Netting/exchange behavior is deferred to v2+.

  | Operation | v1 Hedging |
  |---|---|
  | Open initial position | `OrderSend` BUY/SELL; broker creates this EA's magic+symbol ticket |
  | Modify SL/TP | `PositionModify(ticket)` per "my" ticket |
  | Trail SL | Tightens broker SL per "my" ticket |
  | Close all "my" | Iterate "my" tickets, close each |
  | Partial close | `PositionClosePartial(ticket, lots)` per ticket until cumulative target reached |
  | Add to position (v2) | New `OrderSend`; broker creates a new ticket |
  | Opposing strategy signal | Native independent tickets may coexist when strategies use distinct magic numbers |
  | Reverse position | Close all "my" tickets, then open opposite |

  Hedging "my" filtering is by magic + symbol + ticket. Netting/exchange ownership by virtual gross-position ledger is deferred to v2+ and MUST NOT be release-gated as v1 behavior.
- **F-POS-10** `CPositionStateMachine`: states `FLAT → PENDING_ENTRY → ACTIVE → PENDING_EXIT → FLAT`, plus transient `PENDING_CANCEL` (framework-initiated cancel awaiting confirmation, per F-POS-13) and terminal `HALT`. Created and owned by `CStrategyBase`; never constructed by adapters, coordinator, or router — both `CTradeTxRouter` and `CTradeCoordinator` operate on a shared reference received at construction (see P-3, F-POS-7). Transitions driven by `CTradeTxRouter` events. **Absorbs async fill reconciliation**: `PENDING_ENTRY` carries a timeout (`InpFillTimeoutSecs`, default 5 s); on timeout, cancel still-pending pending order if possible, else trip kill-switch + ERROR. Gates entries to `FLAT` only (prevents double-entry race). Designed to extend for v2 pyramiding (`ACTIVE` self-loop via `PENDING_ADD`) and v2 netting virtual-position lifecycle. Additional v1 transition: **`ACTIVE → HALT`** — triggered when a framework emergency action leaves the hedging ticket in an unresolvable or unprotected state; auto-clears via reconcile-safe recovery (F-POS-20), otherwise persists until restart.
- **F-POS-11** Strategy-specific state (pyramid units, cycle/skip state) is NOT modeled by the state machine; it is the strategy's own, persisted via `CStateStore`.
- **F-POS-12** `CTradeTxRouter` MUST classify terminal order/request outcomes in `OnTradeTransaction`: rejection retcodes (`TRADE_RETCODE_REJECT`, `TRADE_RETCODE_INVALID*`, `TRADE_RETCODE_NO_MONEY`, `TRADE_RETCODE_MARKET_CLOSED`) and order-state transitions (`ORDER_STATE_REJECTED`, `ORDER_STATE_CANCELED`). Because `ORDER_STATE_CANCELED` is overloaded — it can be a broker/exchange rejection OR the framework's own timeout-triggered cancel — the state machine MUST distinguish the two via a framework-owned ownership flag ("did we submit a cancel for this order?").
- **F-POS-13** Cancel/rejection handling by origin: **(a) broker/exchange rejection arriving before any framework cancel** (ownership flag false) → no position exists → `PENDING_ENTRY → FLAT` immediately + ERROR, re-arm. **(b) Framework-initiated cancel after the fill timeout** (ownership flag true) → cancel is itself async → enter transient `PENDING_CANCEL` and await confirmation; confirmed cancel → `FLAT`; **(c) cancel fails or never confirms** (the order may have filled in the race) → `HALT` + kill-switch, because position state is unknown. The machine MUST NOT treat every `ORDER_STATE_CANCELED` as a safe re-arm — only origin (a) and confirmed (b) are safe. The 5 s timeout (CP-13) is a backstop for genuine silence, NOT the primary path for explicit rejections (path a).
- **F-POS-14** State-machine event tolerance. The state machine MUST treat `OnTradeTransaction` events as *hints* and rely on canonical observable state (`PositionSelect`, `HistoryDealGet*`, order-state queries) as the source of truth, because tester vs live behavior diverges:
  - The Strategy Tester is *more* synchronous than live — `OrderSend` bookkeeping often appears settled before any transaction event fires; live has measurable lag.
  - Some transaction types (`TRADE_TRANSACTION_ORDER_ADD` and others) are silently skipped in tester per documented community findings.
  - Volume fields populated in `MqlTradeTransaction` differ between tester (`qty` populated on `ORDER_DELETE/FILLED`) and live demo (zero) — never depend on struct field values for accounting; read from `PositionGetDouble`/`HistoryDealGetDouble` instead.
  - Pending-order-to-history transition has a visibility gap in live (briefly findable in neither active nor history); in tester the transition is immediate.
  The state machine MUST therefore: (a) advance on observable state changes regardless of which events fired; (b) tolerate skipped or out-of-order events without HALTing; (c) read accounting data from canonical sources only.
- **F-POS-15** Authoritative state-tracking surface (v1 hedging; v2 netting-ready boundary). Per-EA position identity and state MUST be derived from broker-backed surfaces that carry this EA's magic plus this EA's GV-backed strategy state; never from order comments, standalone internal flags, or `PositionSelect(symbol)` alone:
  - **Magic number** (`DEAL_MAGIC` / `ORDER_MAGIC`, and `POSITION_MAGIC` only as diagnostic on netting because the aggregate position may show the last modifying magic) — the primary "who caused this deal/order" key; survives restarts, set by the EA, cannot be overwritten by the broker. `(account, symbol, InpMagicNumber)` MUST be unique per TradeSpine strategy instance in v1. Duplicate detection is terminal-local only: on init, `CKeyBuilder` derives a hashed duplicate-marker GV from `account|symbol|magic|duplicate_marker|owner`. The marker GV stores `0` (free) or `1` (claimed); side GVs store owner diagnostics including `owner_chart_id` and the marker heartbeat timestamp. The EA creates the marker with value `0` if missing, claims it with `GlobalVariableSetOnCondition()` from `0 → 1`, writes owner diagnostics, and starts a fixed low-frequency heartbeat. The heartbeat GV is updated every 30 seconds while the EA is alive; a marker is stale only when the last heartbeat is older than 90 seconds (three missed beats). If the marker is already claimed and the heartbeat is fresh, startup fails (`INIT_FAILED` + ERROR). If the marker is claimed but heartbeat-stale, the new instance logs WARN, reclaims the marker by CAS/overwrite of the marker + side GVs, and continues init. `owner_chart_id` is diagnostic only; chart liveness alone is never authoritative because a chart can remain open after the EA was removed or changed. The platform itself does not enforce this uniqueness, and another terminal/VPS on the same login is operator-managed in v1. `CKeyBuilder` generates the heartbeat GV name from canonical key `account|symbol|magic|duplicate_marker|heartbeat_ts`; the GV stores the timestamp of the last successful heartbeat write as a double (Unix seconds). On clean `OnDeinit` (non-crash reason: `REASON_REMOVE`, `REASON_RECOMPILE`, `REASON_CHARTCHANGE`, `REASON_CHARTCLOSE`, `REASON_PARAMETERS`, `REASON_ACCOUNT`) the framework clears the marker GV to `0` and clears the heartbeat GV to `0`, preventing stale GV accumulation from clean sessions. The heartbeat fires only in live and visual-tester modes; it is suppressed when `OptContext::IsOptimizing()` is true or `IsTesting() && !IsVisualMode()` is true (non-visual tester) — the duplicate-marker mechanism is unnecessary when the tester runs a single EA per pass, and timer writes add unwanted I/O in both non-live modes.
  - **Deal/order history** (`HistorySelect` + `HistoryDealGet*` / `HistoryOrderGet*`) — immutable audit trail for what this EA actually submitted and what the broker executed. v1 reconciliation filters by this EA's magic, symbol, and hedging ticket/state evidence. v2 netting will additionally use persisted links to virtual positions and pending exits.
  - **`POSITION_IDENTIFIER`** — deferred v2 netting diagnostic/linkage only. v1 hedging ownership uses ticket/magic/symbol evidence.
  The state machine and strategy-specific state are CACHES of this strategy-scoped evidence, reconciled on every `OnTradeTransaction` event and restart. In v1 hedging, broker tickets represent strategy ownership directly. In v2 netting/exchange, the virtual ledger becomes the decision source because the broker exposes only one aggregate symbol position.
- **F-POS-16** Netting virtual gross-position ledger (**deferred v2+ design note, not v1 executable scope**). Multiple TradeSpine EAs on the same symbol in netting/exchange mode require a per-EA virtual gross-position ledger, broker-history reconciliation, and strategy-owned pending exits. v1 MUST NOT instantiate or depend on this ledger for live trading; netting/exchange account mode fails init before any trade path is active.
- **F-POS-17** Short-lived symbol execution mutex (**deferred v2+ design note, not v1 executable scope**). Netting/exchange support will need a terminal-wide hashed GV lock around virtual-ledger and pending-exit critical sections. v1 does not create, acquire, or require this mutex because v1 executable scope is hedging-only. Any `InpExecLockStaleSecs` input is deferred unless retained only as a documented v2 placeholder.
- **F-POS-18** Outside/manual orders are explicitly outside framework scope and MUST NOT perturb per-EA strategy state. Manual orders means user, broker, script, or non-TradeSpine activity that does not carry this EA's magic. The framework ignores outside activity for strategy accounting, does NOT HALT on the basis of unrelated manual orders, and does NOT write unrelated manual/user orders to this EA's audit or trade CSV. External-intervention handling remains strategy-scoped: if the user cancels, closes, or modifies this EA's own hedging ticket, that is in scope and may be logged as `CR_EXTERNAL`.
- **F-POS-19** Netting per-strategy pending SL/TP exits and framework-managed OCO (**deferred v2+ design note, not v1 executable scope**). v1 hedging uses broker-native ticket SL/TP and does not create virtual-position pending exits for netting/exchange accounts.
- **F-POS-20** `HALT` semantics. `HALT` is a persisted per-strategy safety state. While halted, the strategy performs no new entries, no strategy-driven exits, and no trailing/modify actions. Emergency panic/kill-switch actions remain allowed only when ownership is known, because they are safety actions. Entering HALT writes the halt reason and last known state to GV, logs ERROR through `Logger`, prints to the terminal Journal through the logger path, and routes the same payload through an alert sink. In live/visual mode the sink raises a terminal `Alert`; in tester/non-visual/optimization contexts it records the payload through a mockable/log-only sink because UI alerts are not reliable test artifacts. The payload contains: halt reason, symbol, magic, hedging ticket id when known, last known lifecycle state, and recommended operator action. HALT survives restart. HALT clearing is automated and reconcile-safe only: on init and explicit reconciliation windows, the framework attempts recovery and clears HALT only when current GV/history/order evidence proves a safe state. Auto-clear is allowed when reconciliation proves the strategy is flat with no live strategy-owned tickets/orders, or when strategy-owned hedging ticket state is repaired safely. HALT remains active when active ownership or broker/history evidence is ambiguous. Every auto-clear logs WARN with previous halt reason, evidence used, and resulting lifecycle state. There is no `InpClearHalt` boolean in v1; operator action is still required to resolve ambiguous market state, but safe recovery itself is framework-owned. Virtual position ids, linked pending exits, OCO repair, and signed netting volume diagnostics are v2+ scope.
- **F-POS-21** Strategy-owned external intervention defaults. Unrelated manual/non-TradeSpine orders remain ignored and never enter this EA's logs. In v1 hedging mode, if this EA's broker-side ticket SL/TP is canceled or manually modified, the framework replaces it with the strategy-computed value on the next reconciliation when topology is valid and logs `CR_EXTERNAL_REPAIRED`; if topology is not valid, it enters `HALT`. If this EA's hedging ticket is manually closed, the framework accepts broker reality, closes/reduces this EA's state, and logs `CR_EXTERNAL`. Netting pending-exit/OCO intervention rules are deferred with netting/exchange mode to v2+.
- **F-POS-22** v1 recovery matrix (low-I/O).

  | Condition | Action |
  |---|---|
  | GV present + hedging ticket state reconstructable | Recreate in-memory state; repair ticket SL/TP when topology is valid; continue. |
  | GV present + broker/history contradicts hedging ticket state | Repair if one unambiguous broker event explains the drift; otherwise HALT. |
  | GV missing + no active magic-owned orders + history proves flat/closed | Continue as flat. |
  | GV missing + active magic-owned orders or ambiguous active ownership | HALT. |
  | Duplicate marker heartbeat > 90 s | Reclaim with WARN; continue init. Fresh heartbeat → block init with `INIT_FAILED` + ERROR. `owner_chart_id` is diagnostic only, never liveness authority. |

### Coordination
- **F-COORD-1** `CTradeCoordinator` uses (by interface) the sizer (`IPositionSizer`), stop policy (`IStopPolicy`), submission seam (`ITradePort`), position-view seam (`IPositionView`), and `TradeLogger`; it drives the state machine. Exposes `ProcessSignal(Signal)→GuardResult` and `Update()`. **`Update()` — cheap tick pump** called by `CStrategyBase` on every tick after strategy hooks complete; every-tick responsibilities are limited to local timeout bookkeeping and advancing already-known state, with no order scan, no `HistorySelect`, and no GV writes. Any reconciliation requiring active-order/history reads runs only during init, `OnTradeTransaction`, explicit timer maintenance, or strategy-owned external-intervention detection. v2 netting OCO sibling detection is outside v1 execution scope. `Update()` does NOT automatically trail stops — trailing is strategy-owned in `OnManagePosition`. **State-machine sharing:** `CTradeCoordinator` holds a reference to the `CPositionStateMachine` (reference received from `CStrategyBase` at construction — the coordinator does NOT own or create the machine); `CTradeTxRouter` (a member of `CPositionContext`, F-POS-7) fires transitions on the same instance from the `OnTradeTransaction` path. Both paths are distinct entry points into one machine — there is no duplicate machine and no hidden coupling.
- **F-COORD-2** `CStrategyBase` composes one `CTradeCoordinator`; all base-class entry helpers (`OpenLong`/`OpenShort`) and close helpers (`CloseAll`/`CloseLots`/`ClosePosition`) delegate to it.
- **F-COORD-3** The coordinator is unit-testable: constructing it with `MockSizer`/`MockStopPolicy`/`MockTradePort`/`MockPositionView` allows asserting pipeline decisions without a broker.
- **F-COORD-4** Indicator-readiness gate. The coordinator refuses entries while any registered indicator reports `IsReady(min_bars) == false` (handles created but history still loading, e.g. on EA attach or terminal restart). Each refusal logs WARN once per indicator until readiness is reached. The strategy registers its indicators by calling `RegisterIndicator(IIndicator*)` on `CStrategyBase` from within `OnStrategyInit`; `CStrategyBase` forwards the list to the coordinator. An indicator the strategy reads directly without calling `RegisterIndicator` bypasses the gate — the strategy then owns the readiness check for that indicator.

### Persistence
- **F-PERS-1** `CStateStore` is GV-backed in v1. It stores double/bool/datetime/small-int, panic flags, HALT state, local duplicate-magic markers, and hedging ticket-state fields. Virtual-ledger fields and execution mutexes are deferred to v2+ with netting/exchange support. All GV names are produced by `CKeyBuilder` (`TS_<16hex_hash>_<short_field>`); raw identity is logged for humans but never embedded in GV names. `ulong` ticket/deal/order identifiers MUST be stored losslessly as two numeric GV fields (`*_hi` and `*_lo`) rather than as a single double, because MQL5 tickets are wider than the integer precision guaranteed by `double`. No custom file snapshot layer ships in v1.
- **F-PERS-2** Namespace identity is canonical string `account|symbol|magic|scope|field`, converted to GV names by `CKeyBuilder`. On init, state is rebuilt from this EA's hashed GV namespace plus active/history broker objects carrying this EA's magic. Marker/state namespaces store a diagnostic identity hash (→ F-CORE-6); mismatch means key collision or corruption and causes `INIT_FAILED` before live trading, or HALT if detected live. If GV state is missing but magic-filtered broker history is sufficient to reconstruct a closed/flat state, the EA may continue. If active hedging ticket ownership cannot be reconstructed safely, this strategy enters `HALT` with ERROR rather than guessing. Active virtual ledger and linked pending-exit reconstruction rules are v2+ scope.
- **F-PERS-3** Optimization: `Clear()` at init; persistent GV writes that could contaminate parallel passes are disabled or namespaced per optimization pass. The duplicate-marker heartbeat is also suppressed in optimization and non-visual tester (see F-POS-15). **Isolation mechanism:** MT5 runs each optimization pass with a fresh EA `OnInit`, so `Clear()` at init is sufficient — there is no shared in-process GV state carried between passes. **Edge case (out of v1 supported scope):** an operator running a live/demo EA instance with the same `(account, symbol, InpMagicNumber)` in the same terminal concurrently with an optimization run risks GV key collisions; the supported v1 practice is to use distinct magic numbers or separate terminals for live and optimization sessions.
- **F-PERS-4** v1 avoids explicit custom file I/O for live-market performance. `CStateStore` writes only on meaningful state changes, not per tick. `GlobalVariablesFlush()` is not called after every write by default; terminal-managed GV persistence plus magic-filtered broker history is the v1 low-I/O recovery model. If a hard crash loses GV state and broker history/active orders are insufficient to prove hedging ticket ownership safely, the correct v1 behavior is `HALT`, not reconstruction by guesswork. A v2 durability mode may force GV flushes on critical virtual-ledger/OCO writes or add a file snapshot layer if v1 evidence shows the extra I/O is worth the recovery strength.

### Indicators
- **F-IND-1** `IIndicator`: `Init/IsInitialized/Handle/Name`.
- **F-IND-2** `CIndicatorBase`: handle management, `CopyBufferSafe`, `ValueAt`, `IsReady`. **Destructor calls `IndicatorRelease`.**
- **F-IND-3** One file per indicator under `Native/` or `Custom/`.
- **F-IND-4** v1 `Native/`: `IndATR`, `IndMA` — the only generic `Native/` wrappers v1 ships. RSI, Bands, Stochastic, MACD, ADX, CCI are NOT shipped in v1 (no placeholders, no stubs); they will be added in v2 only when a strategy needs them. Each shipped strategy artifact implements or declares only the indicators/pattern detectors it needs: `DonchianBreakout` uses `IndDonchian` (F-IND-5, `Custom/`) and `IndATR` (`Native/`) for ATR-based trailing; `MovingAverageCross` uses `IndMA` (`Native/`); `1minscalpv3_hedging.mq5` and `BullishBearish Engulfing all v7 hedging.mq5` are additional hedging ports and must not force broad unused wrapper stubs beyond their actual port requirements. `IndSupertrend` (F-IND-5, `Custom/`) is shipped for use by future strategies. No unused wrappers are stubbed in v1, and speculative breadth is untested code in a real-money system.
- **F-IND-5** v1 `Custom/`: Donchian, Supertrend.
- **F-IND-6** Optional result caching keyed by (handle, buffer, bar-time); off by default.

### Strategy base
- **F-STRAT-1** `CStrategyBase` non-virtual lifecycle + virtual hooks. The framework's `OnInit` calls `EventSetTimer(max(GetTimerSeconds(), 30))` unconditionally — guaranteeing a maintenance tick at least every 30 s regardless of whether the strategy uses a timer. On every timer tick the framework dispatches internal maintenance (duplicate-marker heartbeat, reconciliation windows) before forwarding to `OnTimerEvent`.
- **F-STRAT-2** Hooks (active in v1): `OnStrategyInit`(→bool), `OnStrategyDeinit`, `OnNewBar`(→void — call `OpenLong`/`OpenShort` for bar-cadence entries), `OnTickEvent`(→void — call entry helpers here for tick-cadence entries: volatility spikes, spread capture, news), `OnManagePosition`(→void — called by the framework every tick during phase 4 while this EA's strategy position state is ACTIVE; strategy owns what it calls inside: trailing, partial close, condition-based exit, etc.), `OnTimerEvent`, `OnPositionOpened`, `OnPositionClosed`, `OnOrderPlaced`, `OnOrderFilled`, `OnOrderRejected`, `OnEntryAttemptBlocked`(reason), `OnSessionStart`, `OnSessionEnd`, `OnChartEventCustom`. **Framework-internal event (NOT a hook):** `OnTradeTransaction` is dispatched via the framework-internal chain `CStrategyBase → CPositionContext → CTradeTxRouter` (see F-POS-7) — strategy authors MUST NOT add processing for it in their derived class. v1 PLACEHOLDERS (declared with no-op defaults, `@v2_placeholder`, framework does not invoke them in v1): `OnBookEventCustom`, `OnTesterPass`, `OnTesterInitCustom`, `OnTesterDeinitCustom`. `SubscribeToBook` declarative override (F-STRAT-3) is also placeholder — returns false in v1, ignored if overridden true (framework does not subscribe to depth-of-market).
- **F-STRAT-3** Declarative overrides: `GetSizer` (default `CRiskSizer`), `GetStopPolicy` (default NULL — required if SL used and Signal SL unset), `GetSignalTimeframe` (no default), `GetRiskPercent` (default `InpRiskPercent`), `GetTimerSeconds` (0; the strategy's desired timer interval — the framework enforces a minimum of 30 s for internal maintenance via `EventSetTimer(max(GetTimerSeconds(), 30))`; see F-STRAT-1). **Authoring note:** strategy authors requiring sub-30-second periodic logic MUST use `OnTickEvent` instead — the 30-second floor is unconditional. `OnTimerEvent` is maintenance-cadence only, not trade-cadence. This constraint is documented in `Docs/AUTHORING.md`. `SubscribeToBook` (false).
- **F-STRAT-4** Entry helpers (route through coordinator → ProcessSignal):
  - `OpenLong(string comment, double sl_price = 0, double tp_price = 0, string metadata = "")`
  - `OpenShort(string comment, double sl_price = 0, double tp_price = 0, string metadata = "")`
  - Defaults: risk is always `GetRiskPercent()` (no per-call override — sizing is the sizer's authority); `sl_price=0`/`tp_price=0` → stop policy computes per §7d step 4 (layered); market entry only in v1.
  Management helpers (operate on existing positions; route through the coordinator's CLOSE branch for unified audit, but NOT through the entry sizing/stop sub-pipeline):
  - `CloseAll(string reason)`, `CloseLots(double lots, string reason)`, `ClosePosition(ulong ticket, string reason)`
  - `ModifySL(double new_sl)`, `ModifyTP(double new_tp)`, `TrailSL(double new_sl)` (tightens only)
  - `CancelPending(ulong ticket)`, `CancelAllPending()`
  - Query: `CurrentPrice()`, `MainTicket()`, `HasMyPosition()`, `PositionSide()`, `TotalLots()`, `NetAvgPrice()`
  Setup (call from `OnStrategyInit`):
  - `RegisterIndicator(IIndicator* ind)` — registers an indicator with the coordinator's readiness gate (F-COORD-4); must be called for each indicator whose `IsReady()` state should block entries.
  No direct `CTrade` access from strategies.
- **F-STRAT-5** `CNewBarDetector` compares `iTime(symbol, GetSignalTimeframe(), 0)` against stored last-bar time (NOT tick counting), to survive connection-drop gaps.
- **F-STRAT-6** `CommonInputs.mqh` declares the universal inputs every strategy gets via one `#include`. Canonical list (v1 active):
  - **Identity:** `InpMagicNumber`, `InpDeviation`
  - **Lot caps (catastrophic guard):** `InpMinLotsPerOrder` (0 = symbol min), `InpMaxLotsPerOrder` (0 = symbol max), `InpAboveMaxAction` (SKIP_TRADE | CLAMP_DOWN), `InpBelowMinAction` (SKIP_TRADE | CLAMP_UP)
  - **Daily/runtime kill-switch:** `InpDailyLossPct`, `InpMaxOpenLots` (enforced by kill-switch, not the cap layer), `InpMaxTradesPerDay`, `InpPanicStop`
  - **Execution:** `InpMaxSpread` (0 = disabled), `InpFillTimeoutSecs` (default 5), `InpMaxRetries` (default 3), `InpRetryDelayMs` (default 250), `InpAuditInOptimization` (default false). `InpExecLockStaleSecs` is a v2 placeholder only if retained in docs/code; v1 hedging execution does not use an execution mutex.
  - **Session:** `InpSessionStart`, `InpSessionEnd`, `InpDayTradeMode`, `InpCloseMinsBefore` (all in broker/server time — `TimeCurrent()` is the authoritative clock; no offset input in v1)
  - **Sizing:** `InpSizingMode` (ENUM_SIZING_MODE, default SIZING_RISK_PERCENT), `InpRiskPercent` (default 1.0), `InpFixedLot` (used when SIZING_FIXED_LOT)
  - **Symbol lifecycle:** no operator expiration-warning input in v1; contract-expiration warnings are fixed at one broker day before expiration.
  - **Visualization:** `InpEnableVisuals` (single compile-time default `true`; effective state computed at runtime as `InpEnableVisuals && !IsOptimizing() && (IsLive() || IsVisualMode())`. MQL5 input defaults must be compile-time constants — headless VPS operators set the input to `false` per chart.)
  - **Logging:** `InpEnableLogs`, `InpLogLevel`

  **Input groups (NF-7):** `CommonInputs.mqh` MUST define `input group` labels for every logical section above (e.g. `"Identity"`, `"Lot caps"`, `"Kill-switch"`, `"Execution"`, `"Session"`, `"Sizing"`, `"Symbol lifecycle"`, `"Visualization"`, `"Logging"`). The canonical group names and ordering are documented in `Docs/INPUTS_REFERENCE.md`. Omitting groups degrades the MT5 parameters panel and makes operator configuration error-prone.

  **Per-strategy input review:** the list above is the universal baseline included by every strategy via `CommonInputs.mqh`. Strategy authors SHOULD verify which inputs are actively consumed by their specific strategy and document intentionally unused inputs in the strategy file's header comment (e.g. `InpFixedLot` when only `SIZING_RISK_PERCENT` is used). Unused inputs are harmless but may confuse operators.

- **F-STRAT-7** Entry/management helpers refuse to execute before lifecycle phase 4 (ERROR + return 0/false).

### Stops (initial SL/TP)
- **F-STOP-1** `IStopPolicy.ComputeStops(Signal, entry)→StopLevels`; `Name()`. Computes the INITIAL stop, decoupled from the entry signal. Invoked only when the `Signal` leaves SL/TP unset. Selectable by enum input for optimization sweeps.
- **F-STOP-2** v1: `CStopATR` (ATR×mult), `CStopFixed` (fixed points), `CStopSwing` (structure: SL beyond most recent swing low/high within lookback, configurable strength + buffer; returns `sl_distance = 0` when no qualifying swing is found — failure sentinel per §7d struct comment).

### Trailing (ongoing stop)
- **F-TRAIL-1** `ITrailingStop.ProposeNewSL(ticket, current_price)→double` (0 = no change); `Name()`. `Configure(...)` concrete-only.
- **F-TRAIL-2** v1 (active): `CTrailATRMultiple`, `CTrailBreakeven`. v1 (placeholders, `@v2_placeholder`): `CTrailFixedDistance`, `CTrailStepped`. Two concrete trails are enough to prove the enum-sweep pattern; the others land when a strategy needs them.
- **F-TRAIL-3** Selection by enum input is first-class; strategy holds one member per type, selects active in `OnStrategyInit`; optimizer sweeps the enum. Strategy applies trailing in `OnManagePosition` via `TrailSL`. Framework does not auto-call trailing.
- **F-TRAIL-4** Multi-exit coexistence. A strategy position may simultaneously have initial SL/TP, a trailing stop, and an exit-signal close. In v1 hedging mode these map to broker-side ticket SL/TP and ticket close operations. Netting-mode strategy-owned pending exit orders are deferred to v2+ with F-POS-19. These are layers, not competitors: trailing moves/replaces this strategy's SL tighten-only; the exit signal closes regardless of SL/TP position; whichever triggers first wins. The one ordering rule: if a strategy runs a trailing policy AND calls `ModifySL` directly in the same tick, last-writer-wins for that strategy's own exit order only. Documented in `Docs/RECIPES.md`.

### Optional / Testing / Docs
- **F-OPT-1** `Visualization` provides helpers for drawing strategy-specific chart objects (horizontal lines, arrows, text labels, prefix-based cleanup). Master switch `InpEnableVisuals` (common input) allows full disable even in live — important for headless VPS deployments where no chart is observed.
- **F-OPT-2** Visualization performance gating (chart object operations are expensive; a naive every-tick redraw degrades performance even outside optimization): **(a)** fully disabled when `OptContext.IsOptimizing()`; **(b)** disabled in tester non-visual mode (no chart exists); **(c)** in tester-visual and live, redraw ONLY on meaningful change (new bar, new/closed position, SL relocation) — NEVER every tick; **(d)** reuse objects by name (`ObjectSetXxx`) instead of delete-and-recreate; **(e)** cap total object count with oldest-eviction.
- **F-OPT-3** Visualization MUST NOT block or materially slow the trading path: drawing happens AFTER trade logic in the tick cycle, never before; a drawing failure logs WARN and is swallowed (never propagates to abort a trade). The trading path's correctness and latency are independent of whether visualization is on.
- **F-TEST-1** `TradeSpine/Include/Testing/Assert.mqh`: `AssertTrue/False`, `AssertEqual`, `AssertLotEqual`, `AssertPriceEqual(tol)`, pass/fail counters, summary print. No external dependency.
- **F-TEST-2** `TradeSpine/Include/Testing/Mocks.mqh`: `MockSizer`, `MockStopPolicy`, `MockTradePort`, `MockPositionView`, `MockClock` for Tier-1 unit tests. **`MockClock` minimum interface:** `double Now()` (returns current mock time as Unix seconds) and `void Advance(double seconds)` (advances the mock clock by the given amount). Framework code that compares elapsed time for fill-timeout (F-POS-10) and retry-delay (F-EXEC-8) must accept a clock reference — production code defaults to `TimeLocal()`; tests inject `MockClock`. Required by AC-17 (fill-timeout transition) and AC-26 (retry-count/exhaustion).
- **F-TEST-3** Tier-1 unit tests (`Scripts/Tests/*.mq5`, run as scripts): SafeMath, sizers, stop policies, state-machine transitions, kill-switch, coordinator pipeline (with mocks). `RunAllTests.mq5` aggregates.
- **F-TEST-4** Tier-2 integration tests (Strategy Tester harness EA, single-EA only — the tester runs one EA per pass): `CGuardedTrade` order placement, async fill timing, hedging close behavior, filling-mode selection, and v1 deferred-mode initialization failure for `RETAIL_NETTING` / `EXCHANGE`.
- **F-TEST-5** Netting/exchange deferred-mode test — `Scripts/Tests/Test_AccountModeDeferred.mq5` verifies that `RETAIL_NETTING` and `EXCHANGE` account-mode selections produce an operator-facing deferred-v2 error and `INIT_FAILED` before live trading. No virtual-ledger, OCO, execution-mutex, or manual concurrent netting evidence is required for v1.
- **F-TEST-6** Manual-concurrency evidence pack is **deferred to v2+** together with executable netting/exchange account modes. v1 release evidence MUST NOT require live/demo concurrent netting proof.
- **F-DOC-1..7** README, ARCHITECTURE, AUTHORING, RECIPES (≥10), INPUTS_REFERENCE, TESTING (how to run Tier-1, Tier-1.5, and Tier-2), per-module docs, template README. English + B3 glossary. `Docs/AUTHORING.md` MUST cover: minimum timer interval constraint (30 s; sub-30-s logic must use `OnTickEvent`); `OnTradeTransaction` is framework-internal and not a strategy hook; and input group naming conventions per `Docs/INPUTS_REFERENCE.md`.
- **F-DOC-8** 100% Doxygen coverage (grep). **F-DOC-9** docs updated in same commit as API changes.

## 10. Non-Functional Requirements

| ID | Requirement |
|---|---|
| NF-1 | ≤10% tester overhead vs hand-written equivalent. |
| NF-2 | ≤2 MB per EA instance. |
| NF-3 | ≤50 µs `OnTick` overhead when idle. |
| NF-4 | 100% Doxygen coverage on public methods. |
| NF-5 | Compiles strict, no warnings, MetaEditor 4150+. |
| NF-6 | No raw `Print` in framework-authored production code (gated via Logger). **Excludes `MQL5/Experts/Main/TradeSpine/Include/StdLib/`** (vendored third-party source), `Include/Testing/`, and `Scripts/Tests/`, because test harnesses must print pass/fail summaries. Framework-authored production code must use Logger. |
| NF-7 | Conventions: `m_`/`g_`/`Inp`, `input group`. |
| NF-8 | Copyright header in every file. |
| NF-9 | Framework includes only the framework's own vendored `Include/StdLib/` (via quoted relative includes); never `<Trade/...>` or `<Expert/...>`. |
| NF-10 | 4 lifecycle transitions emit INFO logs. |
| NF-11 | Grep acceptance: strategy files contain no `<Trade/Trade.mqh>` and no raw `OrderSend(`. |
| NF-12 | Tier-1 unit tests pass (RunAllTests green) before any release tag. |
| NF-13 | `TradeSpine/Include/StdLib/VERSION.md` present and records source terminal build. |
| NF-14 | **Placeholder protocol.** Items marked `@v2_placeholder` (in source comments and PRD) are reserved interface surface — declared but not invoked/implemented. They exist to (a) freeze naming and signatures so v2 doesn't break v1 strategies, (b) document deferred scope visibly. Placeholders must compile, must not be wired into framework call paths, and must log "not implemented in v1" if invoked. Removed in v2 (when implemented) or v3 (if abandoned). |
| NF-15 | **Low-I/O performance budgets.** Idle tick: no GV writes, no `HistorySelect`, no chart redraw, no order scan, target ≤50 µs. Accepted entry: ≤12 GV writes before/after broker result, excluding ticket hi/lo fields. Accepted exit: ≤12 GV writes plus sibling cleanup fields. SL/TP trail update: ≤6 GV writes and one broker order modify/delete-create path. Duplicate-marker heartbeat may write one GV every 30 seconds per active EA on timer/maintenance cadence, never from the idle tick path; disabled in optimization and non-visual tester (`OptContext::IsOptimizing()` or `IsTesting() && !IsVisualMode()`). Reconciliation runs only on init, `OnTradeTransaction`, explicit timer maintenance, and strategy-owned external-intervention detection — never every tick. `HistorySelect` is forbidden in idle tick and allowed only during init/reconciliation windows. |
| NF-16 | **Canonical release record policy.** `CHANGELOG.md` is the sole canonical decision/release log. Every PRD `Document version` MUST have a same-version changelog section dated and summarized in `CHANGELOG.md`. A PRD version without a matching changelog entry fails release readiness. |

## 11. Catastrophic Protection Requirements

| ID | Requirement |
|---|---|
| CP-1 | Final lots > effective max (`InpMaxLotsPerOrder`, or `SYMBOL_VOLUME_MAX` if 0): per `InpAboveMaxAction` — default `SKIP_TRADE` with ERROR/WARN because the requested size violated the user's catastrophic cap; optional `CLAMP_DOWN` for deliberate cap-as-throttle workflows. |
| CP-2 | Final lots > 0 but < effective min (`InpMinLotsPerOrder`, or `SYMBOL_VOLUME_MIN` if 0): per `InpBelowMinAction` — default `SKIP_TRADE`; optional `CLAMP_UP` with WARN. Clamp-up increases risk above intent and must be an explicit operator choice, not the default. |
| CP-3 | Non-finite lots: reject, ERROR. |
| CP-4 | SL/TP wrong side or closer than dynamic stops level: reject, WARN. |
| CP-5 | Kill-switch tripped: reject. |
| CP-6 | `InpPanicStop` true at runtime (STRATEGY-SCOPE, v1): close this EA's hedging tickets, trip this EA's kill-switch, refuse entries until restart. v1 panic NEVER affects other strategies' positions or pending orders. Netting/exchange panic behavior is deferred with those account modes. A future system-wide "kill all strategies" panic switch is explicitly out of scope for v1 (v2+ feature). |
| CP-7 | Daily P&L < `-InpDailyLossPct%`: trip, close all, persist until server midnight. |
| CP-8 | Optimization: clear persistence at init. |
| CP-9 | `CRiskSizer` returns 0.0 (abort) on tick_value≤0, tick_size≤0, equity≤0, sl_dist≤0, risk≤0. 0.0 aborts; never clamped up by CP-2. |
| CP-10 | `SymbolContext.Init()` false → `INIT_FAILED`, ERROR. |
| CP-11 | `Submit()` explicit margin check independent of sizer. |
| CP-12 | Trade attempts before lifecycle phase 4 → ERROR + return 0/false. |
| CP-13 | Async fill timeout (5 s default): cancel pending if possible, else trip kill-switch + ERROR. |
| CP-14 | **v1 scope:** entry accepted only when this EA's position state machine is `FLAT`; entries from the same EA while its state is `ACTIVE`/`PENDING_*` are rejected (logged DEBUG). **v2 relaxation:** scaling-in / a second independent entry signal that ADDS to this EA's position is pyramiding — the state machine opens an `ACTIVE → PENDING_ADD → ACTIVE` self-loop with unit accounting (designed-for in F-POS-10). Until v2, an individual strategy attempting multiple concurrent entries is out of scope; this is a deliberate limitation, not an oversight. |
| CP-15 | Async broker/exchange rejection in `PENDING_ENTRY` → immediate `FLAT` + ERROR (F-POS-12). Must not wait for the fill timeout, which would block valid new entries. |
| CP-16 | v1 state persistence uses GV-only storage plus magic-filtered broker history. Ticket/deal/order IDs stored in GV MUST be lossless (`hi`/`lo` chunks). If restart reconciliation cannot safely reconstruct this EA's hedging ticket state or strategy-owned pending order relationship, this strategy MUST enter `HALT` with ERROR/alert-sink and last-known-state report rather than trade from guessed state. |
| CP-17 | `OrderCheck` (F-EXEC-4 stage 4) returning a trading-disabled verdict (terminal or program level) → reject + ERROR + trip kill-switch (no point continuing if the account cannot trade). Insufficient cumulative margin per `OrderCheck` → reject + WARN. |
| CP-18 | Retryable retcodes (per F-EXEC-8) trigger a bounded retry with refreshed price/quotes; after `InpMaxRetries` (default 3) exhausted, the order is rejected with WARN and the state machine returns to `FLAT`. Retryable retcodes MUST NOT count as broker rejections (which would skip the retry and re-arm immediately) nor as timeouts (which would HALT). |
| CP-19 | If a strategy does not override `GetSignalTimeframe()` (which has no default per F-STRAT-3), the framework MUST abort EA load with `INIT_FAILED` + ERROR naming the missing override. The `CNewBarDetector` cannot function without a valid signal timeframe, and silent fallback to `_Period` would couple the strategy's signal cadence to whatever chart it happens to be attached to — a real-money correctness hazard. |
| CP-20 | While a strategy is in `HALT`, all non-emergency entry/exit/modify/trailing helpers MUST refuse execution with ERROR and return failure. Only known-ownership panic/kill-switch cleanup may run. HALT is persisted and may clear automatically only after init/reconciliation proves a safe flat or safely repaired state per F-POS-20/F-POS-22; ambiguous ownership remains HALT with ERROR/alert-sink and last-known-state report. |

## 11b. Statistical Validation Note (forward-looking)

The Probabilistic Sharpe Ratio (PSR) is one candidate in-loop optimization criterion under consideration as a v3 feature, exposed via the selectable `ENUM_OPT_CRITERION` enum (see v3 roadmap). The companion Deflated Sharpe Ratio (DSR) is the post-hoc multiple-testing correction that runs in the external Python analytics layer, not in MT5. Detailed reasoning, formulas, trade-count caveats, and implementation guidance for both live in `Docs/RECIPES.md` when those features ship — they are out of scope for v1 specification beyond the v3 roadmap entry below.

## 12. Strategy Authoring Model

(See §7d for the pipeline.) A strategy includes `StrategyBase.mqh` + chosen indicators/stops/trails; declares strategy-specific inputs (incl. enum selectors for stop/trail types) plus the universal `CommonInputs` include; defines a class deriving from `CStrategyBase`; overrides `GetSizer`/`GetStopPolicy`/`GetSignalTimeframe`/`GetRiskPercent` plus `OnStrategyInit` and the cadence hook(s) it needs (`OnNewBar` for bar-cadence entries, `OnTickEvent` for tick-cadence entries, `OnManagePosition` for trailing/management); calls `OpenLong`/`OpenShort` for entries and `TrailSL`/`CloseAll`/`CloseLots` for management; ends with the MT5 entry-point shims that delegate to the strategy instance. Reference: `DonchianBreakout.mq5`. Full annotated stub in `Docs/AUTHORING.md`.

## 13. Acceptance Criteria

- **AC-1** Template→working strategy in <30 min (intermediate dev).
- **AC-2** Strategy file 80–250 lines excl. signal logic.
- **AC-3** Donchian reference matches hand-coded equivalent within ≤1 lot/trade under the minimum benchmark protocol in §13b.
- **AC-4** CP-1…CP-20 each covered by a test case.
- **AC-5** ≤10% optimization overhead vs hand-written under the minimum benchmark protocol in §13b.
- **AC-6** Same strategy file runs correctly on `RETAIL_HEDGING` accounts. On `RETAIL_NETTING` or `EXCHANGE`, v1 initialization fails with a clear deferred account-mode diagnostic and no trade path becomes active.
- **AC-7** Futures sizing (WIN, WDO): `SIZING_RISK_PERCENT` produces expected lots from broker tick-value/tick-size and SL distance; `SIZING_FIXED_LOT` yields constant lots across an optimization sweep. Equity sizing modes (`SIZING_FIXED_CASH`, `SIZING_PCT_EQUITY`): v1 placeholder behavior covered by AC-25. (→ see G-5 for v1/v2 scope.)
- **AC-8** Doxygen coverage 100% (grep).
- **AC-9** No raw `Print` in framework-authored production code (grep, excluding `MQL5/Experts/Main/TradeSpine/Include/StdLib/`, `Include/Testing/`, and `Scripts/Tests/` per NF-6).
- **AC-10** Margin-bypass test: sizer demanding margin > free×0.95 → `Submit` rejects, WARN, no position.
- **AC-11** Stop/trail enum optimization sweeps all values without erroring on NONE.
- **AC-12** All required docs exist and AUTHORING walks the Donchian simple-sample build end-to-end, while TESTING/port notes identify the two additional hedging ports and their compile/sign-off expectations.
- **AC-13** Trade call from constructor/OnStrategyInit → no order, ERROR with stage name.
- **AC-14** Intent audit: every entry produces a paired LogIntent/LogExecution CSV record with comment + metadata + computed stops + requested/submitted lots; v2-only netting/OCO fields are absent or empty in v1 hedging rows.
- **AC-15** Hedging close/partial-close behavior is verified per owned broker ticket; netting/exchange close mechanics are verified only as deferred-mode init failure in v1.
- **AC-16** Coordinator unit-testable: `Test_Coordinator.mq5` exercises the pipeline with mocks (sizer-returns-0 abort, kill-switch reject, below-min clamp, happy path) with no broker.
- **AC-17** State machine: entry attempt while `PENDING_ENTRY`/`ACTIVE`/`PENDING_EXIT` is rejected; `Test_PositionStateMachine.mq5` covers all transitions including timeout and `PENDING_CANCEL`.
- **AC-18** Vendored StdLib: framework compiles against `MQL5/Experts/Main/TradeSpine/Include/StdLib/`; grep confirms framework-authored code includes only the framework's own vendored `Include/StdLib/` (via quoted relative includes); `VERSION.md` present; vendored StdLib has no remaining angle-bracket includes after the seven `Object.mqh` edits.
- **AC-19** Broker-rejection handling (origin a, per F-POS-13): a simulated async rejection retcode while in `PENDING_ENTRY` with cancel-ownership-flag false transitions to `FLAT` within one tick (not after the timeout), logs ERROR, and a valid signal on the next tick is accepted. Covered in `Test_PositionStateMachine.mq5` and the Tier-2 harness.
- **AC-20** GV persistence and ticket precision: writing a `ulong` ticket/deal/order id stores and restores the exact same value through the `*_hi`/`*_lo` GV representation. Restart reconciliation uses GV state plus magic-filtered active/history broker objects; if active hedging ticket ownership cannot be reconstructed, the EA enters `HALT` with ERROR before accepting new entries.
- **AC-21** Entry-mode topology (F-EXEC, Signal): a `Signal` with `entry_mode = ENTRY_STOP`/`ENTRY_LIMIT` is rejected with ERROR in v1 ("pending entries are v2"); a wrong-side `entry_price` for the declared mode (e.g. `ENTRY_STOP` long with `entry_price < ask`) is rejected with ERROR, never silently reinterpreted.
- **AC-22** Split seam (F-EXEC-1/F-EXEC-3, F-COORD-1): `Test_Coordinator.mq5` constructs the coordinator with `MockTradePort` AND `MockPositionView` separately, demonstrating that pipeline tests can vary position state without touching submission and vice versa.
- **AC-23** Cancel disambiguation (F-POS-13): three test cases cover the three origins — (a) broker rejection before any framework cancel → `FLAT`; (b) framework-initiated cancel after timeout, confirmed → `PENDING_CANCEL → FLAT`; (c) framework-initiated cancel that fails or never confirms → `HALT` + kill-switch trip.
- **AC-24** `OrderCheck` stage: a request submitted while trading is disabled is rejected with ERROR and trips the kill-switch (CP-17); audit records carry `MqlTradeCheckResult.margin_level` only on success and the full projection (balance/equity/margin/margin_free/margin_level) only on rejection (per F-EXEC-4 stage 6).
- **AC-25** Sizing modes (v1 scope, futures-only): `CRiskSizer` produces expected lots for `SIZING_RISK_PERCENT` (on WIN/WDO futures) and `SIZING_FIXED_LOT`, each clamped/snapped to broker step/min/max correctly. `SIZING_FIXED_LOT` yields constant lots across an optimization sweep. Equity-sizing modes `SIZING_FIXED_CASH` and `SIZING_PCT_EQUITY` return `0.0` with WARN per NF-14 placeholder protocol — v1 does not implement equity-specific sizing.
- **AC-26** Retryable retcodes (F-EXEC-8, CP-18): a simulated `TRADE_RETCODE_REQUOTE` triggers up to `InpMaxRetries` retries with refreshed price; success after retry → DONE + audit shows retry count. Exhausted retries → reject + WARN + `FLAT`. A `TRADE_RETCODE_REJECT` is not retried.
- **AC-27** Event tolerance (F-POS-14): a tester-vs-live diff harness confirms the state machine reaches `ACTIVE` and `FLAT` correctly even when injected event streams omit specific transaction types or arrive out of order; accounting is read from canonical position/deal state rather than transaction struct field values.
- **AC-28** Slippage logged (F-CORE-5): every executed entry and exit produces a CSV row with `intended_price`, `actual_fill_price`, and `slippage_points` populated from the actual DEAL.
- **AC-29** Expiration warning (F-MKT-8): with the current symbol inside the warn window, a chart comment "Symbol expiring on YYYY-MM-DD" is visible and a WARN log appears; trading continues uninterrupted.
- **AC-30** Indicator-readiness gate (F-COORD-4): an indicator registered via `RegisterIndicator()` from `OnStrategyInit` that reports `IsReady() == false` causes entry attempts to be refused with WARN; once ready, the next entry attempt proceeds normally. An indicator NOT registered bypasses the gate (verified by a negative test case).
- **AC-31** Quoted include resolution: a clean checkout under `MQL5/Experts/Main/TradeSpine/` compiles without symlinks or files copied into `MQL5/Include`; grep confirms no framework-authored `<Trade/...>`, `<Expert/...>`, or stale `<TradeSpine/...>` angle-bracket includes.
- **AC-32** Account-mode deferral guard: selecting `RETAIL_NETTING` or `EXCHANGE` in v1 produces `INIT_FAILED`, logs ERROR with the selected raw `ACCOUNT_MARGIN_MODE`, and exposes an operator-facing "deferred account mode" diagnostic before any order, GV ledger, or adapter trade path is active.
- **AC-33** Hedging same-symbol ownership: two same-symbol TradeSpine strategy instances with different `InpMagicNumber` values on a hedging account maintain independent ownership evidence by magic+symbol+ticket and do not close, modify, or log each other's tickets.
- **AC-34** Deferred-mode no-side-effects: the `RETAIL_NETTING`/`EXCHANGE` init-failure path creates no virtual-ledger state, no pending-exit/OCO records, no execution mutex, and no trade CSV rows.
- **AC-35** Hedging restart recovery: after restart with GV present, this EA reconstructs in-memory state from its magic-filtered hedging ticket/history evidence; if active ticket ownership is ambiguous or contradictory, it enters `HALT` with ERROR before accepting new entries.
- **AC-36** Strategy-scoped panic breadth: v1 panic closes only this EA's hedging tickets, trips only this EA's kill-switch, and does not affect other TradeSpine strategies. Account-wide panic remains v2+.
- **AC-37** Netting/exchange manual evidence not required for v1: release sign-off confirms those modes are deferred by `INIT_FAILED`; concurrent same-symbol netting live/demo evidence is deferred to v2+ with the executable netting adapter.
- **AC-38** External/manual exposure non-interference: a manual order or non-TradeSpine order without this EA's magic does not change this EA's hedging strategy state, trigger HALT, or create this EA's audit/trade CSV row. A change to this EA's own hedging ticket is detected as strategy-scoped external intervention and logged as `CR_EXTERNAL` or `CR_EXTERNAL_REPAIRED`.
- **AC-39** Duplicate magic guard: in the same terminal, attaching two TradeSpine strategy instances with the same `(account, symbol, InpMagicNumber)` fails the second instance at init with `INIT_FAILED` + ERROR; using different magics on the same symbol succeeds. The test does not attempt cross-terminal/VPS detection, which is out of v1 scope.
- **AC-40** `POSITION_IDENTIFIER` treatment: in v1 hedging mode, ticket/magic/symbol evidence is the ownership source of truth. Netting aggregate `POSITION_IDENTIFIER` linkage is logged only as v2 diagnostic context and is never used to enable netting/exchange trading in v1.
- **AC-41** Hash-key stability and collision guard: `CKeyBuilder` produces the same `TS_<hash>_<short_field>` names across restart/build for the same canonical identity; a simulated diagnostic identity-hash mismatch aborts init with ERROR or HALTs if detected live.
- **AC-42** Stale duplicate marker recovery: a live heartbeat marker blocks a duplicate `(account, symbol, magic)` init with `INIT_FAILED` + ERROR. A marker whose heartbeat age is greater than 90 seconds is reclaimed with WARN by the new instance. A marker with a live chart but stale heartbeat is reclaimed because `owner_chart_id` is diagnostic only. A marker with a dead chart but fresh heartbeat is treated as live until the 90-second stale threshold expires.
- **AC-43** HALT behavior: entering HALT persists the state, refuses non-emergency helpers, logs ERROR, sends the required last-known-state fields through the alert sink, and survives restart. In live/visual mode the sink raises terminal `Alert`; in tester/non-visual/optimization tests the sink is mockable/log-only. Restart with reconcile-safe flat state auto-clears HALT and logs WARN. Restart with safely repaired hedging ticket state auto-clears HALT and logs WARN. Restart with ambiguous active ownership remains HALT and logs ERROR plus alert-sink payload. No input boolean is required or accepted for HALT clearing.
- **AC-44** Recovery matrix: tests cover every F-POS-22 row, including GV-present repair paths, GV-missing flat continuation, GV-missing ambiguous active ownership → HALT, and contradictory broker/history state repair only when a single unambiguous event explains drift.
- **AC-45** Strategy-owned external intervention repair/HALT: tests cover hedging ticket SL recreation, TP recreation/no-TP continuation/HALT, manually modified SL/TP replacement with `CR_EXTERNAL_REPAIRED`, hedging ticket manual close acceptance with `CR_EXTERNAL`, and ambiguous ticket ownership state → HALT.
- **AC-46** Low-I/O idle path: idle `OnTick` performs no GV writes, no `HistorySelect`, no chart redraw, and no order scan; entry/exit/trailing write counts stay within NF-15 budgets. Duplicate-marker heartbeat writes occur only on timer/maintenance cadence and stay outside the idle tick budget.
- **AC-47** Deferred netting design boundary: documentation and tests assert that virtual gross-position ledgers, netting pending-exit lifetime, framework-managed OCO, and execution mutex behavior are v2+ scope and are not required for v1 acceptance.
- **AC-48** Shipped v1 strategy set: the Donchian and Moving-Average simple samples plus the `1minscalpv3_hedging.mq5` and `BullishBearish Engulfing all v7 hedging.mq5` hedging ports compile as TradeSpine strategy artifacts, route framework-mediated trades through the guarded pipeline, and contain no direct broker-execution bypass in strategy code.

## 13b. Minimum Benchmark Protocol (AC-3 and AC-5)

This protocol is mandatory for any claim against AC-3 or AC-5.

1. **Environment freeze.** Run both baseline (hand-written) and framework strategy on the same terminal build, same broker/account type, same symbol, same timeframe, same date range, same spread model, and same initial deposit/leverage.
2. **Input parity.** Use equivalent strategy parameters (entry/exit logic, risk %, stop/trail settings) and record all input values in the run log.
3. **Run count.** Execute at least 5 independent runs per variant (baseline and framework) using identical settings; discard a run only with a documented technical failure.
4. **AC-3 comparison method.** Compare trade-by-trade lot sizes on matched entry events; pass condition: absolute difference `|lots_framework - lots_baseline| ≤ 1.0` for every matched trade.
5. **AC-5 comparison method.** Measure tester wall-clock duration for each run; compute median duration per variant; overhead formula is `((median_framework - median_baseline) / median_baseline) * 100`.
6. **Pass thresholds.** AC-3 passes only if all matched trades satisfy the lot-distance bound. AC-5 passes only if overhead is `≤ 10%`.
7. **Evidence artifacts.** Store: run manifest (environment + inputs), raw run timings, trade-match table for AC-3, and a final pass/fail summary. Reference artifact location in release notes.

## 14. Risks & Mitigations

| Risk | P | I | Mitigation |
|---|---|---|---|
| Virtual-call overhead >10% | Low | Med | Profiler; `final` on hot hooks; benchmark |
| Unsupported account mode reaches live trade path | Med | High | `RETAIL_NETTING`/`EXCHANGE` fail init with deferred-mode diagnostic (AC-6/AC-32); state-machine tests (AC-17) |
| GV ticket precision loss | Med | High | F-PERS-1 stores `ulong` ticket/deal/order IDs as high/low GV chunks; AC-20 verifies exact round-trip |
| Deferred netting design accidentally treated as v1 scope | Med | High | Non-goals, F-POS-16/17/19, AC-32/34/37/47, and roadmap all require init failure for netting/exchange modes in v1 |
| Manual/user activity changes broker aggregate exposure | Med | Low | F-POS-18 declares it outside strategy scope; strategy ledgers reconcile against this-EA GV-backed state and magic-filtered history only; unrelated manual orders are not strategy-logged; AC-38 verifies non-interference |
| Hedging ticket state ambiguous after restart | Med | High | Restart reconciliation uses magic-filtered ticket/history evidence; ambiguity enters HALT before accepting entries (AC-35/CP-16) |
| Stale duplicate marker blocks restart after crash | Low | Med | Marker heartbeat updates every 30 seconds; stale after 90 seconds → automatic reclaim with WARN; `owner_chart_id` is diagnostic only; AC-42 covers live/stale paths |
| Vendored StdLib drifts from terminal / misses a real fix | Med | Med | Documented update procedure (7c); test suite gate before adopting |
| Vendored `Object.mqh` include edit breaks on terminal quirk | Low | Med | Tier-1 compile test catches it immediately |
| Author bypasses guard with raw OrderSend | Med | High | NF-11 grep; policy; rich helper surface |
| Clamp-up-to-min increases risk above intent | Med | Med | Default `InpBelowMinAction=SKIP_TRADE`; clamp-up only by explicit operator choice and always WARNs |
| Coordinator interface seams add boilerplate | Low | Low | Worth it for testability (AC-16); seams are thin |
| Optimization parallel GV contamination | Low | High | Clear at init (CP-8) |
| Docs drift | Med | Med | F-DOC-9 same-commit rule |
| Async exchange rejection blinds EA for 5 s | Med | High | F-POS-12 immediate `PENDING_ENTRY → FLAT` on reject retcodes; timeout is backstop only |
| GV state unavailable or insufficient after restart | Med | High | Reconcile from magic-filtered active orders/deal history; if active hedging ticket ownership cannot be reconstructed safely, HALT this strategy before new entries (F-PERS-2, F-POS-22, CP-16, AC-20/35/44) |
| Hash-key collision or corruption | Low | High | `CKeyBuilder` stores a diagnostic identity hash per namespace and aborts/HALTs on mismatch (F-CORE-6, AC-41) |
| HALT hides actionable state from operator or clears unsafely | Med | High | F-POS-20 requires ERROR log, alert-sink payload, persisted halt reason, and last-known state report; automated clearing is reconcile-safe only; AC-43 verifies auto-clear and remain-halted paths |

## 15. Roadmap (phased build)

**v0.1 — Skeleton and source control foundation:** StdLib vendoring + `VERSION.md`; quoted include layout; `OptContext`, `Logger`, `SafeMath`, `Profiler` (`PROFILER_START`/`PROFILER_STOP`/`PROFILER_PRINT` macros, thin stubs — backend activated in this phase to enable early NF-1/NF-3 measurement); `CommonInputs` skeleton; `Testing/Assert.mqh`, `Testing/Mocks.mqh`, and `RunAllTests.mq5` skeleton. *Goal: clean compile path and first green no-trade tests.*

**v0.2 — Market and low-I/O persistence base:** `SymbolContext`, `AccountContext`, GV-backed `CStateStore`, `CKeyBuilder`/`KeyHash`, duplicate magic marker with fixed 30-second heartbeat and 90-second stale recovery, ticket/deal/order hi/lo persistence tests, and hashed namespace collision guard. *Goal: stable identity and persistence primitives before trading code.*

**v0.3 — Guarded execution and sizing:** `ITradePort`, `CGuardedTrade`, `FillingPolicy`, `SpreadGuard`, `OrderCheck`/`OrderCalcMargin`, retcode classification/retry loop, slippage logging, `CRiskSizer` with `SIZING_RISK_PERCENT` and `SIZING_FIXED_LOT`, kill-switch base. *Goal: one guarded market order path with catastrophic protection.*

**v0.4 — Strategy lifecycle and coordinator:** `Signal.mqh`, `TradeIntent`, `IStopPolicy` + `CStopATR`, `CTradeCoordinator`, `CStrategyBase`, lifecycle stage gates, `CNewBarDetector`, minimal template. *Goal: a minimal strategy can call `OpenLong` through the full pipeline.*

**v0.5 — State machine and transaction routing:** `CPositionStateMachine`, `CTradeTxRouter`, async rejection/timeout/cancel disambiguation, `PENDING_CANCEL`, HALT state, HALT alert/log/report behavior. *Goal: state transitions are explicit and recoverable.*

**v0.6 — Hedging adapter and account-mode gate:** `IAccountModeAdapter`, `CHedgingAdapter`, account-mode detection, `RETAIL_HEDGING` default/supported path, `RETAIL_NETTING`/`EXCHANGE` deferred-mode `INIT_FAILED`, hedging ticket filtering, hedging close/modify/trailing behavior, and simple hedging reference harness. *Goal: broker-native ownership path works and unsupported v1 account modes fail safely before trading.*

**v0.7 — Hedging recovery and release evidence:** hedging restart reconciliation, strategy-owned external-intervention repair/HALT policy, deferred-mode no-side-effect tests, low-I/O idle-path checks, and release evidence for hedging same-symbol independence. *Goal: v1 ownership and recovery are robust without implementing netting/exchange paths.*

**v0.8 — Documentation and v2 boundary stabilization:** developer guide, release governance, explicit v2 placeholders for netting virtual ledger, pending exits/OCO, execution mutex, equity sizing, and partial-close manager. *Goal: v1 docs are complete and deferred features are discoverable without becoming v1 acceptance work.*

**v0.9 — Reference ergonomics and documentation:** `IIndicator`/`CIndicatorBase`, `IndATR`, `IndMA`, `IndDonchian`, `IndSupertrend`, `CStopFixed`, `CStopSwing`, v1-active trailing (`CTrailATRMultiple`, `CTrailBreakeven`), visualization, README/AUTHORING/TESTING docs, Donchian and MA-cross simple samples, and the two additional hedging ports (`1minscalpv3_hedging.mq5`, `BullishBearish Engulfing all v7 hedging.mq5`). Profiler macros/backend are already part of v0.1 and are exercised here for final NF-1/NF-3 benchmarking. *Goal: full authoring experience, real-strategy port coverage, and documentation closeout.*

**v1.0 — Hardening:** CP-1…CP-20 harness; AC sign-off including deferred-mode account gate evidence; NF-1/NF-3/NF-15 performance benchmarks; RunAllTests green; MetaEditor strict compile; StdLib VERSION pinned; release docs.

**v2:** netting/exchange executable account modes (`CNettingAdapter`, virtual gross-position ledger, pending SL/TP exits, framework-managed OCO, short-lived execution mutex, and manual concurrent netting evidence pack); optional durability mode (GV flush and/or file snapshot) only if v1 recovery evidence proves it is needed; pyramiding, partial-close manager, `ISignalFilter`+filters, adaptive/drawdown sizer (`SIZING_ADAPTIVE` enum value), equity sizing modes (`SIZING_FIXED_CASH`, `SIZING_PCT_EQUITY`) implemented when the first equity strategy lands, remaining Native/ indicator wrappers (RSI, Bands, Stochastic, MACD, ADX, CCI) on demand, remaining trailing modes (`CTrailFixedDistance`, `CTrailStepped`), advanced `IExitManager`, custom `OnTester` (activates the `OnTester*` placeholder hooks) with the frame-export plumbing that logs ALL candidate criteria + parameter vectors per pass (shared with the DSR pipeline, §11b) and at least one hardcoded custom criterion (balance-curve stability and/or PSR) for empirical validation against each other on the reference strategies, depth-of-market subscriptions (activates `OnBookEventCustom`/`SubscribeToBook`), system-wide "kill all strategies" panic switch (closes positions across all TradeSpine EAs on the terminal, account-scoped); `OrderSendAsync` batch path for multi-leg entries using the `AsyncSwitcher` RAII idiom (constructor enables async, destructor restores sync — guarantees reset on any exit). **v3:** durable file persistence formats if still needed, multi-TF, Kelly, multi-TF bitmask, Python-ETL Deflated-Sharpe-Ratio audit over optimization result sets (§11b) incl. trial-clustering for effective independent N; user-facing selectable `ENUM_OPT_CRITERION` (`InpOptCriterion`, fixed-per-run never-swept) shipping the criteria validated as worthwhile during v2 (§11b). **v4:** multi-symbol, portfolio EA + `IPortfolioAllocator`, WebRequest. **v5+:** UI, deeper Python ETL tooling.

## 16. Decisions (all OQ resolved)

- Name: **TradeSpine**; folder `TradeSpine/`.
- Kill-switch defaults: permissive opt-in per F-RISK-4 (`InpDailyLossPct=0`, `InpMaxOpenLots=0`, `InpMaxTradesPerDay=0`, `InpPanicStop=false` — all disabled at ship; operator opts in by setting a non-zero limit). Operators wanting conservative caps during v1 development can set them per chart without code changes.
- Shipped strategy artifacts: Donchian breakout and MA-cross remain the simple reference samples; `1minscalpv3_hedging.mq5` and `BullishBearish Engulfing all v7 hedging.mq5` are additional hedging ports.
- Logger: system/debug → Journal; trade + state-change → CSV via `TradeLogger`.
- Build: manual MetaEditor for v1; future headless `terminal64.exe /config:tester.ini`.
- Profiler: 5 ms dev, off in optimization.
- Docs language: English + B3 glossary.
- Entry styles: imperative helpers only (`OpenLong`/`OpenShort` + management helpers), callable from `OnNewBar` (bar cadence) or `OnTickEvent` (tick cadence). Signal struct remains framework-internal. (OQ-8 reversed in v1.8 after critical review.)
- Exits: split `Stops/` and `Trailing/` folders.
- Coordinator: pipeline extracted into composed `CTradeCoordinator` with `ITradePort` seam.
- Includes/location: `MQL5/Experts/Main/TradeSpine/` with quoted relative includes.
- StdLib: vendored + frozen (total-freeze Option A; vendored `Object.mqh`, edited include).
- Analytics: Python-side only; framework reports, does not analyze.
- Project root: `MQL5/Experts/Main/TradeSpine/`; framework code at `MQL5/Experts/Main/TradeSpine/Include/`; includes are quoted relative paths. This keeps EAs visible in the MT5 Navigator while remaining self-contained.
- Sessions: broker `SymbolInfoSessionTrade` is the scheduled session source; `OrderCheck`/retcodes/symbol trade flags are authoritative for ad hoc closures and halts. User `InpSessionStart`/`InpSessionEnd` overlay a strategy-active sub-window. Both must hold for entries.
- State tracking: in v1 hedging mode, this EA's GV-backed state + magic-filtered ticket/deal/order history are authoritative for this EA (F-POS-15/F-PERS-1). `POSITION_IDENTIFIER` is useful as hedging ticket diagnostic identity but is not a netting virtual identity in v1. Netting virtual ledgers are v2+ scope. State is never inferred from comments, mutable position ticket alone, or `PositionSelect(symbol)` alone. v1 deliberately avoids a custom file snapshot layer to minimize I/O. GV names are hash-based (`CKeyBuilder`) rather than raw identity strings, and v1 recovery prefers HALT with operator-facing state over guessing when low-I/O GV/history evidence is insufficient.
- GV keying: all v1 GV names are generated by `CKeyBuilder` as `TS_<16hex_hash>_<short_field>` from canonical identity strings. Raw account/symbol/magic identity is only logged for humans. Collision/corruption is detected by comparing the stored diagnostic identity hash (FNV-1a) against the expected identity on init/reconciliation; mismatch → `INIT_FAILED` or `HALT`. (→ see F-CORE-6.)
- HALT: persisted per-strategy safety state; blocks non-emergency trading; clears only via reconcile-safe automated recovery. (→ see F-POS-20.)
- External intervention: unrelated manual/non-TradeSpine orders are ignored; strategy-owned external changes are repaired/recreated when unambiguous and safe, otherwise HALT.
- Performance: v1 is low-I/O by design; no per-tick GV writes, history scans, order scans, or chart redraws on idle ticks. Durability stronger than terminal-managed GV persistence is v2+ only if v1 evidence proves it is needed.
- Changelog governance: `CHANGELOG.md` is the canonical record of PRD/version decisions. Every `Document version` requires a same-version changelog entry with date and summary before release sign-off.
- Multi-TP / scale-out: v2 partial-close-manager concern; `TradeIntent` stays single SL/TP in v1.
- Multiple concurrent entries / scaling-in: v2 (pyramiding via `PENDING_ADD`); v1 is single-entry (CP-14).
- Paradigm: classes for stateful/polymorphic; free functions for pure logic (P-10).
- One strategy per chart symbol; multiple strategies per symbol: each TradeSpine strategy instance attaches to one symbol, and one symbol may host multiple strategy instances with different `InpMagicNumber` values. In v1 this is supported on hedging accounts through broker-native tickets. Netting/exchange same-symbol isolation is deferred to v2+ with the virtual gross-position ledger and framework-owned pending SL/TP exit design notes (F-POS-16/19).
- Netting broker aggregate model: deferred v2+; v1 detects `RETAIL_NETTING`/`EXCHANGE`, reports them, and fails init before trading. (→ see G-4a, F-POS-16.)
- Netting SL/TP: deferred v2+ strategy-owned pending stop/limit orders + framework-managed OCO. (→ see F-POS-19.)
- Outside/manual orders: unrelated manual/non-TradeSpine orders are outside strategy scope and do not affect per-EA state or logs. (→ see F-POS-18.)
- Duplicate magic guard: terminal-local only for v1. `(account, symbol, InpMagicNumber)` collisions in the same terminal fail init; another terminal/VPS running the same login is out of scope and operator-managed. **Liveness mechanism for the marker: fixed low-frequency heartbeat** — the marker side-GVs store owner diagnostics plus a heartbeat timestamp updated every 30 seconds. Fresh heartbeat blocks duplicate init; heartbeat older than 90 seconds is stale and may be reclaimed with WARN. `owner_chart_id` is diagnostic only. This heartbeat is separate from the short-lived execution mutex, which still uses acquisition timestamps because its critical section must recover quickly.
- Session time: `TimeCurrent()` is the authoritative clock for all session comparisons in v1. `InpSessionStart`/`InpSessionEnd` are entered as broker/server time (HH:MM); no user offset input is provided. Adding an offset would introduce a misconfiguration vector with no benefit while v1 focuses solely on B3 (where the broker and exchange clocks are aligned).
- Panic scope: STRATEGY-LEVEL for v1 (CP-6). Account-wide panic is v2+.

## 17. Glossary

B3; Catastrophic event; Chokepoint; Coordinator (pipeline orchestrator); ENUM_SIZING_MODE (sizing calculation selector); Hedging; Indicator-readiness gate (entries refused while installed indicators report not-ready); Lifecycle stage; MqlTradeCheckResult (OrderCheck projected account state); Netting; OrderCheck (broker pre-flight validation: formal correctness, trading-disabled, cumulative margin); Optimization pass; Placeholder (`@v2_placeholder` — declared but not implemented, reserved per NF-14); PLACED retcode; Pluggable; Port/seam (`ITradePort`, an interface enabling test mocks); Position state machine (FLAT/PENDING_ENTRY/ACTIVE/PENDING_EXIT/PENDING_CANCEL/HALT); Retryable retcode (REQUOTE/PRICE_CHANGED/PRICE_OFF and connection-class; bounded retry per F-EXEC-8); Signal (framework-internal entry intent struct — constructed inside `OpenLong`/`OpenShort` and the close helpers, consumed by the pipeline and `TradeLogger`; never authored directly by strategy code); Slippage (intended vs actual fill price, logged per F-CORE-5); StopLevels; StopPolicy (initial stop); TradeIntent (unified audit payload); Trail (ongoing stop); ENUM_OPT_CRITERION (v3 selectable in-loop optimization fitness function — balance-DD / balance-stability / PSR / profit-factor / expected-payoff; fixed per run, never swept); DSR (Deflated Sharpe Ratio — Sharpe corrected for multiple-testing selection bias + non-normality; computed post-optimization in Python, §11b); PSR (Probabilistic Sharpe Ratio — probability the true Sharpe exceeds a benchmark, correcting for sample length/skew/kurtosis; computable per-pass in `OnTester()`, §11b); POSITION_IDENTIFIER (broker key for position episodes — on hedging it identifies a specific ticket's position object and is directly useful as identity; on netting it identifies aggregate-position episodes and is diagnostic/linkage only for TradeSpine virtual ownership, NOT virtual position identity); CKeyBuilder/KeyHash (framework-owned deterministic hash key generator for GV names); HALT (persisted per-strategy safety state that blocks non-emergency trading, reports last known state, and clears only after reconcile-safe automated recovery); Recovery matrix (v1 rules deciding repair, continue, or HALT from GV/history/broker evidence); RegisterIndicator (CStrategyBase method called from OnStrategyInit to register an indicator with the coordinator's readiness gate — F-COORD-4); TradeLogger (framework component that writes the two paired CSV records — LogIntent before submission and LogExecution after broker result — to the MQL5 Files sandbox per F-CORE-7); Vendored StdLib (frozen, in-repo copy of the standard-library subtree).

*End of document.*
