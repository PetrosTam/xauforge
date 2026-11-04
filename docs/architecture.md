# Architecture

This document describes XAUForge's implemented MetaTrader 5 / MQL5 architecture after the Phase 7 Trade Manager merge. It documents existing responsibilities and phase boundaries; it does not introduce new trading rules or approve live trading.

## System Boundary

XAUForge is an Expert Advisor for the Gold / XAUUSD domain. At runtime it operates on the broker symbol attached to the chart (`_Symbol`), including any broker-specific suffix. Strategy calculations use the explicit `SignalTimeframe` input, defaulting to `PERIOD_H1`, rather than silently adopting the chart timeframe.

The Git repository is the source of truth for project-controlled MQL5 source, scripts, and documentation. A dedicated MetaTrader 5 / MetaEditor installation runs outside the repository in `/portable` mode, with Windows directory junctions exposing repository-controlled source to the terminal. See [Development Environment](development-environment.md).

## Implemented Components

| Component | Source | Responsibility |
| --- | --- | --- |
| Main EA | [`XAUForge.mq5`](../mql5/Experts/XAUForge/XAUForge.mq5) | Initialize state and orchestrate new-bar signal and risk evaluation; release indicator resources. |
| StrategyEngine | [`StrategyEngine.mqh`](../mql5/Include/XAUForge/StrategyEngine.mqh) | Read ready, completed-bar EMA/ATR data and return `SIGNAL_BUY`, `SIGNAL_SELL`, or `SIGNAL_NONE`. |
| SymbolManager | [`SymbolManager.mqh`](../mql5/Include/XAUForge/SymbolManager.mqh) | Load and validate broker symbol capabilities; detect netting/hedging account mode. |
| RiskManager | [`RiskManager.mqh`](../mql5/Include/XAUForge/RiskManager.mqh) | Validate risk inputs, build baseline SL/TP, calculate and normalize planned-risk volume, and enforce the cash-flow-adjusted daily-loss entry gate. |
| TradeManager | [`TradeManager.mqh`](../mql5/Include/XAUForge/TradeManager.mqh) | Validate an approved trade intent against current broker conditions, construct/check a request, submit synchronously, and classify the immediate response. |

The modules have separate responsibilities: strategy evaluation does not perform account sizing, risk calculations do not imply broker approval, and the TradeManager does not select trade direction.

## Current Main-EA Lifecycle

### `OnInit()`

The main EA validates risk settings, initializes its new-bar reference, loads and validates `_Symbol` capabilities, detects the account position mode, initializes or recovers daily-loss state, and creates strategy indicator handles. Initialization fails when required state cannot be established safely.

### `OnTick()`

The current main-EA path is:

```text
new tick
  -> new bar on SignalTimeframe?       otherwise return
  -> resolve broker-server-day daily-loss state
  -> read synchronized completed-bar EMA/ATR data
  -> evaluate EMA20/EMA50 crossover
  -> signal is BUY or SELL?            otherwise return
  -> evaluate daily-loss entry gate    block if unavailable/reached
  -> read current _Symbol tick
  -> build ATR14-based risk plan
  -> calculate OrderCalcProfit-based raw risk volume
  -> normalize volume downward to broker rules
  -> emit diagnostics and return       no order submission
```

The current bar's opening time is used **only** to detect a new bar. Signal inputs come from completed bars: shift 2 and shift 1 for the EMA crossover; shift 1 for ATR. The EA does not use bar 0 for a trading signal. Missing, unsynchronized, or invalid data causes a safe skip.

### `OnDeinit()`

The EA releases indicator handles and writes a shutdown diagnostic.

## Execution Boundary

The Phase 7 TradeManager contains a synchronous execution path exposed through `ExecuteApprovedTradeIntent()`. Its pre-submission checks include current quote validity and freshness, spread, symbol trade mode and sessions, final stop geometry, risk-volume recalculation, margin and request validation, trading permissions, and `OrderCheck()`. It can then call `OrderSend()` and classify the immediate result.

**The production `XAUForge.mq5` currently includes `TradeManager.mqh` but does not call `ExecuteApprovedTradeIntent()`.** The execution path has been exercised through separate validation artifacts; this is not equivalent to integrated production-EA trading. See [Trade Manager](trade-manager.md) and [Trade Manager Validation Evidence](trade-manager-validation.md).

An `OrderSend()` result or retcode does not establish final order, deal, or position state. Final lifecycle reconciliation belongs to the later transaction-tracking work.

## Broker and Account Boundaries

`SymbolManager` captures an initialization snapshot of broker symbol specifications and detects the account's position accounting mode. Market prices, spread, trade/session availability, and applicable distance constraints must be revalidated near submission rather than assumed unchanged from initialization.

Netting and hedging recognition is implemented. **Position ownership enforcement is not.** The later ownership model must distinguish XAUForge exposure from manual or foreign exposure; ambiguous netting exposure must fail safe instead of being modified or closed on an assumption. See [Symbol and Account Capabilities](symbol-account-capabilities.md).

## Roadmap Boundaries

- **Phases 0-7:** Completed within their documented scopes, including the standalone TradeManager component.
- **Phase 8 - Trade Lifecycle:** Not started. Model orders/deals/positions, enforce ownership and the maximum-one-XAUForge-position policy.
- **Phase 9 - Transaction Tracking:** Not started. Add lightweight, authoritative `OnTradeTransaction()` lifecycle handling.
- **Phase 10 - Position Recovery:** Not started. Reconstruct state after restart or re-attachment and prevent duplicate actions.
- **Later phases:** Whole-EA integration, reproducible testing, backtesting, forward validation and conditional analytics/infrastructure work follow the [Roadmap](../ROADMAP.md).

No HTTP, database, message queue, or analytics dependency belongs in the current trade critical path. Technology is introduced only when justified by a documented requirement.

## Engineering Invariants

- No bar-0 signal inputs or implicit chart-timeframe changes.
- Failed data, risk, broker, or state checks stop further action rather than forcing an entry.
- Planned percentage-equity price risk is not a guarantee of realized loss; execution conditions and trading costs can change actual results.
- Broker volume normalization is conservative; volume below `SYMBOL_VOLUME_MIN` is rejected, not rounded up to create a trade.
- No assumption of ownership based on symbol alone, especially in netting accounts.
- Separate immediate submission results from authoritative transaction and position lifecycle state.
- Compile quality gate: 0 errors and 0 warnings. Focused tests do not establish live-trading readiness or profitability.

Significant architectural or risk-policy changes require an explicit entry in [`DECISIONS.md`](../DECISIONS.md) before implementation.
