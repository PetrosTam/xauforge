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

**Status:** Complete

Exit evidence:

- `OnInit`
- `OnTick`
- `OnDeinit`
- New-bar control flow

## Phase 4 — Strategy Engine

**Status:** Complete

Exit evidence:

- EMA20 and EMA50 crossover signal generation
- ATR14 signal support
- Explicit signal timeframe
- Completed-bar signal evaluation
- No trade execution

## Phase 5 — Symbol and Account Capabilities

**Status:** Complete

Exit evidence:

- Broker symbol rules handled
- Account capabilities inspected
- Netting and hedging mode detected
- Ownership ambiguity identified as a fail-safe condition for later ownership enforcement

## Phase 6 — Risk Manager

**Status:** In Review

Exit evidence:

- Planned percentage equity risk sizing
- ATR-based baseline SL/TP planning
- `OrderCalcProfit`-based sizing in account currency
- Conservative broker-volume normalization
- Rejection when normalized volume falls below `SYMBOL_VOLUME_MIN`
- Broker-server-day daily-loss baseline
- Cash-flow-adjusted daily-loss evaluation
- Restart-safe daily-loss persistence and recovery
- New-entry daily-loss gate
- Compile, deterministic behavior, and runtime recovery evidence

## Phase 7 — Trade Manager

Exit evidence:

- Dynamic pre-trade broker validation
- Broker stop constraints re-checked before submission
- Risk sizing recalculated if the final stop distance must change
- Independent margin and request validation
- `OrderCheck`
- Synchronous broker-valid trade submission
- Immediate trade retcode handling

## Phase 8 — Trade Lifecycle

Exit evidence:

- Orders, deals, and positions modeled correctly
- XAUForge position ownership rules enforced
- Maximum one XAUForge position initially

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

Phases 0 through 5 are complete.

Phase 6 — Risk Manager is in review.

The Phase 6 implementation now covers planned percentage-equity risk, ATR-based baseline SL/TP planning, `OrderCalcProfit`-based position sizing, conservative broker-volume normalization, and restart-safe cash-flow-adjusted daily-loss gates.

The remaining Phase 6 work is documentation alignment, full branch review, pull-request validation, merge, and branch cleanup.

Phase 7 — Trade Manager has not started. Dynamic pre-trade validation, broker stop-constraint enforcement, margin/request validation, `OrderCheck`, and actual order submission remain Phase 7 work.
