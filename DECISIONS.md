# XAUForge Engineering Decisions

This document records significant engineering decisions for XAUForge.

Its purpose is to make important architectural, trading, risk, workflow, and infrastructure choices explicit, reviewable, and explainable.

Significant changes to these decisions must be recorded here with their context, decision, rationale, and consequences rather than introduced silently.

## Decision Record Format

Each decision uses the following structure:

- **Status** — whether the decision is currently accepted, superseded, or deprecated
- **Context** — the problem or constraint that motivated the decision
- **Decision** — the selected approach
- **Rationale** — why that approach was selected
- **Consequences** — important effects, limitations, or follow-up requirements

---

## ADR-001 — XAUUSD Is the Initial Instrument

**Status:** Accepted

### Context

XAUForge needs one complete market workflow before introducing multi-symbol complexity.

### Decision

XAUUSD is the initial trading domain.

At runtime, the Expert Advisor operates on the actual broker symbol to which it is attached through `_Symbol`.

### Rationale

Focusing on one instrument allows broker behavior, risk handling, execution, recovery, and testing to be developed thoroughly before expanding the system to additional markets.

### Consequences

- Broker symbol properties must be queried dynamically.
- The project must work with the actual broker symbol represented by `_Symbol`.
- Automatic broker symbol alias discovery is not part of the initial scope.
- Multi-symbol trading is not part of the MVP.

---

## ADR-002 — Strategy and Execution Are Separate

**Status:** Accepted

### Context

Signal generation and broker execution have different responsibilities.

Combining them would increase coupling between market logic, risk validation, and execution behavior.

### Decision

`StrategyEngine` produces trading intent only.

It does not submit, modify, or close broker orders or positions.

### Rationale

Separating strategy from execution allows market logic to evolve without requiring broker, risk, or execution logic to be rewritten.

It also makes the system easier to test by responsibility.

### Consequences

- Strategy code does not directly place trades.
- Execution components do not decide whether a market signal is bullish or bearish.
- Risk and broker validation remain outside the strategy layer.
- Strategy changes can be tested independently from execution changes.

---

## ADR-003 — Dedicated MT5 Portable Environment

**Status:** Accepted

### Context

MetaTrader 5 maintains runtime state including terminal configuration, broker data, account state, history, cache, logs, and other machine-specific files.

This runtime state must not become part of the Git repository.

### Decision

Use a project-specific MetaTrader 5 and MetaEditor instance in `/portable` mode outside the Git repository.

### Rationale

A dedicated environment improves isolation and reproducibility while keeping Git focused on project-controlled source and documentation.

### Consequences

- Terminal runtime state is not version-controlled.
- Broker credentials and account configuration are not committed.
- The Git repository remains the source of truth for project source.
- A verified setup process must connect repository-controlled MQL5 source with the dedicated MT5 environment.
- Exact MT5 and MetaEditor builds must be recorded for important experiments because the platform can update over time.

---

## ADR-004 — Private Repository During Development

**Status:** Accepted

### Context

XAUForge requires development, testing, documentation, licensing review, reproducibility evidence, and repository cleanup before it is suitable for public portfolio use.

### Decision

The `xauforge` repository remains private during development.

Changing repository visibility to public is a manual owner decision made only after the Public Release Gate has passed.

### Rationale

Keeping the repository private during development allows the project to mature without exposing incomplete documentation, accidental sensitive information, misleading performance claims, or unfinished engineering work.

### Consequences

- Repository visibility is never changed automatically.
- Public release requires an explicit review.
- Secrets and repository history must be reviewed before publication.
- Documentation and limitations must be suitable for public viewing before release.
- The owner manually changes repository visibility.

---

## ADR-005 — RabbitMQ Is Post-Core

**Status:** Accepted

### Context

The initial XAUForge system does not have a demonstrated asynchronous workload that requires a message broker.

### Decision

RabbitMQ is not introduced during core development.

It may be introduced later only if a real asynchronous workload creates a justified requirement.

### Rationale

Infrastructure should solve an actual engineering problem rather than increase technology count or architectural complexity without demonstrated value.

### Consequences

- The core trading system remains simpler.
- RabbitMQ is a conditional later-phase technology.
- The trading critical path does not depend on RabbitMQ.
- Any future introduction must justify its operational, maintenance, security, and reproducibility cost.

---

## ADR-006 — MIT License

**Status:** Accepted

### Context

XAUForge-owned source code requires a clear licensing baseline.

Third-party software, data, and assets may have their own independent licensing requirements.

### Decision

XAUForge-owned source code is licensed under the MIT License with SPDX identifier `MIT`.

Third-party licenses remain independent.

### Rationale

The MIT License provides a clear and established licensing model for project-owned source without incorrectly applying the same terms to external components.

### Consequences

- The repository contains the standard MIT License text.
- XAUForge-owned source follows the MIT licensing baseline.
- Third-party dependencies, data, and assets require separate license review.
- Licensing is reviewed again before public release.

---

## ADR-007 — Explicit Signal Timeframe and No Look-Ahead

**Status:** Accepted

### Context

Trading behavior must not change silently because the Expert Advisor is attached to a chart with a different timeframe.

Signals must also avoid using incomplete current-bar information.

### Decision

`SignalTimeframe` is explicit and defaults to `PERIOD_H1`.

Signal generation uses completed bars only.

Crossover evaluation uses shift `2 -> 1`.

Bar `0` is never used for trading signals.

### Rationale

An explicit timeframe makes strategy behavior deterministic with respect to chart attachment.

Using completed bars prevents incomplete current-bar information from leaking into signal decisions.

### Consequences

- Changing the chart timeframe does not silently redefine the strategy.
- Signal calculations use completed market data.
- The no-look-ahead rule is explicit and testable.
- EMA crossover logic must evaluate the transition from shift `2` to shift `1`.

---

## ADR-008 — Synchronous Trade Submission Baseline

**Status:** Accepted

### Context

Trade submission should begin with a simple and explainable execution model while still preserving authoritative tracking of the server-side lifecycle.

### Decision

Trade submission is synchronous in the baseline.

`CTrade` asynchronous mode remains disabled initially.

`OnTradeTransaction` tracks the authoritative server-side trade lifecycle.

### Rationale

Synchronous submission simplifies immediate request and retcode handling while `OnTradeTransaction` still provides authoritative information about orders, deals, and positions after the server processes trading activity.

### Consequences

- Immediate submission results are handled synchronously.
- `OnTradeTransaction` remains authoritative for lifecycle tracking.
- The transaction handler must remain lightweight.
- Asynchronous submission is not introduced without a justified requirement.

---

## ADR-009 — Broker-Server-Day Equity Loss Gate

**Status:** Accepted

### Context

A daily-loss limit must remain meaningful across floating profit and loss, trading costs, Expert Advisor restarts, and non-trading account cash flows.

A simple session-local counter would not survive restart and could misinterpret deposits or withdrawals as trading performance.

### Decision

Maximum daily loss is measured from a cash-flow-adjusted broker-server-day start equity baseline.

The baseline must survive restart.

Reaching the daily-loss limit blocks new entries.

### Rationale

The daily risk budget must remain stable for the broker trading day and must not reset because the Expert Advisor restarts.

Non-trading balance operations must also be separated from trading performance.

### Consequences

- Floating profit and loss contributes to the daily-loss calculation.
- Trading costs contribute to the daily-loss calculation.
- Deposits, withdrawals, credits, and other non-trading cash flows adjust the baseline.
- Restarting or re-attaching the Expert Advisor does not silently reset the daily risk budget.
- Reaching the loss limit prevents new entries rather than forcing an unexpected position liquidation.

---

## ADR-010 — EMA Baseline Uses Closing Prices with No Shift

**Status:** Accepted

### Context

The EMA20 / EMA50 crossover requires an explicit applied price and moving-average shift when creating MQL5 moving-average indicators.

These parameters must be fixed explicitly so the strategy remains reproducible and does not rely on an undocumented implementation choice.

### Decision

EMA20 and EMA50 use `MODE_EMA`, `PRICE_CLOSE`, and `ma_shift = 0`.

### Rationale

Using unshifted closing-price EMAs provides a simple, conventional, and reproducible baseline without introducing additional strategy parameters.

### Consequences

- EMA20 and EMA50 are calculated from closing prices.
- Both moving averages use zero graphical/data shift.
- The crossover definition remains based on completed bars from shift `2 -> 1`.
- Changing the applied price or moving-average shift is a strategy change and requires explicit review.

---

## ADR-011 — Broker Volume Normalization Preserves the Risk Ceiling

**Status:** Accepted

### Context

Risk-based position sizing produces a raw trading volume from the planned equity risk and the monetary loss between entry and stop-loss.

Broker rules can constrain that raw volume through minimum volume, maximum volume, and volume step requirements.

The baseline already requires conservative downward normalization to the broker volume step and rejection when the resulting volume is below the broker minimum.

The behavior for a raw volume above the broker maximum also needs to be explicit.

### Decision

Broker volume normalization must never increase the calculated risk volume.

The raw volume is capped downward to `SYMBOL_VOLUME_MAX` when it exceeds the broker maximum.

The capped volume is then rounded downward to `SYMBOL_VOLUME_STEP`.

If the normalized volume is below `SYMBOL_VOLUME_MIN`, the trade is rejected rather than rounded upward to the minimum.

### Rationale

`RiskPercent` defines a planned risk ceiling, not a target that must always be fully consumed.

Reducing volume below the calculated raw volume reduces planned price risk and therefore remains within the risk budget.

Increasing volume to satisfy a broker minimum could exceed the planned risk budget and is therefore not allowed.

This keeps broker normalization conservative and consistent with the project's safe-failure principle.

### Consequences

- Volume normalization never rounds upward.
- A raw volume above `SYMBOL_VOLUME_MAX` is reduced rather than rejected solely for exceeding the maximum.
- Actual planned price risk can be lower than the configured risk budget.
- A normalized volume below `SYMBOL_VOLUME_MIN` causes the entry to be rejected.
- Floating-point tolerances and broker-step boundary behavior must be covered by tests.
- Broker request and margin validation remain separate later checks and are not replaced by volume normalization.
