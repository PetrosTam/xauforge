# Risk Management

This document describes the implemented Phase 6 risk-management behavior in XAUForge.

Phase 6 is complete. Trade submission, `OrderCheck`, margin/request pre-flight, final broker stop-constraint enforcement, and position ownership enforcement are later-phase responsibilities and are not presented here as implemented.

## Scope

Phase 6 provides the risk calculations and safety gates needed before broker submission.

The implemented behavior covers:

- validated risk settings,
- ATR-based baseline SL/TP planning,
- planned percentage-equity risk,
- `OrderCalcProfit()`-based position sizing,
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

Validation rules are:

- `RiskPercent` must be finite, greater than zero, and no greater than 100%,
- `MaxDailyLossPercent` must be finite, greater than zero, and no greater than 100%,
- `RiskRewardRatio` must be finite and greater than zero.

Risk settings are validated before the EA continues initialization.

Invalid risk settings fail safely rather than allowing trading with an unknown or invalid risk budget.

## Baseline SL/TP Planning

The strategy provides a direction and completed-bar ATR data.

The RiskManager builds a baseline trade plan from:

- the current candidate entry price,
- ATR14 from completed data,
- the signal direction,
- and the configured risk/reward ratio.

The baseline stop distance is:

```text
stop_distance = ATR14[1] * 2.0
```

For BUY:

```text
SL = entry - stop_distance
TP = entry + stop_distance * RiskRewardRatio
```

For SELL:

```text
SL = entry + stop_distance
TP = entry - stop_distance * RiskRewardRatio
```

The baseline risk/reward ratio is `2.0`.

This Phase 6 trade plan is planned risk geometry, not final broker submission validation.

If later broker pre-flight constraints require the stop distance to change, the volume must be recalculated from the final entry-to-stop distance before `OrderCheck`. That pre-trade broker validation belongs to Phase 7.

## Planned Percentage-Equity Risk

XAUForge sizes from current account equity rather than a fixed lot size.

Conceptually:

```text
planned_risk_amount = equity * (risk_percent / 100)
```

For example, 1% planned risk on equity of 10,000 produces a planned price-risk budget of 100 in account currency.

This is planned price risk, not a guarantee of realized maximum loss. Slippage, gaps, commissions, swap, fees, execution delay, and other broker or market effects can make realized P/L differ from the planned amount.

## `OrderCalcProfit()`-Based Position Sizing

XAUForge does not hard-code a gold pip-value assumption.

The RiskManager uses `OrderCalcProfit()` to estimate the account-currency loss for a reference volume over the supplied entry-to-stop move.

Conceptually:

```text
loss_for_reference_volume =
    abs(OrderCalcProfit(... entry -> stop ...))

raw_volume =
    planned_risk_amount
    / loss_for_reference_volume
    * reference_volume
```

The current EA uses the broker minimum volume as the reference volume supplied to the sizing calculation.

Sizing fails safely if required numeric inputs are invalid, the BUY/SELL stop is on the wrong side of the entry, `OrderCalcProfit()` fails, or the resulting reference loss / raw volume is not finite and strictly positive.

Because sizing is derived from the supplied entry and stop prices, Phase 7 must recalculate the volume if broker pre-flight changes the final stop distance.

## Conservative Broker-Volume Normalization

The theoretical `rawVolume` is not assumed to be broker-valid.

It is normalized using the broker volume model:

- `SYMBOL_VOLUME_MIN`
- `SYMBOL_VOLUME_MAX`
- `SYMBOL_VOLUME_STEP`

The implementation first caps raw volume downward at `SYMBOL_VOLUME_MAX` when required, then normalizes downward to the broker step.

Conceptually:

```text
capped_volume = min(raw_volume, SYMBOL_VOLUME_MAX)
final_volume = floor_to_broker_volume_step(capped_volume)
```

Floating-point tolerance is used only to avoid representation noise at exact broker-step boundaries; it must not materially increase the calculated risk volume.

The implementation does not round upward merely to satisfy broker minimum volume.

If the normalized result is genuinely below `SYMBOL_VOLUME_MIN`, the candidate entry is rejected.

### Deterministic volume-normalization evidence

The temporary external validation script covered:

- `0.137` with step `0.01` -> `0.13`,
- `0.131` with step `0.10` -> `0.10`,
- exact broker step preservation,
- cap above broker maximum,
- rejection below broker minimum,
- rejection of invalid broker volume bounds.

Observed result:

```text
SUMMARY | passed=6 | failed=0 | total=6
```

The temporary validation script is not part of the repository at this phase.

## Broker-Server-Day Daily-Loss Model

The daily-loss boundary uses the broker/server calendar day, not Windows local time.

The persisted state is scoped by account login and trade-server identity so unrelated account/server contexts do not intentionally share the same XAUForge daily-loss budget.

The current persistence namespace uses the `XAUForge.DL.<login>.<server>` prefix and the following terminal-global suffixes:

- `.I` — initialization guard day,
- `.V` — persistence schema version,
- `.D` — broker-server day and final commit marker,
- `.E` — original day-start equity,
- `.C` — cumulative qualifying cash-flow total observed at baseline.

The current persistence schema version is `2.0`.

## Daily-Loss Persistence and Recovery

Daily-loss state is persisted using MetaTrader client-terminal global variables.

The day marker acts as the final commit marker for the multi-key state. During a save, the day marker is invalidated and flushed before the payload is changed. The valid day marker is written last and the state is flushed again after the completed payload is written.

This means an interrupted multi-key update should remain detectably invalid rather than appearing to be a complete recovered baseline.

Recovery behavior distinguishes legitimate initialization from same-day state loss:

- no persisted baseline and no initialization guard can represent first-ever initialization and may establish the current-day baseline,
- a valid current-day baseline is recovered rather than replaced,
- a valid older-day baseline / guard may allow initialization of a genuinely newer broker-server day,
- a current-day initialization guard without a valid matching current-day baseline fails safe,
- corrupt or incomplete state that cannot be safely replaced under the bootstrap rules fails safe,
- future-dated state or initialization metadata fails safe.

A completely deleted XAUForge persistence namespace cannot be distinguished by the EA from a namespace that has never been initialized. The initialization guard protects against interrupted or partial current-day persistence when the guard itself remains available; it cannot make external deletion of all namespace keys detectable.

### Runtime same-day recovery evidence

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

### Persistence / new-day / fail-safe exit evidence

A controlled external validation exercised previous-day state, current-day initialization, same-day recovery, missing current-day baseline after initialization began, corrupt current-day state, future-dated state handling, and cleanup of isolated temporary namespaces.

Observed result:

```text
SUMMARY | passed=9 | failed=0 | total=9
```

This was a controlled previous-day persisted-state transition into the current broker-server day. It was not a wall-clock wait across a live midnight boundary.

The temporary validation script is not part of the repository at this phase.

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

`DEAL_TYPE_BALANCE` is a coarse platform category. Representative broker validation must verify that broker-specific balance operations have the intended meaning before any real-money consideration.

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

### Deterministic daily-loss / gate evidence

The temporary external validation covered below/exact/above-threshold cases, cash-flow adjustment, zero/negative equity, invalid adjusted baseline, and entry-gate behavior.

Observed result:

```text
SUMMARY | passed=15 | failed=0 | total=15
```

The temporary validation script is not part of the repository at this phase.

## Risk-Plan / Sizing Exit Evidence

The final Phase 6 exit check exercised:

- valid baseline risk settings,
- invalid percentage and risk/reward boundaries,
- BUY and SELL ATR × 2.0 SL/TP plans,
- exact broker minimum and maximum volume boundaries,
- runtime symbol tick and reference-volume availability,
- BUY and SELL `OrderCalcProfit()` sizing,
- and sizing sensitivity to the supplied entry-to-stop distance.

Observed result:

```text
SUMMARY | passed=15 | failed=0 | total=15
```

This validates the Phase 6 sizing contract. Broker-driven SL adjustment remains a Phase 7 validation responsibility.

The temporary validation script is not part of the repository at this phase.

## EA Orchestration

`OnInit()` validates risk settings and initializes or recovers the current daily-loss state.

On every new bar, the EA resolves the current broker-server-day state again so the EA can cross into a genuinely newer server day without requiring a restart.

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

There is no broker order submission in Phase 6.

## Failure Behavior

The RiskManager follows the project rule: safe failure over forced action.

Examples include:

- invalid settings -> initialization rejected,
- invalid current-day persistence that cannot be safely replaced -> no new entry,
- daily-loss evaluation failure -> new entry blocked,
- daily-loss threshold reached -> new entry blocked,
- unusable adjusted daily-loss baseline -> evaluation failure,
- invalid raw/normalized volume -> candidate entry rejected,
- normalized volume below broker minimum -> candidate entry rejected,
- unusable `OrderCalcProfit()` result -> candidate entry rejected.

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

These belong to TradeManager / Phase 7.

Position ownership enforcement is also not a Phase 6 responsibility; it belongs to the later Trade Lifecycle phase.

The required invariant for Phase 7 is already established:

> if broker stop constraints force a different stop distance, position sizing must be recalculated from the final entry-to-stop move before `OrderCheck`.

## Validation Summary

Phase 6 exit evidence includes:

- production MQL5 compile gate: `0 errors, 0 warnings`,
- deterministic daily-loss / entry-gate validation: `15/15`,
- deterministic volume-normalization validation: `6/6`,
- Phase 6 risk-plan / sizing exit validation: `15/15`,
- persistence / new-day / fail-safe exit validation: `9/9`,
- controlled portable-MT5 same-day persistence recovery,
- reviewed failure paths,
- full branch diff review,
- deliberate staging and atomic Git commits,
- and ADRs for significant risk, persistence, cash-flow, and repository decisions.

Phase 6 is **Complete**. Phase 7 — Trade Manager is the next implementation milestone and has not started.
