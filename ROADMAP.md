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

- Repository created private for the original bootstrap; later visibility change is recorded in [`DECISIONS.md`](DECISIONS.md)
- [`MIT License`](LICENSE)
- Repository foundation pull request
- Dedicated [MetaTrader 5](https://www.metatrader5.com/en/terminal/help) and [MetaEditor](https://www.metatrader5.com/en/metaeditor/help) instance in `/portable` mode
- Local [`XAUForge.mqproj`](mql5/Experts/XAUForge/XAUForge.mqproj)
- Verified repository-to-MQL5 setup process
- Verified build workflow
- Development environment documented in [`docs/development-environment.md`](docs/development-environment.md)

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

**Status:** Complete

Detailed implemented behavior and validation evidence are documented in [`docs/risk-management.md`](docs/risk-management.md).

Exit evidence:

- Planned percentage equity risk sizing
- ATR-based baseline SL/TP planning
- [`OrderCalcProfit()`](https://www.mql5.com/en/docs/trading/ordercalcprofit)-based sizing in account currency
- Conservative broker-volume normalization
- Rejection when normalized volume falls below `SYMBOL_VOLUME_MIN`
- Broker-server-day daily-loss baseline
- Cash-flow-adjusted daily-loss evaluation
- Restart-safe daily-loss persistence and recovery
- New-entry daily-loss gate
- Production compile gate: 0 errors and 0 warnings
- Deterministic daily-loss / entry-gate validation: 15/15
- Deterministic volume-normalization validation: 6/6
- Risk-plan / sizing exit validation: 15/15
- Persistence / new-day / fail-safe exit validation: 9/9
- Controlled same-day runtime recovery evidence
- Full branch diff reviewed and merged through [PR #14](https://github.com/PetrosTam/xauforge/pull/14)

## Phase 7 — Trade Manager

**Status:** Next — Not Started

Exit evidence:

- Dynamic pre-trade broker validation
- Broker stop constraints re-checked before submission
- Risk sizing recalculated if the final stop distance must change
- Independent margin and request validation
- [`OrderCheck`](https://www.mql5.com/en/docs/trading/ordercheck)
- Synchronous broker-valid trade submission
- Immediate trade retcode handling

## Phase 8 — Trade Lifecycle

**Status:** Not Started

Exit evidence:

- Orders, deals, and positions modeled correctly
- XAUForge position ownership rules enforced
- Maximum one XAUForge position initially

## Phase 9 — Transaction Tracking

**Status:** Not Started

Exit evidence:

- Lightweight [`OnTradeTransaction`](https://www.mql5.com/en/docs/event_handlers/ontradetransaction)
- Structured transaction events

## Phase 10 — Position Recovery

**Status:** Not Started

Exit evidence:

- Restart and re-attach state reconstruction
- Duplicate-action protection

## Phase 11 — Testing Foundation

**Status:** Not Started

Exit evidence:

- Logic tests
- Whole-EA Strategy Tester integration cases

## Phase 12 — Backtesting

**Status:** Not Started

Exit evidence:

- Manifested baseline experiments
- Real-tick testing where available
- Reproducible experiment metadata

## Phase 13 — Historical and Demo Forward Validation

**Status:** Not Started

Exit evidence:

- Historical out-of-sample validation process
- Chronological demo forward runs
- Overfitting discipline documented

## Phase 14 — Python Analytics

**Status:** Not Started

Exit evidence:

- Project-local `.venv`
- `pyproject.toml`
- Metrics and plots
- [`pytest`](https://docs.pytest.org/)
- Reproducible Python tooling

## Phase 15 — API and Database

**Status:** Conditional — Not Started

[FastAPI](https://fastapi.tiangolo.com/) and [MariaDB](https://mariadb.com/docs/) are introduced only if the completed core system has a justified requirement for them.

Exit evidence if activated:

- Requirement is documented before implementation
- API/database work remains outside the trading critical path unless explicitly justified
- Reproducible local setup and tests exist

## Phase 16 — RabbitMQ

**Status:** Conditional — Not Started

[RabbitMQ](https://www.rabbitmq.com/docs) is introduced only if a real asynchronous workload exists and simpler approaches are insufficient.

Exit evidence if activated:

- A concrete asynchronous workload justifies the dependency
- Simpler alternatives were considered
- Queue behavior is tested and documented
- The trading critical path does not depend on RabbitMQ without an explicit decision

## Phase 17 — CI / Audit / Hardening

**Status:** Not Started

Exit evidence:

- Quality automation added only for checks that actually exist
- Dependency and security review performed
- Repository and history cleanup reviewed
- CI permissions follow least-privilege principles
- No fake or decorative checks

## Phase 18 — Release Readiness

**Status:** Not Started

Exit evidence:

- Formal Public Release Gate completed
- Public-facing documentation complete
- Representative reproducible evidence
- Screenshots / narrative / limitations prepared where useful
- Secret and history audit complete
- MIT license verified and third-party licensing reviewed
- Disclaimers and performance claims remain honest

## Current Position

Phases 0 through 6 are complete.

The next implementation milestone is **Phase 7 — Trade Manager**.

Phase 7 has not started. Dynamic pre-trade validation, broker stop-constraint enforcement, risk recalculation after any final SL adjustment, independent margin/request validation, `OrderCheck`, synchronous request submission, and immediate retcode handling remain Phase 7 work.

The repository is public during active development under the decision recorded in [`DECISIONS.md`](DECISIONS.md); that visibility does not mean the formal Public Release Gate or Phase 18 has been completed.
