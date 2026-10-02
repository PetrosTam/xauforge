# XAUForge

XAUForge is a production-style [MetaTrader 5](https://www.metatrader5.com/en/terminal/help) / [MQL5](https://www.mql5.com/en/docs) engineering project for Gold / XAUUSD focused on strategy isolation, broker-aware risk management, safe failure, execution correctness, and reproducible development.

It is built as a software-engineering project. It is **not** presented as a guaranteed-profitable trading bot, and historical or simulated results must not be interpreted as evidence of future returns.

## Current Status

**Phase 6 — Risk Manager: Complete**

Phases 0 through 6 are complete.

**Next implementation milestone: Phase 7 — Trade Manager.** Phase 7 has not started, and XAUForge does not yet submit broker orders.

The repository is currently public as a work in progress by manual owner decision. Public visibility does **not** mean that XAUForge is production-ready, validated for real-money use, profitable, or through the formal Public Release Gate.

Current implemented work includes:

- explicit `SignalTimeframe` with default `PERIOD_H1`,
- completed-bar EMA20 / EMA50 crossover logic using shift `2 -> 1`,
- ATR14-based baseline stop-distance planning,
- broker symbol capability discovery through `_Symbol`,
- netting / hedging account-mode detection,
- validated risk settings,
- planned percentage-equity risk sizing,
- [`OrderCalcProfit()`](https://www.mql5.com/en/docs/trading/ordercalcprofit)-based position sizing in account currency,
- conservative broker-volume normalization,
- restart-safe broker-server-day daily-loss persistence,
- cash-flow-adjusted daily-loss evaluation,
- and a fail-safe new-entry daily-loss gate.

See [`ROADMAP.md`](ROADMAP.md) for the development sequence, [`DECISIONS.md`](DECISIONS.md) for engineering decisions, [`docs/development-environment.md`](docs/development-environment.md) for the verified MT5 workflow, and [`docs/risk-management.md`](docs/risk-management.md) for the implemented Phase 6 risk model.

## Strategy Baseline

The initial strategy is deliberately small and explicit:

| Parameter | Baseline |
| --- | --- |
| Market | Gold / XAUUSD domain |
| Runtime symbol | Attached broker symbol via `_Symbol` |
| Signal timeframe | `PERIOD_H1` |
| Fast EMA | 20 |
| Slow EMA | 50 |
| Signal rule | Completed-bar crossover, shift `2 -> 1` |
| ATR period | 14 |
| Baseline stop distance | ATR14 × 2.0 |
| Risk / reward | `2.0` |

Bar `0` is never used for signal generation.

The current crossover semantics are explicit:

```text
BUY:
EMA20[2] <= EMA50[2]
AND
EMA20[1] > EMA50[1]

SELL:
EMA20[2] >= EMA50[2]
AND
EMA20[1] < EMA50[1]
```

Equality on shift `1` does not produce a signal.

## Architecture

XAUForge separates signal generation, risk calculation, and future broker execution responsibilities.

```text
Market / Broker
      |
      v
StrategyEngine
  signal intent only
      |
      v
RiskManager
  SL/TP planning
  planned risk
  volume sizing
  daily-loss gate
      |
      v
TradeManager
  Phase 7 — not implemented yet
```

[`StrategyEngine`](mql5/Include/XAUForge/StrategyEngine.mqh) does not place trades.

[`RiskManager`](mql5/Include/XAUForge/RiskManager.mqh) calculates and validates the risk plan.

Dynamic broker pre-flight, final broker stop-constraint handling, independent margin/request validation, [`OrderCheck`](https://www.mql5.com/en/docs/trading/ordercheck), synchronous request submission, and immediate retcode handling belong to [Phase 7](ROADMAP.md#phase-7--trade-manager).

## Risk Management

### Planned risk

The baseline per-trade risk is percentage-based rather than a fixed lot size.

```text
planned_risk_amount = equity * (risk_percent / 100)
```

Default:

```text
RiskPercent = 1.0
```

This is planned price risk, not a guarantee of realized maximum loss.

### Position sizing

XAUForge does not hard-code a gold pip-value assumption.

[`OrderCalcProfit()`](https://www.mql5.com/en/docs/trading/ordercalcprofit) is used to estimate the account-currency loss of a reference volume between the candidate entry and stop price.

```text
loss_for_reference_volume =
    abs(OrderCalcProfit(... entry -> stop ...))

raw_volume =
    planned_risk_amount
    / loss_for_reference_volume
    * reference_volume
```

If Phase 7 broker pre-flight changes the final entry-to-stop distance, sizing must be recalculated before [`OrderCheck`](https://www.mql5.com/en/docs/trading/ordercheck).

### Conservative broker-volume normalization

The theoretical volume is normalized using:

- `SYMBOL_VOLUME_MIN`
- `SYMBOL_VOLUME_MAX`
- `SYMBOL_VOLUME_STEP`

Normalization is conservative and rounds downward.

If raw volume exceeds `SYMBOL_VOLUME_MAX`, it is capped downward before step normalization.

If the normalized volume falls below `SYMBOL_VOLUME_MIN`, the candidate entry is rejected instead of being increased to the broker minimum.

### Daily-loss gate

Default:

```text
MaxDailyLossPercent = 3.0
```

The daily-loss boundary uses the broker-server calendar day.

The baseline is restart-safe and cash-flow-adjusted so qualifying non-trading account funding operations do not masquerade as trading P/L.

The implemented qualifying cash-flow allowlist is:

- `DEAL_TYPE_BALANCE`
- `DEAL_TYPE_CREDIT`
- `DEAL_TYPE_BONUS`

Reaching the daily-loss threshold blocks new entries. It does not force-liquidate an existing position.

## Validation Evidence

Phase 6 exit evidence includes:

- production MQL5 compile gate: **0 errors, 0 warnings**,
- deterministic daily-loss / entry-gate validation: **15 / 15 passed**,
- deterministic broker-volume normalization validation: **6 / 6 passed**,
- Phase 6 risk-plan / sizing exit validation: **15 / 15 passed**,
- persistence / new-day / fail-safe exit validation: **9 / 9 passed**,
- controlled portable-MT5 same-day recovery:
  - first attach -> `DAILY_LOSS_STATE_RESOLUTION_INITIALIZED`,
  - same-day re-attach -> `DAILY_LOSS_STATE_RESOLUTION_RECOVERED`,
  - original day-start equity remained unchanged,
- full Phase 6 branch diff review before merge,
- deliberate staging and atomic [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/),
- and merged [PR #14](https://github.com/PetrosTam/xauforge/pull/14) evidence for the completed milestone.

The temporary deterministic validation scripts are currently kept outside the repository. Formal repository test infrastructure is introduced later in the roadmap.

## Development Environment

The Git repository is the source of truth.

Development uses a dedicated [MetaTrader 5](https://www.metatrader5.com/en/terminal/help) / [MetaEditor](https://www.metatrader5.com/en/metaeditor/help) installation in `/portable` mode outside the repository.

Repository source is linked into that isolated terminal environment rather than copying terminal runtime state into Git.

The main EA source is [`mql5/Experts/XAUForge/XAUForge.mq5`](mql5/Experts/XAUForge/XAUForge.mq5), with the MetaEditor project definition in [`XAUForge.mqproj`](mql5/Experts/XAUForge/XAUForge.mqproj).

A verified [`scripts/build-mql5.ps1`](scripts/build-mql5.ps1) PowerShell build wrapper compiles the project and parses the MetaEditor compilation log.

Example:

```powershell
.\scripts\build-mql5.ps1 -Mt5Root "<path-to-dedicated-mt5>"
```

Compile gate:

```text
0 errors
0 unexplained warnings
```

Terminal configuration, account state, history, cache, logs, credentials, and generated `.ex5` files are not normal source-controlled artifacts.

## Engineering Principles

XAUForge follows a small set of explicit engineering rules:

- correctness before sophistication,
- understanding before technology count,
- safe failure over forced action,
- reproducibility as a first-class requirement,
- evidence over claims,
- no unnecessary architecture or infrastructure.

Significant design decisions are recorded in [`DECISIONS.md`](DECISIONS.md).

## Current Limitations

The following are intentionally **not** claimed as implemented yet:

- dynamic pre-trade spread gating,
- final trade/session availability validation,
- final broker stop / freeze-constraint enforcement,
- SL adjustment and risk recalculation after final broker pre-flight,
- independent margin validation,
- [`OrderCheck`](https://www.mql5.com/en/docs/trading/ordercheck),
- [`MqlTradeRequest`](https://www.mql5.com/en/docs/constants/structures/mqltraderequest) construction,
- synchronous broker order submission,
- immediate trade retcode handling,
- full order / deal / position lifecycle ownership,
- maximum-one-position enforcement,
- [`OnTradeTransaction`](https://www.mql5.com/en/docs/event_handlers/ontradetransaction) lifecycle tracking,
- restart reconstruction of active trading positions,
- formal Strategy Tester integration suite,
- manifested backtest experiments,
- historical out-of-sample and demo forward validation,
- Python analytics,
- API / database integration,
- RabbitMQ,
- CI / audit / hardening phase completion,
- formal Public Release Gate completion.

These are implemented only when their roadmap phases are reached.

## Repository Workflow

Development uses:

- `main` as the permanent branch,
- short-lived feature branches,
- atomic [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/),
- deliberate staging and diff review,
- pull requests for meaningful changes,
- rebase-and-merge when the commit history is already clean and atomic,
- branch cleanup after merge.

Repository visibility changes remain manual owner actions.

## Roadmap

The core roadmap progresses through:

```text
StrategyEngine
-> Symbol / Account Capabilities
-> RiskManager
-> TradeManager
-> Trade Lifecycle
-> Transaction Tracking
-> Position Recovery
-> Testing
-> Backtesting
-> Historical + Demo Forward Validation
-> Python Analytics
-> Conditional Backend / Queue Work
-> CI / Audit / Hardening
-> Release Readiness
```

See [`ROADMAP.md`](ROADMAP.md) for the full phased plan.

## Disclaimer

XAUForge is educational engineering software.

It is not investment advice and does not guarantee profitability.

Planned price risk is not the same as guaranteed realized maximum loss. Slippage, gaps, commissions, swap, fees, execution delays, and broker behavior can cause realized results to differ from the planned risk calculation.

Testing should be performed in controlled and demo environments before any consideration of real-money use.

## License

XAUForge-owned source code is licensed under the [`MIT License`](LICENSE) ([OSI reference](https://opensource.org/license/mit)).

Third-party code, data, broker data, and external assets retain their own licensing terms where applicable.
