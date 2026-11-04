# XAUForge

**MetaTrader 5 / MQL5 · Gold (XAUUSD) · Software engineering portfolio project**

XAUForge is a modular MetaTrader 5 Expert Advisor engineering project focused on deterministic signals, broker-aware risk management, safe trade execution and reproducible validation.

## Project Status

**In development — Phases 0–7 complete; Phase 8 (Trade Lifecycle) not started.** The Phase 7 `TradeManager.mqh` component has been merged and has scoped validation evidence. The main `XAUForge.mq5` EA does not yet invoke `ExecuteApprovedTradeIntent()`. Position ownership and authoritative trade lifecycle tracking remain for later phases. This repository is not a production-ready trading system.

## Implemented Components

- **StrategyEngine:** H1 EMA20/EMA50 crossover using completed bars (shifts 2 → 1), with ATR14-based baseline stop planning.
- **SymbolManager:** runtime `_Symbol` capabilities and netting/hedging account-mode detection.
- **RiskManager:** equity-based planned risk, conservative broker-volume sizing and a restart-safe, cash-flow-adjusted daily-loss entry gate.
- **TradeManager:** current-quote and broker pre-flight checks, final stop/volume recalculation, `OrderCheck()`, and synchronous order submission with immediate result classification. The component is not yet called by the main EA.

## Technology Stack

- **Platform:** MetaTrader 5 and MetaEditor
- **Language:** MQL5
- **Development:** Windows PowerShell, Git and GitHub

## Getting Started

Requires Windows, Git and a dedicated MetaTrader 5/MetaEditor installation in `/portable` mode **outside** the repository. Follow the [development environment guide](docs/development-environment.md) before building; it describes the required source links and verified setup.

```powershell
git clone https://github.com/PetrosTam/xauforge.git
Set-Location xauforge
.\scripts\setup-mt5.ps1 -Mt5Root "<path-to-dedicated-mt5>"
.\scripts\build-mql5.ps1 -Mt5Root "<path-to-dedicated-mt5>"
```

Replace the sample MT5 location with your own dedicated installation path. A successful build requires **0 errors and 0 warnings**.

## Validation

Phase 7 has undergone focused MQL5 regressions and controlled Strategy Tester execution. Those results validate specific components and failure paths; they do **not** establish complete production EA integration, live-trading readiness or future profitability. See [Trade Manager validation evidence](docs/trade-manager-validation.md).

## Documentation

- [System architecture](docs/architecture.md)
- [Symbol and account capabilities](docs/symbol-account-capabilities.md)
- [Strategy baseline](docs/strategy-baseline.md)
- [Risk management](docs/risk-management.md)
- [Trade Manager and execution boundaries](docs/trade-manager.md)
- [Development environment](docs/development-environment.md)
- [Trade Manager validation evidence](docs/trade-manager-validation.md)
- [Roadmap](ROADMAP.md) and [engineering decisions](DECISIONS.md)

## License and Disclaimer

Current XAUForge-owned materials are proprietary under the [LICENSE](LICENSE). XAUForge is an engineering project, **not financial advice or a guaranteed-profitable trading bot**. Realized losses may exceed planned price risk due to slippage, gaps, fees or execution conditions. Do not use this work for live trading without appropriate independent verification.
