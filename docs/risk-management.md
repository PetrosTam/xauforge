# Risk Management

This document describes the implemented Phase 6 risk-management behavior in XAUForge.

It documents current behavior only. Trade submission, `OrderCheck`, margin/request pre-flight, final broker stop-constraint enforcement, and position ownership enforcement are later-phase responsibilities and are not presented here as implemented.

## Scope

Phase 6 provides the risk calculations and safety gates needed before broker submission.

The current implementation covers:

- validated risk settings,
- ATR-based baseline SL/TP planning,
- planned percentage-equity risk,
- `OrderCalcProfit`-based position sizing,
- conservative broker-volume normalization,
- broker-server-day daily-loss persistence and recovery,
- cash-flow-adjusted daily-loss evaluation,
- and a new-entry daily-loss gate.

Phase 6 does not submit trades.

## Risk Settings

The baseline inputs are:

- `RiskPercent = 1.0`
- `MaxDailyLossPercent = 3.0`
- `RiskRewardRatio = 2.0`

Risk settings are validated before the EA continues initialization.

Invalid risk settings fail safely rather than allowing trading with an unknown or invalid risk budget.

## Baseline SL/TP Planning

The strategy provides a direction and completed-bar ATR data.

The RiskManager builds a baseline trade plan from:

- the current candidate entry price,
- ATR14 from completed data,
- the signal direction,
- and the configured risk/reward ratio.

The baseline risk/reward ratio is `2.0`.

This Phase 6 trade plan is a planned risk geometry, not final broker submission validation.

If later broker pre-flight constraints require the stop distance to change, the volume must be recalculated from the final entry-to-stop distance before `OrderCheck`. That pre-trade broker validation belongs to Phase 7.

## Planned Percentage-Equity Risk

XAUForge sizes from account equity rather than a fixed lot size.

Conceptually:

```text
planned_risk_amount = equity * (risk_percent / 100)
```

For example, 1% planned risk on equity of 10,000 produces a planned price-risk budget of 100 in account currency.

This is planned price risk, not a guarantee of realized maximum loss. Slippage, gaps, commissions, swap, fees, and other execution effects can make realized P/L differ from the planned amount.

## `OrderCalcProfit`-Based Position Sizing

XAUForge does not hard-code a gold pip-value assumption.

The RiskManager uses `OrderCalcProfit` to estimate the account-currency loss for a reference volume over the planned entry-to-stop move.

Conceptually:

```text
loss_for_reference_volume =
    abs(OrderCalcProfit(... entry -> stop ...))

raw_volume =
    planned_risk_amount
    / loss_for_reference_volume
    * reference_volume
```

This keeps sizing tied to the actual symbol and account environment.

## Conservative Broker-Volume Normalization

The theoretical `rawVolume` is not assumed to be broker-valid.

It is normalized using the broker volume model:

- `SYMBOL_VOLUME_MIN`
- `SYMBOL_VOLUME_MAX`
- `SYMBOL_VOLUME_STEP`

Normalization is conservative:

```text
final_volume = floor_to_broker_volume_step(raw_volume)
```

The implementation does not round upward merely to satisfy broker minimum volume.

If the normalized result falls below `SYMBOL_VOLUME_MIN`, the candidate entry is rejected.

If the raw volume exceeds the broker maximum, the implementation caps it downward to the supported maximum and then applies the broker volume step.

### Deterministic validation evidence

The temporary external validation script covered:

- `0.137` with step `0.01` -> `0.13`
- `0.131` with step `0.10` -> `0.10`
- exact broker step preservation
- cap above broker maximum
- rejection below broker minimum
- rejection of invalid broker volume bounds

Observed result:

```text
SUMMARY | passed=6 | failed=0 | total=6
```

The temporary validation script is not part of the repository at this phase.

## Broker-Server-Day Daily-Loss Model

The daily-loss boundary uses the broker/server calendar day, not Windows local time.

The persisted daily-loss state records:

- broker-server day,
- original day-start equity,
- cumulative qualifying non-trading cash flow already reflected at baseline,
- and validity/schema information required for safe recovery.

The state is namespaced by account/server identity so unrelated account contexts do not silently share the same risk budget.

## Daily-Loss Persistence and Recovery

Daily-loss state is persisted using MetaTrader terminal global variables.

The persistence design is restart-safe and validates the stored schema/state before use.

A same-day restart or EA re-attachment must recover the original daily-loss baseline. It must not silently create a fresh daily risk budget.

Missing, incomplete, incompatible, or corrupt state is treated as a safety condition and fails safe.

### Runtime recovery evidence

A controlled portable-MT5 runtime check showed:

First attach:

```text
resolution=DAILY_LOSS_STATE_RESOLUTION_INITIALIZED
server_day=20261002
day_start_equity=100000
baseline_cash_flow=0
```

Same-day remove and re-attach:

```text
resolution=DAILY_LOSS_STATE_RESOLUTION_RECOVERED
server_day=20261002
day_start_equity=100000
baseline_cash_flow=0
```

The original baseline remained unchanged across the re-attachment.

## Cash-Flow Adjustment

The daily-loss model adjusts the baseline for qualifying non-trading account cash flows so funding operations do not masquerade as trading P/L.

Phase 6 reconstructs qualifying cash flows cumulatively from the current broker-server day's deal history.

The implemented allowlist is:

- `DEAL_TYPE_BALANCE`
- `DEAL_TYPE_CREDIT`
- `DEAL_TYPE_BONUS`

The signed `DEAL_PROFIT` value is accumulated for qualifying deals.

Other deal types are not silently treated as baseline-adjusting cash flows.

The current design intentionally leaves trading-related costs and non-allowlisted account operations reflected in equity unless a future explicit decision changes that policy.

## Daily-Loss Evaluation

The adjusted baseline is:

```text
adjusted_baseline =
    day_start_equity
    + (current_cash_flow_total - cash_flow_total_at_baseline)
```

Drawdown amount is:

```text
drawdown_amount =
    max(0, adjusted_baseline - current_equity)
```

Drawdown percentage is:

```text
drawdown_percent =
    drawdown_amount / adjusted_baseline * 100
```

The threshold is reached when:

```text
drawdown_percent >= max_daily_loss_percent
```

Zero or negative current equity remains evaluable as catastrophic drawdown rather than being rejected as an invalid input.

An invalid or non-positive adjusted baseline fails safely.

## New-Entry Daily-Loss Gate

The daily-loss gate separates successful evaluation from permission to open a new entry.

A successful evaluation can still produce a blocked entry.

The gate statuses are:

- `DAILY_LOSS_ENTRY_GATE_NOT_EVALUATED`
- `DAILY_LOSS_ENTRY_GATE_ALLOWED`
- `DAILY_LOSS_ENTRY_GATE_LIMIT_REACHED`
- `DAILY_LOSS_ENTRY_GATE_EVALUATION_FAILED`

The distinction is intentional:

```text
evaluation success + entryAllowed=true
    -> entry may continue through later risk/execution checks

evaluation success + entryAllowed=false
    -> the daily-loss limit was validly reached

evaluation failure + entryAllowed=false
    -> fail-safe technical/state failure
```

Reaching the daily-loss limit blocks new entries. It does not force liquidation of an existing position.

### Deterministic daily-loss validation evidence

The temporary external validation covered baseline drawdown cases, cash-flow adjustment, zero/negative equity, invalid adjusted baseline, and entry-gate behavior.

Observed result:

```text
SUMMARY | passed=15 | failed=0 | total=15
```

The temporary validation script is not part of the repository at this phase.

## EA Orchestration

`OnInit()` initializes or recovers the current daily-loss state.

On every new bar, the EA resolves the current broker-server-day state again so the EA can cross into a genuine new server day without requiring a restart.

For a non-`NONE` signal, the current flow is:

```text
new bar
-> resolve daily-loss state
-> read completed strategy data
-> evaluate signal
-> evaluate daily-loss entry gate
-> read current tick
-> build baseline SL/TP plan
-> calculate raw risk volume
-> normalize broker volume
```

The flow stops safely whenever a required risk step fails.

There is still no broker order submission in Phase 6.

## Failure Behavior

The RiskManager follows the project rule: safe failure over forced action.

Examples include:

- invalid settings -> initialization rejected,
- invalid daily-loss state -> no new entry,
- incompatible/corrupt persistence -> fail safe,
- daily-loss evaluation failure -> new entry blocked,
- daily-loss threshold reached -> new entry blocked,
- unusable adjusted daily-loss baseline -> evaluation failure,
- invalid raw/normalized volume -> candidate entry rejected,
- normalized volume below broker minimum -> candidate entry rejected.

Diagnostics are emitted for important failure paths.

## Phase 7 Boundary

The following are intentionally not claimed as Phase 6 implementation:

- final dynamic spread gate,
- current trade/session availability pre-flight,
- final broker stop/freeze-constraint enforcement,
- SL adjustment caused by broker pre-flight constraints,
- risk recalculation after a final SL adjustment,
- independent margin validation,
- `OrderCheck`,
- `MqlTradeRequest` construction,
- synchronous order submission,
- immediate broker retcode handling.

These belong to the TradeManager / Phase 7 flow.

The required invariant for Phase 7 is already established:

> if broker stop constraints force a different stop distance, position sizing must be recalculated from the final entry-to-stop move before `OrderCheck`.

## Validation Summary

Current Phase 6 evidence includes:

- production MQL5 compile gate: `0 errors, 0 warnings`,
- deterministic daily-loss/gate validation: `15/15`,
- deterministic volume-normalization validation: `6/6`,
- controlled portable-MT5 same-day persistence recovery,
- reviewed failure paths,
- deliberate staging and atomic Git commits,
- ADRs for significant persistence/cash-flow decisions.

Phase 6 remains **In Review** until documentation alignment, full branch review, pull-request validation, merge, and branch cleanup are complete.
