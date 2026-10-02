# XAUForge

XAUForge is a production-style MetaTrader 5 / MQL5 engineering project for Gold / XAUUSD focused on strategy isolation, broker-aware risk management, safe failure, execution correctness, and reproducible development.

It is built as a software-engineering portfolio project. It is **not** presented as a guaranteed-profitable trading bot, and historical or simulated results must not be interpreted as evidence of future returns.

## Current Status

**Phase 6 — Risk Manager: In Review**

Phases 0 through 5 are complete.

Phase 7 — Trade Manager has **not** started. XAUForge does not yet submit broker orders.

Current implemented work includes:

- explicit `SignalTimeframe` with default `PERIOD_H1`,
- completed-bar EMA20 / EMA50 crossover logic using shift `2 -> 1`,
- ATR14-based baseline stop-distance planning,
- broker symbol capability discovery through `_Symbol`,
- netting / hedging account-mode detection,
- validated risk settings,
- planned percentage-equity risk sizing,
- `OrderCalcProfit`-based position sizing in account currency,
- conservative broker-volume normalization,
- restart-safe broker-server-day daily-loss persistence,
- cash-flow-adjusted daily-loss evaluation,
- and a fail-safe new-entry daily-loss gate.

See [`ROADMAP.md`](ROADMAP.md) for the development sequence and [`docs/risk-management.md`](docs/risk-management.md) for the implemented Phase 6 risk model.

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

`StrategyEngine` does not place trades.

`RiskManager` calculates and validates the risk plan.

Dynamic broker pre-flight, `OrderCheck`, synchronous request submission, and immediate retcode handling belong to Phase 7.

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

### Position sizing

XAUForge does not hard-code a gold pip-value assumption.

`OrderCalcProfit` is used to estimate the account-currency loss of a reference volume between the candidate entry and stop price.

```text
loss_for_reference_volume =
    abs(OrderCalcProfit(... entry -> stop ...))

raw_volume =
    planned_risk_amount
    / loss_for_reference_volume
    * reference_volume
```

### Conservative broker-volume normalization

The theoretical volume is normalized using:

- `SYMBOL_VOLUME_MIN`
- `SYMBOL_VOLUME_MAX`
- `SYMBOL_VOLUME_STEP`

Normalization is conservative and rounds downward.

If the normalized volume falls below `SYMBOL_VOLUME_MIN`, the candidate entry is rejected instead of being increased to the broker minimum.

### Daily-loss gate

Default:

```text
MaxDailyLossPercent = 3.0
```

The daily-loss boundary uses the broker-server calendar day.

The baseline is restart-safe and cash-flow-adjusted so qualifying non-trading account funding operations do not masquerade as trading P/L.

Reaching the daily-loss threshold blocks new entries. It does not force-liquidate an existing position.

## Validation Evidence

Current Phase 6 evidence includes:

- production MQL5 compile gate: **0 errors, 0 warnings**,
- deterministic daily-loss / gate validation: **15 / 15 passed**,
- deterministic broker-volume normalization validation: **6 / 6 passed**,
- controlled portable-MT5 same-day recovery test:
  - first attach -> `DAILY_LOSS_STATE_RESOLUTION_INITIALIZED`
  - same-day re-attach -> `DAILY_LOSS_STATE_RESOLUTION_RECOVERED`
  - original day-start equity remained unchanged,
- deliberate staging and atomic Conventional Commits,
- ADRs for significant engineering and risk decisions.

The temporary deterministic validation scripts are currently kept outside the repository. Formal repository test infrastructure is introduced later in the roadmap.

## Development Environment

The Git repository is the source of truth.

Development uses a dedicated MetaTrader 5 / MetaEditor installation in `/portable` mode outside the repository.

Repository source is linked into that isolated terminal environment rather than copying terminal runtime state into Git.

A verified PowerShell build wrapper compiles the project and parses the MetaEditor compilation log.

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
- `OrderCheck`,
- `MqlTradeRequest` construction,
- synchronous broker order submission,
- immediate trade retcode handling,
- full order / deal / position lifecycle ownership,
- `OnTradeTransaction` lifecycle tracking,
- restart reconstruction of active trading positions,
- formal Strategy Tester integration suite,
- manifested backtest experiments,
- historical out-of-sample and demo forward validation,
- Python analytics,
- API / database integration,
- RabbitMQ.

These are implemented only when their roadmap phases are reached.

## Repository Workflow

Development uses:

- `main` as the permanent branch,
- short-lived feature branches,
- atomic Conventional Commits,
- deliberate staging and diff review,
- pull requests for meaningful changes,
- rebase-and-merge when the commit history is already clean and atomic.

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
-> Forward Validation
-> Python Analytics
```

See [`ROADMAP.md`](ROADMAP.md) for the full phased plan.

## Disclaimer

XAUForge is educational and portfolio software.

It is not investment advice and does not guarantee profitability.

Planned price risk is not the same as guaranteed realized maximum loss. Slippage, gaps, commissions, swap, fees, execution delays, and broker behavior can cause realized results to differ from the planned risk calculation.

Testing should be performed in controlled and demo environments before any consideration of real-money use.

## License

XAUForge-owned source code is licensed under the MIT License.

Third-party code, data, broker data, and external assets retain their own licensing terms where applicable.
