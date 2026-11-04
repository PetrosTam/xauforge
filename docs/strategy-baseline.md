# Strategy Baseline

This document records the deliberately simple signal contract for XAUForge. It does not introduce new strategy rules or claim profitability.

## Market and Timeframe

- The strategy domain is Gold / XAUUSD. At runtime, all broker operations use the symbol attached to the chart (`_Symbol`), including broker-specific suffixes.
- `SignalTimeframe` is explicit and defaults to `PERIOD_H1`.
- The initial indicators are EMA20, EMA50 and ATR14. Both EMAs use `MODE_EMA`, `PRICE_CLOSE`, and `ma_shift = 0`.

## Completed-Bar Signals

The algorithm **never** uses bar 0 for a trading signal. A crossover is evaluated from completed bar **shift 2** to completed bar **shift 1**:

```text
BUY:  EMA20[2] <= EMA50[2] AND EMA20[1] > EMA50[1]
SELL: EMA20[2] >= EMA50[2] AND EMA20[1] < EMA50[1]
```

Equality at shift 1 is not a crossover signal. The main EA evaluates the strategy on the first tick of each new `SignalTimeframe` bar.

Signal evaluation requires synchronized price history, sufficient calculated bars, and valid completed-bar indicator data. If these checks fail, no signal is evaluated.

## Baseline Trade Plan

- The initial stop distance is `2.0 × ATR14[1]`.
- The baseline risk/reward ratio is `2.0`.
- The initial planned risk is `1%` of current account equity; the daily-loss threshold defaults to `3%`.
- These values describe the baseline, not guaranteed execution prices or realized losses.

The [Risk Manager](risk-management.md) performs planned sizing and daily-loss checks. The [Trade Manager](trade-manager.md) revalidates broker conditions and recalculates sizing if final stop geometry changes.

The main `XAUForge.mq5` currently evaluates signals and baseline risk plans, but does not call `ExecuteApprovedTradeIntent()` or submit orders. The Trade Manager component is not yet integrated into the main EA execution flow.

Changes to the frozen baseline require an explicit, reviewed engineering decision.
