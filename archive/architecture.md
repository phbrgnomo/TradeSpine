# MQL5 Expert Advisor Framework Architecture

**Version:** 2.2.0  
**Author:** Paulo Henrique Barreto Rebouças  
**Last Updated:** 2025-10-29

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Architectural Goals](#architectural-goals)
3. [Foundation: MQL5 Standard Library](#foundation-mql5-standard-library)
4. [Proposed Framework Architecture](#proposed-framework-architecture)
5. [Layer Details](#layer-details)
6. [Design Patterns](#design-patterns)
7. [Component Diagram](#component-diagram)
8. [Development Workflow](#development-workflow)
9. [Next Steps](#next-steps)

---

## Executive Summary

This document outlines the architecture for a modular, extensible, and testable Expert Advisor (EA) framework in MQL5. The framework leverages MQL5's object-oriented programming capabilities and Standard Library while adding structured layers for rapid strategy development, backtesting, and deployment.

### Key Objectives
- **Rapid Development**: Create new EAs quickly by reusing proven components
- **Simplicity**: Minimal abstraction layers - only extract what's truly reusable
- **Reusability**: Share risk management and state tracking across strategies
- **Maintainability**: Self-contained strategies with clear dependencies
- **Pragmatism**: Build only what's needed, avoid over-engineering

---

## Architectural Goals

### Primary Goals
1. **Self-Contained Strategies**: Each EA contains its signal logic and coordination code
2. **Reusable Components**: Extract only proven reusable parts (risk management, state tracking)
3. **Trade Library Foundation**: Build on CTrade, CPositionInfo, CSymbolInfo - avoid abstractions
4. **Evidence-Based Design**: Start simple, add complexity only when concrete needs arise
5. **Performance**: Minimize overhead, maximize clarity

### Design Principles
- **YAGNI** (You Aren't Gonna Need It): Don't build features until they're needed
- **Composition over Inheritance**: Strategies compose reusable components (HAS-A), but can inherit for strategy-specific variations (IS-A)
- **Single Responsibility**: Each component has one clear purpose
- **Progressive Enhancement**: Start minimal, grow as needs become clear

**Note on Composition vs Inheritance:**
- ✅ **Use Composition** for reusable components: `class MyEA { RiskManager* risk; StateManager* state; }`
- ✅ **Use Inheritance** for strategy variations: `class MyScalpEA : public BaseScalpEA`
- ❌ **Avoid Framework Inheritance**: Don't inherit from BaseEA/BaseStrategy to get bundled components
- Both patterns coexist! Compose components, inherit strategy-specific behavior when needed.

---

## Foundation: MQL5 Standard Library

### Available Standard Library Components

#### Expert Advisor Framework (\Include/Expert/\) — NOT RECOMMENDED
- **Note**: The `Expert` library (`CExpert`, `CExpertSignal`, `CExpertMoney`, `CExpertTrailing`) has reported stability and maintenance issues in the community. **We will not use these classes** in our framework.
- Historical reference only:
  - CExpert: Base EA class with event handling
  - CExpertSignal: Signal generation base (20+ indicator signals)
  - CExpertMoney: Money management (MoneyFixedLot, MoneyFixedRisk, MoneySizeOptimized)
  - CExpertTrailing: Trailing stops (TrailingFixedPips, TrailingMA, TrailingParabolicSAR)
  - CExpertTrade: Trade execution wrapper

#### Trading Classes (\Include/Trade/\) — RECOMMENDED FOUNDATION
- **CTrade**: Core trading operations (open, modify, close positions)
- **CPositionInfo**: Query position properties
- **COrderInfo**: Query order properties
- **CSymbolInfo**: Access symbol specifications
- **CAccountInfo**: Account information and balance
- **CTerminalInfo**: Terminal state and settings

#### Utility Classes
- **CIndicators**: Indicator collection management
- **CArrayObj**: Dynamic array of objects
- **CObject**: Base class for all objects
- **Strings/Arrays/Math**: Helper utilities

### Standard Library Strengths
 **Event-driven architecture**: Built-in event handlers  
 **Type safety**: Compile-time checks  
 **Trading abstractions**: Simplified order management  
 **Indicator integration**: Easy access to technical indicators  
 **Position management**: Automatic position tracking  

### What We Need to Build (Based on Real Needs)

#### Core Components (Essential)
 **Stop/Target Policy**: Pluggable SL/TP calculators (fixed distance, ATR-based, structure-based). Strategy can defer SL/TP to a policy, enabling A/B tests without touching signal logic.  
 **Risk Management**: Position sizing and risk validation (uses SL distance from the chosen Stop/Target policy or explicit strategy SL)  
 **State Management**: Order tracking, performance metrics (win rate, profit, drawdown), state persistence/recovery  
 **Trade Coordination**: Orchestrate signal → stop/tp policy → risk check → execution → state update workflow  

#### Supporting Components (Add As Needed)
 **Logging Framework**: Structured logging with levels (MQL5 only has Print()) - create Logger.mqh  
 **Backtest Utilities**: Walk-forward analysis, statistical tests (MetaTester has limitations) - add as placeholders  
 **Trailing Stop Management**: If multiple strategies need same trailing logic, extract to TrailingManager  
 **Optional Utilities**: Input validation, time helpers, etc.

**Note:** Performance monitoring (basic metrics) is included in StateManager. Advanced metrics (Sharpe, Sortino) can be added via PerformanceTracker extension.  

---

## Proposed Framework Architecture

### Simplified Component Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    MyScalpEA.mq5 (Strategy)                  │
│                                                              │
│  - Input parameters and configuration                        │
│  - OnInit/OnTick/OnDeinit event handlers                     │
│  - Signal calculation (embedded in strategy)                 │
│  - Returns: Signal{type, entry, sl?, tp?, metadata}          │
└───────────────────────────┬──────────────────────────────────┘
                │
                ▼
          ┌─────────────────────┐
          │  TradeCoordinator   │
          │                     │
          │  ProcessSignal()    │
          │  - Apply Stop/TP    │
          │  - Risk check       │
          │  - Execute trade    │
          │  - Update state     │
          └──────────┬──────────┘
                 │
        ┌────────────────┼────────────────┬────────────────┐
        │                │                │                │
        ▼                ▼                ▼                ▼
    ┌───────────────┐ ┌──────────────┐ ┌─────────────────┐ ┌─────────────────┐
    │ StopPolicy    │ │ RiskManager  │ │ StateManager    │ │ MQL5 CTrade     │
    │               │ │              │ │                 │ │                 │
    │ - Compute     │ │ - Calculate  │ │ - Track orders  │ │ - PositionOpen  │
    │   SL/TP       │ │   position   │ │ - Monitor perf  │ │ - PositionClose │
    │   (fixed/ATR/ │ │   size       │ │ - Persist state │ │ - Modify        │
    │   structure)  │ │ - Validate   │ │ - Recover       │ │                 │
    │               │ │   risk       │ │                 │ │ (Direct usage)  │
    └───────────────┘ └──────────────┘ └─────────────────┘ └─────────────────┘
     (Reusable)        (Reusable)         (Essential)        (Trade Library)
```

### Key Principles

1. **Strategy = EA File**: Each EA is self-contained with its own signal logic
2. **Reusable Components**: Extract stop/target policy, risk management, state tracking, and trade coordination
3. **Signal Coordination**: Separate "what to trade" (signal) from "how to trade" (stop/risk/exec/state)
4. **Direct Library Usage**: Use CTrade directly in coordinator, no execution wrapper
5. **Configurable SL/TP**: SL/TP determined by a pluggable Stop/Target Policy; strategy may override explicitly when needed
6. **No Framework Base Classes**: No BaseEA/BaseStrategy that bundle components
7. **Composition**: Strategies compose components (HAS-A), inherit for variations (IS-A) when needed

### Design Philosophy: Start Simple, Grow As Needed

**Foundation: Trade Library Only**

Build directly on the **`Trade` library** (`CTrade`, `CPositionInfo`, `COrderInfo`, `CSymbolInfo`, `CAccountInfo`). Avoid the `Expert` library (`CExpert`, `CExpertSignal`, `CExpertMoney`) due to reported stability issues.

**What We Extract:**
1. **Stop/Target Policy** (reusable): Compute initial SL/TP using chosen method (fixed/ATR/structure)
2. **Risk Management** (reusable): Position sizing, risk validation, exposure checks
3. **State Management** (essential): Order tracking, performance metrics, persistence
4. **Utilities** (optional): Logger, validator helpers as needed

**What Stays in Each EA:**
- Signal calculation logic (unique per strategy)
- Entry/exit decision rules
- Strategy-specific parameters
- Event handlers (OnInit, OnTick, OnDeinit)
- Optional: Explicit SL/TP override (otherwise delegated to Stop/Target policy)

**When to Add Abstractions:**
Only create wrappers/abstractions when you have:
- ✅ At least 2-3 strategies needing the same functionality
- ✅ Clear evidence of code duplication
- ✅ Concrete operational requirement (not hypothetical)

**When to Use CTrade Directly:**
- ✅ Opening/closing/modifying positions
- ✅ Setting magic number, deviation, filling mode
- ✅ All standard trading operations

Add execution wrappers only for specific needs: retry logic, broker quirks, partial close patterns.### File Structure (Simplified)

```
MQL5/
├── Experts/
│   └── Main/
│       ├── MyScalpEA.mq5             # Self-contained strategy
│       ├── MyTrendEA.mq5             # Another strategy
│       ├── Architecture.md           # This document
│       │
│       └── Framework/                # Custom framework (separate from MQL5 libs)
│           ├── Coordination/
│           │   ├── TradeCoordinator.mqh    # Signal processing orchestration
│           │   └── Signal.mqh              # Signal structure definition
│           │
│           ├── Risk/
│           │   ├── IRiskManager.mqh        # Risk interface
│           │   ├── FixedRiskManager.mqh    # Fixed % per trade
│           │   ├── VolatilityRiskManager.mqh  # ATR-based (placeholder)
│           │   ├── DrawdownRiskManager.mqh    # Reduce after losses (placeholder)
│           │   ├── ExposureManager.mqh        # Portfolio limits (placeholder)
│           │   └── DailyLossLimitManager.mqh  # Daily loss cap (placeholder)
│           │
│           ├── Stops/
│           │   ├── IStopPolicy.mqh          # SL/TP policy interface
│           │   ├── FixedSLTP.mqh            # Fixed pip/points SL/TP (placeholder)
│           │   ├── ATRSLTP.mqh              # ATR-based SL/TP (placeholder)
│           │   └── StructureSLTP.mqh        # Swing high/low, FVG, etc. (placeholder)
│           │
│           ├── State/
│           │   ├── StateManager.mqh        # Order tracking & persistence (no interface needed)
│           │   └── PerformanceTracker.mqh  # Advanced metrics (optional)
│           │
│           ├── Trailing/
│           │   └── TrailingManager.mqh     # Extract if needed by multiple strategies
│           │
│           ├── Backtesting/
│           │   ├── WalkForwardAnalyzer.mqh # Walk-forward testing (placeholder)
│           │   └── StatisticalTests.mqh    # Overfitting tests (placeholder)
│           │
│           └── Utils/
│               ├── Logger.mqh              # Structured logging
│               └── Validator.mqh           # Input validation
│
├── Include/
│   └── Trade/                        # MQL5 Standard Library (use directly)
│       ├── Trade.mqh
│       ├── PositionInfo.mqh
│       ├── OrderInfo.mqh
│       ├── SymbolInfo.mqh
│       └── AccountInfo.mqh
│
└── Backtests/                        # Backtest results and analysis
    └── ...
```

**Key Structural Decisions:**
- ✅ **Framework in Experts/Main/**: Separates custom code from MQL5 standard library
- ✅ **Coordination/**: New - orchestrates signal processing workflow
- ✅ **Risk/**: Multiple implementations documented (most as placeholders)
- ✅ **State/**: No interface initially (add if multiple implementations needed)
- ✅ **Trailing/**: Extract trailing logic only if shared across strategies
- ✅ **Backtesting/**: Placeholders for walk-forward and statistical tests
- ✅ **Relative includes**: `#include "Framework/Risk/FixedRiskManager.mqh"` (not `<Framework/...>`)

---

## Component Details

### 1. Strategy (EA File)

**Purpose**: Self-contained trading logic in each EA .mq5 file.

#### Structure

Each EA contains:
- **Input parameters**: Risk %, magic number, strategy settings
- **Event handlers**: OnInit(), OnTick(), OnDeinit()
- **Signal calculation**: Entry/exit logic embedded in the EA
- **Component initialization**: Create risk manager, state manager instances
- **Trade coordination**: Call risk checks, execute via CTrade, update state

#### Example Structure (With TradeCoordinator)

```cpp
// MyScalpEA.mq5
#property copyright "Paulo Henrique Barreto Rebouças"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include "Framework/Coordination/TradeCoordinator.mqh"
#include "Framework/Coordination/Signal.mqh"
#include "Framework/Risk/FixedRiskManager.mqh"
#include "Framework/State/StateManager.mqh"

// Input parameters
input double RiskPercent = 2.0;
input int MagicNumber = 123456;

// Components
CSymbolInfo symbol;
TradeCoordinator* coordinator;

int OnInit() {
    symbol.Name(Symbol());
    
    // Initialize coordinator with dependencies
    FixedRiskManager* riskMgr = new FixedRiskManager(RiskPercent);
    StateManager* stateMgr = new StateManager(MagicNumber);
    stateMgr.LoadState(); // Recover from disconnection
    
    coordinator = new TradeCoordinator(MagicNumber, riskMgr, stateMgr);
    
    return INIT_SUCCEEDED;
}

void OnTick() {
    // 1. Calculate signals (embedded in strategy)
    Signal buySignal = CheckBuyConditions();
    
    // 2. Coordinator handles everything else (stop/tp policy, risk, execution, state)
    if(buySignal.IsValid()) {
        coordinator.ProcessSignal(buySignal);
    }
    
    // 3. Update state (periodic metrics refresh)
    coordinator.Update();
}

void OnDeinit(const int reason) {
    delete coordinator; // Cleans up all components
}

// Signal calculation methods (unique to this strategy)
Signal CheckBuyConditions() {
    // Your strategy logic here
    if(/* buy conditions met */) {
        Signal signal;
        signal.type = SIGNAL_BUY;
        signal.entry = symbol.Ask();
        // Optionally set explicit SL/TP here; otherwise StopPolicy will compute
        // signal.stopLoss = CalculateStopLoss();
        // signal.takeProfit = CalculateTakeProfit();
        signal.comment = "FVG Buy Signal";
        return signal;
    }
    return Signal(); // Invalid signal
}

double CalculateStopLoss() {
    // Your SL logic (strategy-specific)
    return symbol.Ask() - 100 * symbol.Point();
}

double CalculateTakeProfit() {
    // Your TP logic (strategy-specific)
    return symbol.Ask() + 200 * symbol.Point();
}
```

#### Responsibilities
 ✅ Manage input parameters and configuration  
 ✅ Calculate entry/exit signals (strategy-specific logic)  
 ✅ Optionally set explicit SL/TP; otherwise rely on Stop/Target Policy  
 ✅ Delegate coordination to TradeCoordinator  
 ✅ Handle event lifecycle (init, tick, deinit)  
 ✅ Implement trailing stops if needed (via CTrade.PositionModify)  
 ❌ Does NOT handle risk calculations (RiskManager's job)  
 ❌ Does NOT execute trades directly (TradeCoordinator's job)  
 ❌ Does NOT track performance (StateManager's job)  

---

### 2. Trade Coordination Component (Reusable)

**Purpose**: Orchestrate signal processing - separate "what to trade" from "how to trade".

#### Why This Component?

The pattern `signal → risk check → execution → state update` is identical across all strategies. Extract this coordination logic so EAs only focus on signal generation.

#### Core Classes

**Signal Structure**
```cpp
// Framework/Coordination/Signal.mqh
struct Signal
{
    ENUM_ORDER_TYPE type;      // ORDER_TYPE_BUY, ORDER_TYPE_SELL, or none
    double entry;              // Entry price
    double stopLoss;           // Stop loss price
    double takeProfit;         // Take profit price
    string comment;            // Signal description
    
    bool IsValid() { return type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL; }
    
    Signal() : type(ORDER_TYPE_BUY), entry(0), stopLoss(0), takeProfit(0), comment("") {}
};
```

**TradeCoordinator**
```cpp
// Framework/Coordination/TradeCoordinator.mqh
class TradeCoordinator
{
private:
    int m_magicNumber;
    CTrade m_trade;
    CSymbolInfo m_symbol;
    IRiskManager* m_riskManager;
    StateManager* m_stateManager;
    
public:
    TradeCoordinator(int magicNumber, IRiskManager* risk, StateManager* state) {
        m_magicNumber = magicNumber;
        m_riskManager = risk;
        m_stateManager = state;
        m_trade.SetExpertMagicNumber(magicNumber);
        m_symbol.Name(Symbol());
    }
    
    ~TradeCoordinator() {
        delete m_riskManager;
        delete m_stateManager;
    }
    
    // Main coordination method
    bool ProcessSignal(const Signal& signal) {
        if(!signal.IsValid()) return false;
        
        // 1. Ensure SL/TP present via StopPolicy when not explicitly set
        //    (policy selection is configured on coordinator init)
        
        // 2. Risk check
        if(!m_riskManager.CanOpenPosition()) {
            Print("Risk manager blocked trade");
            return false;
        }
        
        // 3. Calculate position size (uses SL distance)
        double volume = m_riskManager.CalculatePositionSize(signal.entry, signal.stopLoss);
        if(volume == 0) {
            Print("Invalid position size calculated");
            return false;
        }
        
        // 4. Execute trade
        bool success = m_trade.PositionOpen(
            Symbol(), 
            signal.type, 
            volume,
            signal.entry, 
            signal.stopLoss, 
            signal.takeProfit, 
            signal.comment
        );
        
        // 5. Track state
        if(success) {
            m_stateManager.TrackTrade(m_trade.ResultOrder(), signal.type, volume);
            m_stateManager.SaveState(); // Persist immediately
        }
        
        return success;
    }
    
    // Periodic state update
    void Update() {
        m_stateManager.Update();
    }
};
```

#### Benefits

✅ **Separation of Concerns**: Strategy generates signals, stop policy sets SL/TP, coordinator handles risk/execution/state  
✅ **Reusability**: Same coordination logic across all strategies  
✅ **Testability**: Can test signal generation without execution  
✅ **Cleaner EAs**: Strategy code focuses on "what" not "how"  
✅ **Single Point of Change**: Modify execution workflow in one place

#### Responsibilities
 ✅ Process signals from strategies  
 ✅ Ensure SL/TP are applied via Stop/Target Policy when not explicitly set  
 ✅ Call risk manager for validation and position sizing  
 ✅ Execute trades via CTrade  
 ✅ Update state manager with trade info  
 ✅ Persist state after each trade  
 ❌ Does NOT generate signals (Strategy's job)  

---

### 3. Stop/Target Policy Component (Reusable)

**Purpose**: Calculate initial SL/TP from market context with swappable policies.

**Why Separate It?**
- Backtest the same signal logic with different SL/TP definitions (fixed vs ATR vs structure)  
- Reuse across strategies and standardize validation (min stops, distance checks)  
- Keep RiskManager focused on sizing; it consumes SL distance, not compute it  

#### Interface (illustrative)

```cpp
// Framework/Stops/IStopPolicy.mqh
class IStopPolicy
{
public:
    // Returns true if it could compute valid SL/TP for the given symbol/signal
    virtual bool Compute(const string symbol, const Signal &inSignal, double &outSL, double &outTP) = 0;
};
```

#### Example Policies (placeholders)
- FixedSLTP: fixed pip/points distance, optional RR-based target
- ATRSLTP: multiples of ATR for SL, TP via RR or ATR multiplier
- StructureSLTP: recent swing high/low; FVG/imbalance bounds

#### Responsibilities
 ✅ Compute initial SL/TP based on configured method  
 ✅ Enforce broker constraints (min stop distance, normalization)  
 ✅ Leave trailing/adjustments to TrailingManager or strategy  
 ❌ Does NOT size positions (RiskManager)  
 ❌ Does NOT execute trades (Coordinator/CTrade)  

---

### 4. Risk Management Component (Reusable)

**Purpose**: Calculate position sizing and validate risk - shared across strategies.

**Important Clarification:**
- ✅ RiskManager calculates **position SIZE** (volume/lots)
- ❌ RiskManager does **NOT** calculate or place SL/TP levels (that’s Stop/Target Policy or explicit strategy override)
- ❌ RiskManager does **NOT** handle trailing stops (implement in EA via CTrade.PositionModify or a TrailingManager)
- RiskManager uses SL distance (provided by Stop/Target Policy or by strategy) to determine safe position size

#### Interface

```cpp
// Framework/Risk/IRiskManager.mqh
class IRiskManager
{
public:
    virtual double CalculatePositionSize(double entryPrice, double stopLoss) = 0;
    virtual bool CanOpenPosition() = 0;
    virtual bool ValidateRisk(double positionSize, double stopLoss) = 0;
};
```

#### Implementations

**FixedRiskManager** (Start here)
```cpp
// Framework/Risk/FixedRiskManager.mqh
class FixedRiskManager : public IRiskManager
{
private:
    double m_riskPercent;  // % of account to risk per trade
    
public:
    FixedRiskManager(double riskPercent) : m_riskPercent(riskPercent) {}
    
    virtual double CalculatePositionSize(double entryPrice, double stopLoss) override {
        CAccountInfo account;
        CSymbolInfo symbol;
        symbol.Name(Symbol());
        
        double riskMoney = account.Balance() * (m_riskPercent / 100.0);
        double slDistance = MathAbs(entryPrice - stopLoss);
        double tickValue = symbol.TickValue();
        double tickSize = symbol.TickSize();
        
        double lots = (riskMoney / slDistance) * tickSize / tickValue;
        
        // Normalize to lot step
        lots = MathFloor(lots / symbol.LotsStep()) * symbol.LotsStep();
        lots = MathMax(symbol.LotsMin(), MathMin(symbol.LotsMax(), lots));
        
        return lots;
    }
    
    virtual bool CanOpenPosition() override {
        // Check exposure limits, drawdown, etc.
        return true; // Implement checks as needed
    }
};
```

#### Additional Implementations (Placeholders - Add When Needed)

**VolatilityRiskManager** (Phase 2+)
- ATR-based position sizing
- Adjust risk based on market volatility
- Increase size in low volatility, reduce in high volatility

**DrawdownRiskManager** (Phase 2+)
- Reduce position size after consecutive losses
- Scale back during drawdown periods
- Gradual recovery as equity rebounds

**ExposureManager** (Phase 3+)
- Portfolio-wide exposure limits
- Prevent over-concentration in single instrument
- Manage aggregate risk across multiple EAs

**DailyLossLimitManager** (Phase 2+)
- Maximum daily/weekly loss caps
- Stop trading after hitting limit
- Resume next period

**TimeBasedRiskManager** (Phase 3+)
- Reduce risk during high-impact news events
- Time-of-day adjustments (lower risk during low liquidity)
- Session-based risk scaling

**CorrelationManager** (Phase 4+)
- Prevent correlated positions across pairs
- Analyze correlation matrix
- Block trades that increase correlation risk

#### When to Implement
Add features only when you have concrete needs:
- ✅ Multiple strategies need same risk logic → Extract to manager
- ✅ Portfolio-level constraints required → Implement ExposureManager
- ✅ Drawdown protection needed → Create DrawdownRiskManager
- ❌ Don't build in anticipation → Wait for real need

#### Responsibilities
 ✅ Calculate position size (volume/lots) based on risk parameters  
 ✅ Validate trade risk before execution  
 ✅ Check exposure limits and constraints  
 ❌ Does NOT calculate SL/TP levels (Strategy's job)  
 ❌ Does NOT place SL/TP orders (CTrade's job via coordinator)  
 ❌ Does NOT handle trailing stops (Strategy's job)  
 ❌ Does NOT execute trades (TradeCoordinator's job)  
 ❌ Does NOT track performance (StateManager's job)  

---

### 5. State Management Component (Essential)

**Purpose**: Track orders, monitor performance, persist state for recovery.

**Note on Interfaces:** StateManager does not have an interface (IStateManager) initially because we expect only one implementation. Interfaces are for polymorphism - when you need multiple implementations. Add IStateManager only if you need different storage backends (file vs database) or different metric calculations. Start simple.

#### Why This Is Essential

1. **Recovery from Disconnections**: MT5 freezes, crashes, and network issues happen
2. **Order Tracking**: Know which positions belong to this EA (via magic number)
3. **Performance Monitoring**: Detect strategy degradation early
4. **Post-Mortem Analysis**: Understand what worked and what didn't

#### Core Class

```cpp
// Framework/State/StateManager.mqh
class StateManager
{
private:
    int m_magicNumber;
    string m_stateFile;
    
    // Performance metrics
    double m_totalProfit;
    int m_totalTrades;
    int m_winningTrades;
    double m_maxDrawdown;
    
public:
    StateManager(int magicNumber) : m_magicNumber(magicNumber) {
        m_stateFile = "state_" + IntegerToString(magicNumber) + ".dat";
    }
    
    // Track new trade
    void TrackTrade(ulong ticket, ENUM_ORDER_TYPE type, double volume) {
        // Record trade details
        // Update counters
    }
    
    // Update metrics on each tick
    void Update() {
        // Scan open positions with our magic number
        // Calculate current P&L, drawdown, etc.
        // Update performance metrics
    }
    
    // Persist state to file
    void SaveState() {
        int handle = FileOpen(m_stateFile, FILE_WRITE|FILE_BIN);
        if(handle != INVALID_HANDLE) {
            FileWriteInteger(handle, m_totalTrades);
            FileWriteInteger(handle, m_winningTrades);
            FileWriteDouble(handle, m_totalProfit);
            FileWriteDouble(handle, m_maxDrawdown);
            FileClose(handle);
        }
    }
    
    // Recover state from file
    void LoadState() {
        int handle = FileOpen(m_stateFile, FILE_READ|FILE_BIN);
        if(handle != INVALID_HANDLE) {
            m_totalTrades = FileReadInteger(handle);
            m_winningTrades = FileReadInteger(handle);
            m_totalProfit = FileReadDouble(handle);
            m_maxDrawdown = FileReadDouble(handle);
            FileClose(handle);
        }
    }
    
    // Query performance
    double GetWinRate() { 
        return m_totalTrades > 0 ? (double)m_winningTrades / m_totalTrades : 0.0; 
    }
    double GetTotalProfit() { return m_totalProfit; }
    double GetMaxDrawdown() { return m_maxDrawdown; }
};
```

#### Optional Enhancement: PerformanceTracker

Add detailed metrics as needed:
- Profit factor
- Sharpe ratio, Sortino ratio
- Average win/loss
- Maximum consecutive losses
- Trade duration statistics

#### Responsibilities
 ✅ Track orders opened by this EA (via magic number)  
 ✅ Calculate performance metrics (win rate, profit, drawdown)  
 ✅ Persist state to file (SaveState/LoadState)  
 ✅ Recover from disconnections and crashes  
 ❌ Does NOT execute trades (CTrade's job)  
 ❌ Does NOT calculate position size (RiskManager's job)  

---

### 6. Utility Helpers (Optional - Add As Needed)

**Purpose**: Common helpers - not a "layer", just reusable functions.

#### When to Add Utilities

Start with `Print()` and add utilities only when:
- ✅ Same code appears in 2+ strategies
- ✅ Code improves readability significantly
- ✅ Helper has clear, focused purpose

#### Example Utilities

**Logger** (add if you need structured logging)
```cpp
// Framework/Utils/Logger.mqh
class Logger
{
public:
    static void Info(string message) {
        Print("[INFO] ", TimeToString(TimeCurrent()), " - ", message);
    }
    
    static void Error(string message) {
        Print("[ERROR] ", TimeToString(TimeCurrent()), " - ", message);
    }
};
```

**Validator** (add if you need input validation)
```cpp
// Framework/Utils/Validator.mqh
class Validator
{
public:
    static bool ValidateRiskPercent(double risk) {
        if(risk <= 0 || risk > 10) {
            Print("Invalid risk percent: ", risk);
            return false;
        }
        return true;
    }
};
```

#### Standard Library Alternatives

Before creating utilities, check if MQL5 already provides:
- **Time functions**: `TimeCurrent()`, `TimeToString()`, `iTime()`
- **Math functions**: `MathAbs()`, `MathMax()`, `MathMin()`, `MathRound()`
- **String functions**: `StringFormat()`, `StringFind()`, `StringSubstr()`
- **Array functions**: `ArrayResize()`, `ArraySort()`, `ArrayBsearch()`

#### Principle
Use existing MQL5 functions first, create utilities only for repeated patterns.  

---

## Data Flow & Integration

### How Components Work Together

```
OnTick() Event
    │
    ├─> 1. Generate Signal (in EA)
    │       - Check indicators (iMA, iRSI, custom logic)
    │       - Evaluate entry conditions
    │       - Optionally set explicit SL/TP
    │       - Return: Signal{type, entry, sl?, tp?, comment}
    │
    └─> 2. TradeCoordinator.ProcessSignal(signal)
        │
        ├─> 2a. StopPolicy.Compute()
        │       - If signal lacks SL/TP, compute via configured policy
        │       - Enforce min stop distance and normalization
        │       - Return: sl/tp values
        │
        ├─> 2b. RiskManager.CanOpenPosition()
        │       - Check exposure limits
        │       - Check drawdown constraints
        │       - Return: true/false
        │
        ├─> 2c. RiskManager.CalculatePositionSize(entry, sl)
        │       - Calculate risk money (balance * risk%)
        │       - Calculate lots based on SL distance
        │       - Normalize to lot step
        │       - Return: volume (lots)
        │
        ├─> 2d. CTrade.PositionOpen(...)
        │       - Execute market order
        │       - Apply filling mode, deviation, magic
        │       - Return: success/failure + ticket
        │
        └─> 2e. StateManager.TrackTrade(ticket, type, volume)
            - Record trade details
            - Update metrics (profit, win rate, drawdown)
            - SaveState() → persist to file
```

### Interaction Example (With TradeCoordinator)

```cpp
void OnTick() {
    // 1. Signal generation (embedded in strategy)
    Signal signal = GenerateBuySignal();
    
    // 2. Coordinator handles everything else
    if(signal.IsValid()) {
        coordinator.ProcessSignal(signal);
    }
    
    // 3. Periodic state update
    coordinator.Update();
}

Signal GenerateBuySignal() {
    // Check conditions
    double ma50 = iMA(Symbol(), PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
    double ma200 = iMA(Symbol(), PERIOD_CURRENT, 200, 0, MODE_SMA, PRICE_CLOSE);
    double rsi = iRSI(Symbol(), PERIOD_CURRENT, 14, PRICE_CLOSE);
    
    if(ma50 > ma200 && rsi < 30) {
        Signal signal;
        signal.type = ORDER_TYPE_BUY;
        signal.entry = symbol.Ask();
        // Optionally set explicit SL/TP; otherwise StopPolicy will compute
        signal.comment = "MA Cross + RSI Oversold";
        return signal;
    }
    
    return Signal(); // Invalid
}
```

**Key Benefits:**
- EA code is clean: just signal logic
- Coordination logic is reusable; SL/TP are swappable policies
- Easy to test signals without execution
- Single point to modify execution workflow

### Design Patterns Used

**Composition**: Strategies compose risk manager and state manager
- Simple, clear dependencies
- Easy to test components independently

**Interface-Based Design**: IRiskManager allows multiple implementations
- FixedRiskManager, VolatilityRiskManager, etc.
- Swap implementations without changing strategy code

**YAGNI Principle**: Avoid patterns that aren't needed yet
- ❌ No Factory (just instantiate directly)
- ❌ No Observer (just call methods)
- ❌ No Decorator (extend when needed)

---

## Visual Architecture

### Component Relationships

```
┌────────────────────────────────────────────────────────────┐
│                    MyScalpEA.mq5                           │
│                  (Self-Contained Strategy)                 │
│                                                            │
│  ┌──────────────────────────────────────────────────┐     │
│  │ OnInit():                                        │     │
│  │  - Initialize CTrade, CPositionInfo, CSymbolInfo │     │
│  │  - Create StopPolicy (choose implementation)     │     │
│  │  - Create RiskManager                            │     │
│  │  - Create StateManager, LoadState()              │     │
│  └──────────────────────────────────────────────────┘     │
│                                                            │
│  ┌──────────────────────────────────────────────────┐     │
│  │ OnTick():                                        │     │
│  │  1. Calculate signals (embedded logic)           │     │
│  │  2. If SL/TP missing → StopPolicy.Compute()      │     │
│  │  3. Check RiskManager.CanOpenPosition()          │     │
│  │  4. Call RiskManager.CalculatePositionSize()     │     │
│  │  5. Execute via CTrade.PositionOpen()            │     │
│  │  6. Update StateManager.TrackTrade()             │     │
│  └──────────────────────────────────────────────────┘     │
│                                                            │
│  ┌──────────────────────────────────────────────────┐     │
│  │ OnDeinit():                                      │     │
│  │  - StateManager.SaveState()                      │     │
│  │  - Cleanup                                       │     │
│  └──────────────────────────────────────────────────┘     │
└──────────┬────────────────┬────────────────┬────────────────┬──────────────┘
         │                │                │                │
         │ uses           │ uses           │ uses           │ uses
         ▼                ▼                ▼                ▼
  ┌────────────────┐ ┌────────────────┐ ┌─────────────┐ ┌────────────────┐
  │ StopPolicy     │ │ RiskManager    │ │ StateManager│ │ MQL5 CTrade    │
  │ (Fixed/ATR/    │ │ FixedRisk      │ │ - TrackTrade│ │ - PositionOpen │
  │  Structure)    │ │ Volatility     │ │ - Metrics   │ │ - PositionClose│
  │ - Compute SLTP │ │ Drawdown       │ │ - SaveState │ │ - Modify       │
  └────────────────┘ └────────────────┘ │ - LoadState │ └────────────────┘
      (Reusable)         (Reusable)    └─────────────┘    (Trade Library)
```

### Separation of Concerns

| Component | Responsibility | Location |
|-----------|----------------|----------|
| **Strategy (EA file)** | Signal calculation, coordination, inputs | `Experts/Main/MyEA.mq5` |
| **StopPolicy** | SL/TP calculation (policy-based) | `Experts/Main/Framework/Stops/` |
| **RiskManager** | Position sizing, exposure limits | `Experts/Main/Framework/Risk/` |
| **StateManager** | Order tracking, metrics, persistence | `Experts/Main/Framework/State/` |
| **CTrade** | Trade execution | `Include/Trade/` (MQL5 std lib) |
| **Utils** | Optional helpers (logger, validator) | `Experts/Main/Framework/Utils/` |

---

## Development Workflow

### Creating a New Strategy (Step by Step)

#### Step 1: Create Self-Contained EA

Start with a complete EA file - no framework yet:

```cpp
// MyScalpEA.mq5
#property copyright "Paulo Henrique Barreto Rebouças"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/SymbolInfo.mqh>

input double RiskPercent = 2.0;
input int MagicNumber = 123456;

CTrade trade;
CPositionInfo position;
CSymbolInfo symbol;

int OnInit() {
    trade.SetExpertMagicNumber(MagicNumber);
    symbol.Name(Symbol());
    return INIT_SUCCEEDED;
}

void OnTick() {
    // Your signal logic here
    bool buySignal = CheckBuyConditions();
    
    if(buySignal) {
        double sl = CalculateStopLoss();
        double tp = CalculateTakeProfit();
        double volume = CalculatePositionSize(symbol.Ask(), sl);
        
        trade.PositionOpen(Symbol(), ORDER_TYPE_BUY, volume,
                          symbol.Ask(), sl, tp, "Buy");
    }
}

bool CheckBuyConditions() {
    // Your entry logic
    return false;
}

double CalculateStopLoss() {
    // Your SL logic
    return symbol.Ask() - 100 * symbol.Point();
}

double CalculateTakeProfit() {
    // Your TP logic
    return symbol.Ask() + 200 * symbol.Point();
}

double CalculatePositionSize(double entry, double sl) {
    // Simple fixed risk calculation
    CAccountInfo account;
    double riskMoney = account.Balance() * (RiskPercent / 100.0);
    double slDistance = MathAbs(entry - sl);
    double lots = (riskMoney / slDistance) * symbol.TickSize() / symbol.TickValue();
    return MathMax(symbol.LotsMin(), MathMin(symbol.LotsMax(), lots));
}

void OnDeinit(const int reason) {
    // Cleanup
}
```

#### Step 2: Test and Identify Reusable Parts

- Backtest the strategy
- Identify what could be shared across strategies:
  - ✅ CalculatePositionSize → Extract to RiskManager
  - ✅ Performance tracking → Extract to StateManager
  - ❌ CheckBuyConditions → Keep in EA (unique per strategy)

#### Step 3: Extract Stop/Target Policy and Risk Management

```cpp
// Now use Framework/Stops/IStopPolicy.mqh and Framework/Risk/FixedRiskManager.mqh
#include <Trade/Trade.mqh>
#include <Framework/Stops/IStopPolicy.mqh>
#include <Framework/Risk/FixedRiskManager.mqh>

IStopPolicy* stopPolicy; // e.g., new FixedSLTP(...)
FixedRiskManager* riskMgr;

int OnInit() {
    trade.SetExpertMagicNumber(MagicNumber);
    symbol.Name(Symbol());
    stopPolicy = /* choose */ NULL;               // Extract SL/TP logic (Fixed/ATR)
    riskMgr = new FixedRiskManager(RiskPercent);  // Extract risk logic
    return INIT_SUCCEEDED;
}

void OnTick() {
    bool buySignal = CheckBuyConditions();
    
    if(buySignal && riskMgr.CanOpenPosition()) {
        double sl, tp;
        // Use StopPolicy when strategy doesn't set explicit SL/TP
        // stopPolicy.Compute(Symbol(), buySignal, sl, tp);
        double volume = riskMgr.CalculatePositionSize(symbol.Ask(), sl);  // Use manager
        // ... rest of code
    }
}
```

#### Step 4: Add State Management

```cpp
#include <Framework/State/StateManager.mqh>

StateManager* stateMgr;

int OnInit() {
    // ... previous code ...
    stateMgr = new StateManager(MagicNumber);
    stateMgr.LoadState();  // Recover from crashes
    return INIT_SUCCEEDED;
}

void OnTick() {
    if(buySignal && riskMgr.CanOpenPosition()) {
        // ... execute trade ...
        if(trade.PositionOpen(...)) {
            stateMgr.TrackTrade(trade.ResultOrder(), ORDER_TYPE_BUY, volume);
        }
    }
    
    stateMgr.Update();  // Update metrics
}

void OnDeinit(const int reason) {
    stateMgr.SaveState();  // Persist for recovery
    delete riskMgr;
    delete stateMgr;
}
```

#### Step 5: Iterate

Build second strategy, extract more shared components only if needed.

---

## Implementation Roadmap

### Phase 0: Proof of Concept (Start Here)
**Goal**: Validate the approach with one complete strategy

1.  **Pick One Existing EA** (e.g., `fvg.mq5` or `BreakoutH1.mq5`)
2.  **Identify Reusable Parts**
   - Position sizing logic → candidate for RiskManager
   - Performance tracking → candidate for StateManager
3.  **Document What's Actually Needed**
   - Don't build abstractions yet, just note patterns
4.  **Validate Strategy Works**
   - Backtest, verify results match original
   - Deploy to demo, ensure stability

**Success Criteria**: One working EA without framework dependencies

---

### Phase 1: Extract Core Components (Build Only What's Proven)
**Goal**: Create reusable components based on Phase 0 learnings

1.  **Create Framework Structure**
   ```
   Experts/Main/Framework/
   ├── Coordination/
   │   ├── Signal.mqh
   │   └── TradeCoordinator.mqh
   ├── Stops/
   │   ├── IStopPolicy.mqh
   │   ├── FixedSLTP.mqh          # placeholder
   │   └── ATRSLTP.mqh            # placeholder
   ├── Risk/
   │   ├── IRiskManager.mqh
   │   └── FixedRiskManager.mqh
   └── State/
       └── StateManager.mqh
   ```

2.  **Implement Core Components**
    - **Signal.mqh**: Signal structure definition
    - **Stop/Target Policy**: FixedSLTP and ATRSLTP as minimal options for SL/TP
    - **FixedRiskManager**: Extract position sizing from Phase 0
    - **StateManager**: Extract tracking/persistence from Phase 0
    - **TradeCoordinator**: Orchestrate StopPolicy → Risk → Execution → State

3.  **Create Base Strategy Template**
   - `Experts/Main/_StrategyTemplate.mq5`
   - Includes: Input parameters, component initialization, signal stubs
   - Copy and customize for new strategies
   - Well-commented with TODOs for customization points

4.  **Refactor Phase 0 EA**
   - Replace inline code with framework components
   - Use TradeCoordinator for signal processing
   - Verify backtest results unchanged
   - Deploy to demo, verify behavior matches

**Success Criteria**: One EA using framework components; ability to toggle SL/TP policies without changing signal code; results unchanged aside from expected SL/TP variants

---

### Phase 2: Add Supporting Components (Progressive Enhancement)
**Goal**: Add logging and utilities as needed

1.  **Implement Logger**
   ```
   Experts/Main/Framework/
   └── Utils/
       └── Logger.mqh    # Structured logging with levels
   ```
   - Info(), Warning(), Error() methods
   - Timestamp and level prefixes
   - Configurable log levels

2.  **Add to Framework Template**
   - Update `_StrategyTemplate.mq5` to include Logger
   - Add logging examples for common scenarios
   - Document when to log vs Print()

3.  **Optional: Trailing Stop Manager**
   - Only if second strategy needs same trailing logic
   - Extract to `Framework/Trailing/TrailingManager.mqh`
   - Otherwise, keep trailing in EA file

**Success Criteria**: Logger available for use, template updated

---

### Phase 3: Port Second Strategy (Validate Reusability)
**Goal**: Prove components are actually reusable

1.  **Pick Second EA** (different strategy type)
2.  **Use Existing Components**
   - FixedRiskManager (or add VolatilityRiskManager if needed)
   - StateManager (should work as-is)
3.  **Identify Gaps**
   - What's missing?
   - What needs to be extended?
4.  **Refine Framework**
   - Add features only if second strategy needs them
   - Keep first strategy working (regression test)

**Success Criteria**: Two EAs sharing Risk + State components, both working

---

### Phase 4: Backtesting Enhancements (Add Placeholders)
**Goal**: Document future backtesting capabilities

1.  **Create Placeholder Files**
   ```
   Experts/Main/Framework/
   └── Backtesting/
       ├── WalkForwardAnalyzer.mqh    # TODO: Implement walk-forward
       └── StatisticalTests.mqh        # TODO: Overfitting detection
   ```

2.  **Document Planned Features**
   - Walk-forward analysis workflow
   - Statistical significance tests
   - Overfitting detection methods
   - Integration with existing backtest data

3.  **Add Backtest Helper Methods**
   - Export results to CSV for analysis
   - Compare in-sample vs out-of-sample
   - Calculate degradation metrics

**Rule**: Add implementation when MetaTester limitations become blockers

---

### Phase 5: Advanced Features (Future - When Needed)
Only add when you have concrete requirements:
- VolatilityRiskManager (ATR-based sizing)
- DrawdownManager (reduce size after losses)
- Multi-strategy coordination
- Portfolio-level exposure management
- Advanced metrics (Sharpe, Sortino)

**Principle**: Build when needed, not in anticipation

---

## Success Criteria

### Development Speed
-  Create new EA in < 30 minutes
-  Modify existing strategy in < 15 minutes

### Code Quality
-  80%+ code reusability across EAs
-  < 100 lines per strategy implementation
-  Clear separation of concerns

### Performance
-  < 5ms per tick processing overhead
-  Minimal memory footprint

### Testability
-  Unit testable components
-  Backtestable strategies
-  Reproducible results

---

## Frequently Asked Questions

### Q: Composition vs Inheritance - Can I still use inheritance for strategy variations?

**A: Yes! Both patterns coexist:**
- **Composition** for reusable components: `class MyEA { RiskManager* risk; StateManager* state; }` ✅
- **Inheritance** for strategy variations: `class MyScalpEA : public BaseScalpEA` ✅
- **Avoid** framework inheritance: `class MyEA : public FrameworkEA` (bundles unwanted components) ❌

**Example:**
```cpp
// GOOD: Inherit for strategy-specific variations
class BaseFVGStrategy {
    virtual double CalculateFVGThreshold() = 0;
};

class AggressiveFVG : public BaseFVGStrategy {
    double CalculateFVGThreshold() override { return 0.5; }
};

class ConservativeFVG : public BaseFVGStrategy {
    double CalculateFVGThreshold() override { return 1.0; }
};
```

### Q: Should Risk/Signal/Coordination be separate files or in one file?

**A: Depends on reusability:**
- **Risk Management**: Separate class (reusable across strategies)
- **Signals**: Embedded in EA file (unique per strategy)
- **Coordination**: Separate class (reusable across strategies)
- **Execution**: Use CTrade directly via coordinator (no wrapper)

### Q: Does RiskManager handle SL/TP placement and trailing stops?

**A: Now handled by a dedicated Stop/Target Policy:**
- **StopPolicy**: Calculates initial SL/TP levels (fixed/ATR/structure)
- **Strategy**: May override SL/TP explicitly if desired for special cases
- **RiskManager**: Calculates position SIZE using SL distance
- **TradeCoordinator**: Places trades with SL/TP via CTrade
- **Trailing Stops**: Implement in EA's OnTick() via CTrade.PositionModify() or extract to TrailingManager if shared

Extract trailing logic to TrailingManager only if multiple strategies need the same trailing pattern.

### Q: What's the data flow between components?

**A: Signal → Coordinator → Components:**
```
Strategy.OnTick()
  → Generates Signal{type, entry, sl, tp}
  → TradeCoordinator.ProcessSignal(signal)
      → RiskManager.CanOpenPosition()
      → RiskManager.CalculatePositionSize()
      → CTrade.PositionOpen()
      → StateManager.TrackTrade()
```

Linear flow, no circular dependencies, single responsibility per component.

### Q: How do I avoid breaking existing strategies when updating framework?

**A: Semantic versioning + pinning:**
- Version framework components (v1.0.0, v1.1.0, v2.0.0)
- EAs include specific version: `#include <Framework/v1/Risk/FixedRiskManager.mqh>`
- Breaking changes increment major version
- Maintain regression test suite

### Q: Why doesn't StateManager have an interface like IRiskManager?

**A: Interfaces are for polymorphism - when you need multiple implementations.**
- **IRiskManager**: Multiple implementations expected (Fixed, Volatility, Drawdown, etc.)
- **StateManager**: One implementation expected (track, persist, metrics)

Add IStateManager only if you need:
- Different storage backends (file vs database vs cloud)
- Different metric calculations (basic vs advanced)
- Multiple state tracking strategies

Start without interface, add when concrete need arises.

### Q: Why not use BaseEA or IStrategy abstraction?

**A: YAGNI (You Aren't Gonna Need It).**
- Each strategy is unique - no benefit from bundled base class
- Composition (HAS-A components) is clearer than inheritance (IS-A framework)
- Avoid framework lock-in - each EA is independent
- CAN inherit for strategy-specific variations (BaseFVGStrategy → AggressiveFVG)

### Q: Should I use the existing Standard Library utilities?

**A: Yes, prefer standard library:**
- Time functions: `TimeCurrent()`, `iTime()`, etc.
- Math functions: `MathAbs()`, `MathMax()`, `MathMin()`
- Arrays: `ArrayResize()`, `ArraySort()`
- Only create custom utilities for repeated patterns

---

## Revision History

| Version | Date       | Changes                                                      |
|---------|------------|--------------------------------------------------------------|
| 1.0.0   | 2025-01-29 | Initial architecture design                                  |
| 1.1.0   | 2025-10-29 | Pivoted to Trade library foundation; removed Expert library dependencies due to stability concerns |
| 2.0.0   | 2025-10-29 | Major simplification: collapsed to 3 components (Strategy, Risk, State), removed Signal/Execution layers, embedded signals in EA, removed BaseEA/IStrategy abstractions, evidence-based approach |
| 2.1.0   | 2025-10-29 | Added TradeCoordinator for signal processing, moved Framework to Experts/Main/, clarified composition vs inheritance, documented all risk implementations as placeholders, added base strategy template to roadmap, clarified RiskManager scope (position sizing only, NOT SL/TP placement), added FAQ on interfaces |
| 2.2.0   | 2025-10-29 | Introduced Stop/Target Policy component to decouple SL/TP from strategy; updated diagrams, data flow, responsibilities, file structure (Framework/Stops), roadmap, and FAQ; clarified RiskManager consumes SL distance from StopPolicy or strategy |

---

**End of Document**
