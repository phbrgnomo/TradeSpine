# Module: Market Session and Symbol Context

**Status: Implemented** · Owning plan: IPLAN-06 · Spec: SPEC-06 · Source: `Include/Market/`

The Market module loads immutable symbol metadata once at initialisation, evaluates session and
trading-hours gates per-tick, validates order definitions before submission, and detects
contract-expiration warnings for futures symbols. It exposes seams for future Position
(IPLAN-04), Coordination (IPLAN-02), and Execution (IPLAN-03) integration; the current Position
implementation does not include Market directly.

---

## Files

| File | Kind | Purpose |
|---|---|---|
| `Include/Market/Interfaces.mqh` | Production | `IContractInfoProvider`, `IMarketSessionProvider` (`IsMarketSessionOpen` + `MarketSessionEndTod`) seams |
| `Include/Market/SymbolContext.mqh` | Production | `SymbolMetadata` struct + `CSymbolContext` |
| `Include/Market/SessionContext.mqh` | Production | `SessionWindow` struct + `CSessionContext` |
| `Include/Market/MarketContext.mqh` | Production | live provider adapters and `CMarketContext`; consumes canonical `TradeIntent` from `Include/Core/TradeTypes.mqh` |
| `Scripts/Tests/Support/FakeMarketContext.mqh` | Test support | `FakeMarketContext` fixture class |
| `Scripts/Tests/Test_SymbolContext.mq5` | Test (unit) | TDD.06.04.8f4d — metadata + validators |
| `Scripts/Tests/Test_SymbolContextLive.mq5` | Test (manual integration) | TDD.06.04.a1e6 — production `CSymbolInfo` adapter smoke; excluded from aggregate |
| `Scripts/Tests/Test_SessionContext.mq5` | Test (integration) | TDD.06.04.4796 — session gates |
| `Scripts/Tests/Test_ContractLifecycle.mq5` | Test (e2e) | TDD.06.04.cd48 — expiry warning |

---

## SymbolMetadata (`Include/Market/SymbolContext.mqh`)

Immutable snapshot populated once at `CSymbolContext::Init()` and never updated on subsequent
ticks. Default constructor zeroes all fields so an incomplete fixture fails `ValidateMetadata()`.

```mql5
struct SymbolMetadata {
    double                 tick_size;    // SYMBOL_TRADE_TICK_SIZE; 0.0 = invalid sentinel
    double                 tick_value;   // SYMBOL_TRADE_TICK_VALUE
    double                 contract_size; // SYMBOL_TRADE_CONTRACT_SIZE
    double                 point;        // SYMBOL_POINT — used for stop-distance math
    double                 lot_step;     // SYMBOL_VOLUME_STEP
    double                 lot_min;      // SYMBOL_VOLUME_MIN
    double                 lot_max;      // SYMBOL_VOLUME_MAX
    int                    digits;       // SYMBOL_DIGITS
    int                    stops_level;  // SYMBOL_TRADE_STOPS_LEVEL (live call cached at Init)
    int                    freeze_level; // SYMBOL_TRADE_FREEZE_LEVEL (live call cached at Init)
    ENUM_SYMBOL_TRADE_MODE trade_mode;   // SYMBOL_TRADE_MODE
    SymbolMetadata(void);               // all-zero default
};
```

---

## CSymbolContext (`Include/Market/SymbolContext.mqh`)

Uses vendored `CSymbolInfo` to populate `SymbolMetadata` at init-time. All validators operate on
the cached snapshot — no broker API calls on tick.

### Public interface

```mql5
bool Init(const string symbol)
```
Production init calls `CSymbolInfo::Name()`, then maps only the required typed accessors into the
TradeSpine-owned snapshot. It deliberately does not require profit/loss-specific tick-value
properties. Returns `false` if the adapter cannot load the symbol or a required field fails validation.


```mql5
bool InitFromMetadata(const SymbolMetadata &meta)
```
Test-only injection path. Accepts a pre-built fixture and validates it with the same
`ValidateMetadata()` guard: finite positive `tick_size`, `tick_value`, `contract_size`, `point`,
and lot fields, with `lot_max >= lot_min`; non-negative `stops_level` and `freeze_level`; and a
whitelisted `ENUM_SYMBOL_TRADE_MODE`.

```mql5
bool IsInitialized() const
bool IsEntryAllowedLive(ENUM_ORDER_TYPE) const // respects LONGONLY / SHORTONLY restrictions
SymbolMetadata Metadata() const
bool ValidateLots(double lots, string &reason) const
bool ValidatePrice(double price, string &reason) const
bool ValidateStops(double sl, double tp, double entry_price, string &reason) const
```

`Init()` and `InitFromMetadata()` `Print` a field-level diagnostic on failure (e.g.
`tick_size must be > 0`) rather than failing silently. `Init()` retains the symbol name so
`IsEntryAllowedLive()` can re-read the broker trade mode (which can change intraday) via a
single direct `SymbolInfoInteger` call. Fixture contexts use their injected metadata. An uninitialized context or
failed live read rejects entries conservatively.

Before each production initialization, `CSymbolContext` clears the complete cached metadata
snapshot. A failed re-initialization therefore cannot expose a prior symbol's values through
`Metadata()`.

### Manual production-adapter smoke

`Scripts/Tests/Test_SymbolContextLive.mq5` is a read-only Tier-1.5 script. Attach it to an
approved B3 chart (or set `InpSymbol`) and run it from the Navigator. It calls
`CSymbolContext::Init()`, asserts the required production snapshot fields, and prints one
`[LIVE]` line containing the loaded values. It is intentionally excluded from `RunAllTests`,
whose Market tests must remain deterministic and fixture-only. It never sends, modifies, or
closes trades.

**Trade-mode matrix:**

| `ENUM_SYMBOL_TRADE_MODE` | BUY allowed | SELL allowed |
|---|---|---|
| `FULL` | true | true |
| `LONGONLY` | true | false |
| `SHORTONLY` | false | true |
| `CLOSEONLY` | false | false |
| `DISABLED` | false | false |

**ValidateMetadata note:** each double field is guarded by `SafeMath::IsFinite()` before the
`<= 0` / `< lot_min` comparison, because MQL5 NaN comparisons always return false (so `NaN <= 0.0`
is false and would silently pass without the guard).

**ValidatePrice note:** uses cached `m_meta.tick_size` and `m_meta.digits` directly
(`NormalizeDouble(MathRound(price/tick_size)*tick_size, digits)`) — never reads `_Symbol` so
fixture-based tests are deterministic.

**ValidateStops note:** stop distance is computed in points (`MathAbs(entry-stop)/m_meta.point`).
`sl=0.0` or `tp=0.0` skips the corresponding check. `stops_level=0` skips all distance checks.

---

## SessionWindow (`Include/Market/SessionContext.mqh`)

Three boolean flags computed per-tick by `CSessionContext::Evaluate()`. Default constructor
sets all flags to `false`.

```mql5
struct SessionWindow {
    bool market_open;              // broker market-session schedule is open
    bool user_trading_hours_open;  // current time within entry_window
    bool day_trade_close_required; // close buffer reached (day_trade_mode only)
    SessionWindow(void);
};
```

---

## CSessionContext (`Include/Market/SessionContext.mqh`)

Pure time-gate: reads `IClock::Now()` and `CommonInputs` configuration. No broker API calls.

### Public interface

```mql5
void Init(const CommonInputs &inputs, IClock *clock)
SessionWindow Evaluate(bool market_session_open, int market_session_end_tod = -1)  // non-const
```

**Time arithmetic** (all arithmetic in broker-local time):

- `tod = (int)(clock.Now() % 86400)` — seconds since midnight
- `start_tod = (int)(inputs.entry_window_start % 86400)`
- `end_tod = (int)(inputs.entry_window_end % 86400)`
- `user_trading_hours_open = (tod >= start_tod && tod < end_tod)` — inclusive start, exclusive end
- **Close reference** (`CommonInputs.close_reference`): the trigger is measured from either the user
  window end or the broker market session end.
  - `CLOSE_REF_USER_WINDOW_END` (default): `close_ref_tod = end_tod`
  - `CLOSE_REF_MARKET_SESSION_END`: `close_ref_tod = market_session_end_tod` when it is `> 0`;
    otherwise it falls back to `end_tod` and `Print`s a warning.
- `close_trigger_tod = close_ref_tod - inputs.close_mins_before * 60`
- `day_trade_close_required = (inputs.day_trade_mode && tod >= close_trigger_tod)`

`market_session_end_tod` is supplied by `CMarketContext` from an `IMarketSessionProvider`;
`CSessionContext` itself stays pure (no broker calls). When `day_trade_mode = false`:
`user_trading_hours_open` is always `true`; `day_trade_close_required` is always `false`.

---

## Injectable seams (`Include/Market/Interfaces.mqh`)

Mirrors the `Include/Core/Interfaces.mqh` convention — the interfaces live in their own header;
live broker adapters live with their consumer (`MarketContext.mqh`); test doubles
(`FakeMarketContext`) implement them directly.

```mql5
interface IContractInfoProvider {
    datetime ExpirationTime() const;          // 0 = no expiry / non-futures
};
interface IMarketSessionProvider {
    bool IsMarketSessionOpen(datetime when) const; // true when when is inside a trade session;
                                                   // false outside / no schedule (conservative)
    int  MarketSessionEndTod(datetime when) const; // last trade-session end (sec from
                                                   // midnight) for when's weekday; -1 = none
};
```

**Live adapters (`Include/Market/MarketContext.mqh`):**

- `CLiveContractInfoProvider` — calls `CSymbolInfo::ExpirationTime()`
  (`SymbolInfoInteger(SYMBOL_EXPIRATION_TIME)`); returns 0 for non-futures, and `Print`s a warning
  when the symbol cannot be selected (distinguishing a query error from the legitimate 0).
- `CLiveMarketSessionProvider` — iterates `SymbolInfoSessionTrade(symbol, dow, idx, from, to)` for
  the weekday of `when`. `IsMarketSessionOpen` returns `true` when `when`'s time-of-day falls inside
  any session `[from, to)`; `MarketSessionEndTod` returns the latest session `to` (seconds from
  midnight), or -1 when no session is defined. Midnight-crossing market sessions are out of scope for v1.

`FakeMarketContext` (test-time only) implements **both** interfaces by returning configured fixtures.

---

## TradeIntent — `Include/Core/TradeTypes.mqh` (CHG-21)

`TradeIntent` was hoisted from `Include/Market/MarketContext.mqh` to `Include/Core/TradeTypes.mqh`
by CHG-21 so that Market, Coordination (SPEC-02), and Execution (SPEC-03) share one canonical
definition. `CMarketContext::ValidateOrderDefinition()` consumes it via the shared Core header.
See [Core.md — TradeTypes.mqh](Core.md#tradetypesmqh--shared-trade-domain-types-chg-21) for
the full struct definition and extension policy.

---

## CMarketContext (`Include/Market/MarketContext.mqh`)

Facade that coordinates `CSymbolContext`, `CSessionContext`, and `IContractInfoProvider`.

### Public interface

```mql5
bool Init(const string symbol, const CommonInputs &inputs, IClock *clock,
          ILogSink *sink, COptContext *ctx)
```
Production path. Loads symbol metadata from the broker, wires the session context, and
creates owned `CLiveContractInfoProvider` and `CLiveMarketSessionProvider` adapters. Returns
`false` on a `NULL` clock or broker metadata failure.

```mql5
bool InitFromFixtures(const SymbolMetadata &meta, const CommonInputs &inputs,
                      IClock *clock, ILogSink *sink, COptContext *ctx,
                      IContractInfoProvider *provider,
                      IMarketSessionProvider *session_provider = NULL)
```
Test path. Injects metadata, a contract provider, and an optional market-session provider without
live broker calls. The provided provider pointers are **not owned** — caller manages lifetime. A
`NULL` `session_provider` makes `market_open` resolve to the conservative closed default (and leaves
`market_session_end` unavailable, so a `MARKET_SESSION_END` close reference falls back to the user
window end); tests exercising the market-session gate must pass a provider. **Returns `false` on a
`NULL` clock** (and logs via `sink`) as well as on metadata-fixture failure.

```mql5
bool            IsReady() const
CSymbolContext* SymbolCtx()      // renamed from Symbol() to avoid shadowing global Symbol()
SessionWindow   EvaluateSession()
bool ValidateOrderDefinition(const TradeIntent &intent, string &reason) const
bool IsExpirationWarning(datetime session_open_time) const
```

**EvaluateSession:** computes `market_open` from
`IMarketSessionProvider.IsMarketSessionOpen(now)` only (conservative `false` when no session
provider is wired). It also queries `MarketSessionEndTod` (using the retained `IClock` to date the
query) and passes it to `CSessionContext::Evaluate()` for the close-reference math. Directional
trade-mode permission is evaluated by `ValidateOrderDefinition()` once an intent exists.

**ValidateOrderDefinition:** delegates to `CSymbolContext::IsEntryAllowedLive(intent.order_type)`,
`ValidateLots`, and `ValidatePrice` (skipped when `intent.price == 0`); then enforces order-level
rules — an entry price is required when SL/TP is set, side-aware stop ordering (BUY: SL below / TP
above entry; SELL: the mirror), and the SL/TP price grid — before `ValidateStops`. Returns `false`
with an operator-facing `reason` string on any failure. Non-finite (NaN/Inf) price, SL, or TP
values are explicitly rejected before the `> 0.0` branch; MQL5 NaN comparisons always return false,
so an explicit `SafeMath::IsFinite()` guard is required.

**IsExpirationWarning:** returns `true` when `IsReady()` and `0 < provider.ExpirationTime() - session_open_time ≤ 86400`.
Returns `false` when not ready (guarded against stale providers from a failed re-init), when
`ExpirationTime() == 0` (non-futures), or the delta is negative (past expiry) or beyond one
broker day. Both `Init()` and `InitFromFixtures()` also clear `m_contract_info`/`m_session_info`
at the top of the call, before any early-exit path, so a failed re-init leaves no stale state.

---

## FakeMarketContext (`Scripts/Tests/Support/FakeMarketContext.mqh`)

MQL5 does not support multiple inheritance, so the fake surface is split across two classes in the
same file.

**`FakeMarketSessionProvider`** — implements `IMarketSessionProvider`:

```mql5
void SetMarketSessionOpen(bool open)   // drives IsMarketSessionOpen independently of trade mode
bool SetMarketSessionEnd(int tod)      // [0..86399] or -1; false + stores -1 if out-of-range
void Reset()                           // session closed, end unavailable
bool IsMarketSessionOpen(datetime) const override
int  MarketSessionEndTod(datetime) const override
```

**`FakeMarketContext`** — implements `IContractInfoProvider`, owns a `FakeMarketSessionProvider`
by value:

```mql5
void SetAsB3Futures()       // tick_size=5.0, point=1.0, tick_value=1.0, lot_step/min=1.0,
                            // lot_max=900.0, digits=0, stops_level=0, freeze_level=0, FULL, session open
void SetAsInvalidSymbol()   // tick_size=0.0 → triggers CSymbolContext::InitFromMetadata failure
void ConfigureMetadata(double tick_size, double tick_value, double contract_size,
                       double point, double lot_step, double lot_min, double lot_max,
                       int digits, int stops_level, int freeze_level,
                       ENUM_SYMBOL_TRADE_MODE mode)
void SetMarketSessionOpen(bool open)         // delegates to internal FakeMarketSessionProvider
void SetExpirationTime(datetime expiry)      // 0 = no expiry
bool SetMarketSessionEnd(int tod)            // delegates; [0..86399] or -1
FakeMarketSessionProvider* SessionProvider() // pass to InitFromFixtures() as session_provider
SymbolMetadata Metadata() const              // returns by value (MQL5 disallows reference returns)
datetime ExpirationTime() const override     // IContractInfoProvider
```

Pass `&fake` as `IContractInfoProvider*` and `fake.SessionProvider()` as `IMarketSessionProvider*`
to `CMarketContext::InitFromFixtures()`.

---

## Dependencies

- Vendored `Include/StdLib/Trade/SymbolInfo.mqh` — sole adapter for static broker metadata reads
- `Include/Core/Interfaces.mqh` — `IClock`, `ILogSink`
- `Include/Core/CommonInputs.mqh` — `CommonInputs` struct
- `Include/Core/SafeMath.mqh` — `NormalizeLotRaw`, `EqualDoubles`, `IsFinite`
- `Include/Core/OptContext.mqh` — `COptContext`

---

## Include paths

From `Include/Market/*.mqh`:

```
#include "Interfaces.mqh"                   // intra-module seams (MarketContext.mqh)
#include "../StdLib/Trade/SymbolInfo.mqh"    // static symbol metadata adapter
#include "../Core/SafeMath.mqh"
#include "../Core/Interfaces.mqh"
#include "../Core/CommonInputs.mqh"
#include "../Core/OptContext.mqh"
```

From `Scripts/Tests/Support/FakeMarketContext.mqh`:

```
#include "../../../Include/Market/MarketContext.mqh"
```
