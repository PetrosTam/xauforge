# XAUForge Roadmap

This roadmap defines the planned implementation sequence for XAUForge.

It tracks the project's phase progression, scope boundaries, and the evidence required to complete each development phase.

## Phase 0 — Requirements and Architecture

**Status:** Complete

Exit evidence:

- Project scope defined
- Architecture baseline established
- Risk model defined
- Git and GitHub workflow defined
- Testing and reproducibility strategy defined

## Phase 1 — Repository and Isolated MT5 Environment

**Status:** Complete

Exit evidence:

- Private GitHub repository
- MIT License
- Repository foundation pull request
- Dedicated MetaTrader 5 and MetaEditor instance in portable mode
- Local `XAUForge.mqproj`
- Verified repository-to-MQL5 setup process
- Verified build workflow
- Development environment documented

## Phase 2 — MQL5 Fundamentals

**Status:** Complete

Exit evidence:

- Minimal Expert Advisor compiles cleanly
- Core MQL5 structure is understood

## Phase 3 — EA Lifecycle

Exit evidence:

- `OnInit`
- `OnTick`
- `OnDeinit`
- New-bar control flow

## Phase 4 — Strategy Engine

Exit evidence:

- EMA20 and EMA50 crossover signal generation
- ATR14 signal support
- Explicit signal timeframe
- Completed-bar signal evaluation
- No trade execution

## Phase 5 — Symbol and Account Capabilities

Exit evidence:

- Broker symbol rules handled
- Account capabilities inspected
- Netting and hedging mode detected
- Ownership ambiguity handled safely

## Phase 6 — Risk Manager

Exit evidence:

- Planned percentage equity risk sizing
- Conservative volume normalization
- Broker-valid SL and TP handling
- Daily-loss baseline
- Restart-safe daily-loss recovery

## Phase 7 — Trade Manager

Exit evidence:

- Synchronous broker-valid trade submission
- `OrderCheck`
- Immediate trade retcode handling

## Phase 8 — Trade Lifecycle

Exit evidence:

- Orders, deals, and positions modeled correctly
- XAUForge position ownership rules enforced

## Phase 9 — Transaction Tracking

Exit evidence:

- Lightweight `OnTradeTransaction`
- Structured transaction events

## Phase 10 — Position Recovery

Exit evidence:

- Restart and re-attach state reconstruction
- Duplicate-action protection

## Phase 11 — Testing Foundation

Exit evidence:

- Logic tests
- Whole-EA Strategy Tester integration cases

## Phase 12 — Backtesting

Exit evidence:

- Manifested baseline experiments
- Real-tick testing where available
- Reproducible experiment metadata

## Phase 13 — Historical and Demo Forward Validation

Exit evidence:

- Historical out-of-sample validation process
- Chronological demo forward runs
- Overfitting discipline documented

## Phase 14 — Python Analytics

Exit evidence:

- Project-local `.venv`
- `pyproject.toml`
- Metrics and plots
- `pytest`
- Reproducible Python tooling

## Phase 15 — API and Database

**Conditional phase**

FastAPI and MariaDB are introduced only if the completed core system has a justified requirement for them.

## Phase 16 — RabbitMQ

**Conditional phase**

RabbitMQ is introduced only if a real asynchronous workload exists and simpler approaches are insufficient.

## Current Position

Phase 0 is complete.

Phase 1 is complete.

Phase 2 is complete.

The current milestone is Phase 3 — EA Lifecycle.

The next implementation step is to introduce and understand the Expert Advisor lifecycle through `OnInit`, `OnTick`, `OnDeinit`, and new-bar control flow before strategy logic is added.
