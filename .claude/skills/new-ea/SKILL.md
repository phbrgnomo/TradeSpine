---
name: new-ea
description: "Create a new single-file MQL5 Expert Advisor in Experts/Main following this repo's conventions. Guides requirements gathering, implements the EA, and runs a syntax check."
disable-model-invocation: true
---

# New MQL5 Expert Advisor

Create a single-file MQL5 Expert Advisor in `Experts/Main/` following the conventions of this repository.

## Step 1 — Load MQL5 reference (REQUIRED)

Invoke `skill: mql-developer-main`. Load before writing any code:
- `references/mql5-reference.md` — CTrade, event handlers, enumerations
- `references/trading-operations.md` — order management, async fills, position sizing
- `references/architecture-patterns.md` — EA structure and design patterns

## Step 2 — Gather requirements

Ask the user for the following before writing any code. Use `#tool:vscode/askQuestions` if available; otherwise ask in chat:

1. **EA name** — used as the filename (`Experts/Main/<name>.mq5`) and `#property` fields
2. **Strategy** — entry and exit conditions, indicators, timeframes. Ask clarifying questions until the logic is unambiguous.
3. **Session mode** — one of:
   - *Day trade* — positions opened during session only; all closed at session end
   - *Swing trade* — positions opened during session only; held overnight
   - *24h* — no session restriction
4. **Position sizing method** — Fixed lot / % of equity (uses `RiskSizer.mqh`) / ATR-based
5. **Exit types** — which of the following to activate: Take Profit, Stop Loss, Signal-based exit, Time-based exit
6. **Visualization** — show chart objects during live trading? (disabled in optimization automatically)

Do NOT proceed to Step 3 until all answers are confirmed.

## Step 3 — Implement the EA

Create `Experts/Main/<name>.mq5` as a **single file** — no new files outside that folder.

### Required file header

```mql5
//+------------------------------------------------------------------+
//| <EAName>.mq5                                                     |
//| Copyright 2026, Paulo Henrique Barreto Rebouças                  |
//| https://www.mql5.com                                             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Paulo Henrique Barreto Rebouças"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
```

### Required includes

Always include these; add others only when needed:

```mql5
#include "Include/Trade/Trade.mqh"        // CTrade — all order execution
#include "Include/Trade/RiskSizer.mqh"    // RiskSizerInit / RiskSizerCalcLot — % equity sizing
```

Use quoted relative includes for `Trade/Trade.mqh` and `Trade/RiskSizer.mqh`; vendored libraries must live under the repository's `Include/` vendor path so builds do not rely on terminal-wide installs. Include `"Include/Trade/TradeRecorder.mqh"` only if the user asks for trade logging.

### Naming conventions

| Scope | Prefix | Example |
|-------|--------|---------|
| Global variable | `g_` | `g_trade`, `g_barTime` |
| Input parameter | `Inp` | `InpMagicNumber`, `InpRiskPercent` |
| Struct member | none | `.direction`, `.lots` |
| Class member | `m_` | `m_handle` |

### Required input groups

```mql5
input group "=== General ==="
input long   InpMagicNumber  = 12345;       // Magic number
input bool   InpEnableLogs   = true;        // Enable journal logging
input bool   InpDebugMode    = false;       // Enable debug diagnostics

input group "=== Session ==="
// ... session start/end, mode

input group "=== Risk Management ==="
input double InpRiskPercent  = 1.0;         // Risk per trade (% equity)
input double InpFixedLot     = 0.01;        // Fixed lot (if fixed sizing)

input group "=== Strategy ==="
// ... strategy-specific inputs

input group "=== Visualization ==="
input bool   InpShowObjects  = true;        // Show chart objects (disable in optimization)
```

### OnInit requirements

```mql5
int OnInit() {
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpDeviation);

   if(!RiskSizerInit(InpEnableLogs))  // required when using % equity sizing
      return INIT_FAILED;

   // ... indicator handle creation, symbol cache, etc.
   return INIT_SUCCEEDED;
}
```

### OnTick requirements

- **Must be lightweight.** Heavy calculations (indicators, state updates) go inside a new-bar gate.
- New-bar detection: `iTime(_Symbol, InpSignalTimeFrame, 1)` — uses the last *completed* bar, which is stable.
- All logging conditional on `InpEnableLogs` or `InpDebugMode`.
- All chart object drawing conditional on `InpShowObjects && !MQLInfoInteger(MQL_OPTIMIZATION)`.

```mql5
void OnTick() {
   static datetime s_lastBar = 0;
   datetime curBar = iTime(_Symbol, InpSignalTimeFrame, 1);
   bool isNewBar = (curBar != s_lastBar && curBar > 0);

   if(isNewBar) {
      s_lastBar = curBar;
      // update indicators, check signals, manage exits
   }

   // lightweight per-tick checks only (e.g., trailing stop, internal SL)
}
```

### Trade execution

Use `CTrade` for all order operations — never call `OrderSend()` directly:

```mql5
CTrade g_trade;

// Open:
g_trade.Buy(lots, _Symbol, 0.0, sl, tp, "comment");

// Close:
g_trade.PositionClose(_Symbol, InpDeviation);
```

Pass `price=0.0` on Buy/Sell for market orders to reduce requotes.

### Position sizing

When using % equity sizing:

```mql5
double lots = RiskSizerCalcLot(
   InpRiskPercent,      // % of equity
   slDistance,          // price distance entry→SL
   ORDER_TYPE_BUY,      // for margin check
   0.0,                 // no lot cap
   0.0, 0.0,            // use symbol defaults
   InpEnableLogs
);
```

### OnTester (REQUIRED)

```mql5
double OnTester() {
   double pf = TesterStatistics(STAT_PROFIT_FACTOR);
   double dd = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   if(pf <= 0 || dd >= 30.0) return 0.0;
   return pf * (1.0 - dd / 100.0);   // profit factor penalized by drawdown
}
```

### Pluggable strategy class

Encapsulate all strategy-specific logic in a `CStrategy` class:

```mql5
class CStrategy {
public:
   bool  Init();          // create indicator handles
   void  Update();        // called once per bar — cache indicator values
   int   CheckEntry();    // returns +1 (buy), -1 (sell), 0 (none)
   int   CheckExit();     // returns +1 (close long), -1 (close short), 0 (none)
};
```

`OnTick()` instantiates and calls this class — keeping the EA shell reusable.

## Step 4 — Verify: docs and examples (for any non-trivial API usage)

When uncertain about an MQL5 API signature used in the implementation:
→ Invoke `skill: mql5-docs-research` to confirm before finalizing the code.

When implementing a well-known pattern (trailing stop, ATR calculation, Donchian channel, etc.):
→ Invoke `skill: mql5-code-examples` to find a reference implementation.

## Step 5 — Syntax check (REQUIRED)

After writing the file, run the syntax check via the VS Code command:

```
mql_tools.checkFile
```

Use `#tool:vscode/runCommand` with command `mql_tools.checkFile`. If the file is not the active editor, open it first. Fix all reported errors before declaring the EA complete. Cancel with `mql_tools.checkFileStop` if the check hangs.

## Step 6 — Report

Provide a brief summary in chat:
- Strategy implemented (entry/exit logic in 2–3 sentences)
- Risk management method and sizing formula used
- Session mode configured
- Any open decisions left to the user (e.g., symbol-specific parameters to tune)
- Syntax check result (zero errors, or list of fixes applied)

## Acceptance criteria

- Single file under `Experts/Main/` only — no other folders touched
- `#property strict` present
- All inputs use `Inp` prefix and are organized into groups
- `g_` prefix on all globals
- `CTrade` used for all order execution
- `OnTick()` is lightweight; heavy work gated to once per bar
- Logging conditional on `InpEnableLogs` / `InpDebugMode`
- `OnTester()` returns a meaningful optimization metric
- Zero syntax errors from `mql_tools.checkFile`
