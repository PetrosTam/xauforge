# XAUForge Engineering Decisions

This document records significant engineering decisions for XAUForge.

Its purpose is to make important architectural, trading, risk, workflow, and infrastructure choices explicit, reviewable, and explainable.

Significant changes to these decisions must be recorded here with their context, decision, rationale, and consequences rather than introduced silently.

Superseded decisions remain in this log. When a later ADR replaces an earlier decision, the earlier decision text is retained and its status points to the superseding ADR so the engineering history remains auditable.

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

**Status:** Superseded by ADR-016

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

This visibility-timing decision was later replaced by ADR-016 after the repository owner made the repository public during active development. The security, documentation, licensing, and manual-owner-control principles remain applicable.

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
- Licensing remains part of the formal Public Release Gate.
- Public repository visibility under ADR-016 does not imply that the formal release-quality licensing review has been completed or waived.

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

Qualifying non-trading funding operations must be separated from trading performance without silently excluding trading-related costs.

### Consequences

- Floating profit and loss contributes to the daily-loss calculation.
- Trading costs contribute to the daily-loss calculation.
- Qualifying non-trading cash flows adjust the baseline; the exact allowlist and reconstruction policy are defined by ADR-015.
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

---

## ADR-012 — Percentage Risk Inputs Use Explicit Percentage Bounds

**Status:** Accepted

### Context

`RiskPercent` is expressed as a percentage of current account equity.

`MaxDailyLossPercent` is expressed as a percentage of the cash-flow-adjusted broker-server-day start-equity baseline.

Both are percentage-valued risk controls, while `RiskRewardRatio` is a positive ratio rather than a percentage.

The project baseline requires risk-management inputs to be validated, but it does not define a narrower strategy-specific maximum for these percentage inputs.

Allowing values above 100% would permit a configured percentage budget greater than the entire current or baseline equity amount.

`RiskRewardRatio` is not an equity percentage, so an arbitrary strategy-specific upper limit is not introduced without evidence.

### Decision

`RiskPercent` must be finite, greater than zero, and no greater than 100%.

`MaxDailyLossPercent` must be finite, greater than zero, and no greater than 100%.

`RiskRewardRatio` must remain finite and greater than zero.

No narrower strategy-specific maximum is introduced without an explicit future risk-policy decision.

### Rationale

The 100% upper bound is a semantic bound for percentage-valued risk controls, not a recommendation to use extreme risk values.

`RiskPercent` is applied to current account equity when calculating planned monetary risk for a prospective trade.

`MaxDailyLossPercent` is applied to the cash-flow-adjusted broker-server-day start-equity baseline when determining whether new entries must be blocked.

The baseline defaults remain `RiskPercent = 1.0`, `MaxDailyLossPercent = 3.0`, and `RiskRewardRatio = 2.0`.

Avoiding an arbitrary upper bound for `RiskRewardRatio` keeps validation limited to requirements justified by the current baseline.

### Consequences

- Non-finite, zero, and negative risk settings are rejected.
- `RiskPercent` above 100% is rejected.
- `MaxDailyLossPercent` above 100% is rejected.
- `RiskRewardRatio` remains positive and finite without an arbitrary strategy-specific upper cap.
- `RiskPercent` and `MaxDailyLossPercent` share percentage validation but do not share the same calculation baseline.
- The default risk parameters are unchanged.
- Any future tightening of these bounds is a risk-policy change and requires explicit review.

---

## ADR-013 — Daily-Loss State Uses Terminal Global Variables

**Status:** Accepted

### Context

The daily-loss policy must preserve the original broker-server-day baseline across EA restart or re-attachment.

The persistence mechanism must remain outside ordinary in-memory EA state, must not introduce external infrastructure into the MQL5 core, and must support fail-safe recovery when persisted state is missing, incomplete, incompatible, or invalid.

MetaTrader 5 provides client-terminal global variables as native terminal-managed persistent storage.

These variables are shared across MQL5 programs in the same client terminal and store numeric `double` values. XAUForge therefore requires explicit namespacing, schema validation, and a persistence protocol that prevents partially updated state from being accepted as valid.

### Decision

XAUForge persists the Phase 6 daily-loss state using MetaTrader 5 client-terminal global variables.

Persisted daily-loss state is namespaced by:

- the XAUForge project identifier,
- the account login,
- the trade-server identity.

The base persistence protocol stores:

- a schema version,
- the broker-server calendar-day identifier,
- the original valid day-start equity.

ADR-014 later adds a separate `.I` initialization guard for same-day bootstrap safety.

ADR-015 later extends the persisted state to schema version `2.0` by adding the cumulative qualifying cash-flow total observed at baseline under the `.C` suffix.

The broker-server day is derived from `TimeCurrent()` and represented as `YYYYMMDD`.

Persisted calendar-day values must represent an actual valid calendar date within the supported MQL5 `datetime` range before they are accepted.

Persistence keys must remain within the MetaTrader global-variable name-length limit. An unusable namespace causes safe failure rather than silent truncation or collision.

The broker-server day value acts as the commit marker for the multi-key state.

Before updating an existing persisted state, XAUForge sets the day marker to an invalid value and calls `GlobalVariablesFlush()` before modifying the payload.

The state payload is then written.

The valid broker-server day marker is written last, after the payload, and `GlobalVariablesFlush()` is called again after the completed state has been written.

This protocol ensures that an interrupted update remains detectably invalid rather than appearing to be a successfully committed state with mixed old and new values.

Missing, incomplete, unsupported-version, invalid-date, non-finite, or otherwise invalid persisted state is never accepted as valid recovered state.

Whether a fresh current-day baseline may be initialized after missing or invalid persistence is governed by the bootstrap rules in ADR-014; same-day state loss after initialization has begun must fail safe.

### Rationale

Terminal global variables provide native restart-surviving persistence without introducing files, databases, HTTP services, Python, or other external infrastructure into the critical MQL5 core.

Account and trade-server namespacing prevents unrelated trading environments from intentionally sharing the same XAUForge daily-loss state.

Using `TimeCurrent()` keeps the calendar boundary based on broker/server time rather than Windows local time.

Representing the broker-server day as `YYYYMMDD` keeps persisted day identity deterministic, inspectable, and independent of local timezone conversion.

Validating the complete calendar date prevents structurally plausible but impossible values, such as an invalid day for a given month, from being accepted as recovered state.

A small explicit schema makes recovery behavior inspectable and allows future persistence changes to fail safely rather than silently interpreting incompatible state.

Invalidating and flushing the commit marker before modifying the payload prevents an interrupted update from leaving an old valid marker associated with partially updated data.

Writing the valid day marker last provides a simple commit boundary for the persisted multi-key state.

### Consequences

- Daily-loss state is not limited to EA process memory.
- Persisted values are restricted to the numeric storage supported by terminal global variables.
- Persistence state is shared at client-terminal scope, so correct namespacing is mandatory.
- Terminal global-variable names must remain within the platform length limit.
- Persisted broker-server day values are validated as real calendar dates before use.
- A save operation invalidates and flushes the commit marker before modifying the payload.
- A completed save writes the valid day marker last and explicitly flushes the resulting state.
- An interrupted or partial update remains invalid and must not be treated as successfully recovered state.
- Missing, incomplete, incompatible, or corrupt state is not accepted as recovered state; bootstrap/replacement behavior follows ADR-014.
- Strategy Tester global variables are emulated by tester agents and are separate from the live client terminal's global variables.
- Same-day recovery, new-day initialization, cash-flow reconstruction, and the daily-loss entry gate remain separate responsibilities from the persistence mechanism and are implemented and validated independently in Phase 6.
- External persistence infrastructure remains outside the Phase 6 core.

---

## ADR-014 — Daily-Loss Bootstrap Uses a Persistent Initialization Guard

**Status:** Accepted

### Context

A missing persisted daily-loss baseline is ambiguous.

It may represent the first valid XAUForge observation for an account and trade server, or it may represent unexpected state loss after a baseline had already been established for the current broker-server day.

Silently treating every missing baseline as first-time initialization could grant a fresh daily-loss budget after state loss or an interrupted persistence operation.

### Decision

XAUForge maintains a separate persistent daily-loss initialization guard in the same account/server namespace.

The guard key uses the `.I` suffix and stores the broker-server day identifier in `YYYYMMDD` form.

Before creating a new daily-loss baseline for a server day, XAUForge persists and flushes the initialization guard for that day.

Only after the guard has been persisted does XAUForge persist the daily-loss baseline state.

A valid persisted baseline for the current server day is recovered rather than replaced.

A current-day initialization guard without a valid matching current-day baseline causes fail-safe behavior and must not create a replacement baseline.

An older initialization guard may permit initialization when a genuinely newer broker-server day is observed.

Persisted state or guard values referring to a future server day cause fail-safe behavior.

If a valid same-day baseline exists but the initialization guard is absent or stale, XAUForge may restore the guard from the validated same-day baseline before continuing.

### Rationale

The initialization guard distinguishes ordinary first-time or new-day initialization from a same-day persistence failure.

Writing and flushing the guard before writing the baseline ensures that an interrupted initialization cannot later be mistaken for a legitimate first initialization with a fresh risk budget.

The guard remains native MetaTrader terminal-global state and does not introduce external infrastructure.

### Consequences

- Same-day missing or incomplete baseline state does not silently reset the daily-loss budget.
- First-ever initialization remains possible when no baseline and no initialization guard exist.
- A genuine new broker-server day may establish a new baseline when the persisted initialization guard belongs to an older day.
- Interrupted current-day initialization fails safe.
- Future-dated persisted state or initialization metadata fails safe.
- Valid same-day state remains authoritative and is recovered rather than recreated.
- The initialization guard adds one additional terminal global variable per account/server namespace.
- Deliberate external deletion of all XAUForge daily-loss terminal globals cannot be distinguished from a never-initialized namespace by the EA alone.
- Cash-flow reconstruction and the daily-loss threshold gate remain separate responsibilities from bootstrap/recovery and are implemented and validated independently in Phase 6.

---

## ADR-015 — Daily-Loss Cash Flows Are Reconstructed Cumulatively From Deal History

**Status:** Accepted

### Context

The Phase 6 daily-loss policy measures account-equity drawdown from a broker-server-day baseline while preventing non-trading account funding operations from masquerading as trading profit or loss.

The same daily-loss budget must survive EA restart or re-attachment. An in-memory or increment-only cash-flow counter would not be restart-safe because the same historical deposit, withdrawal, credit, or bonus could be counted again after reconstruction.

The existing persisted daily-loss state therefore needs enough information to distinguish cash flows already reflected when the baseline was captured from qualifying cash flows that occur later in the same broker-server day.

### Decision

XAUForge reconstructs qualifying non-trading cash flows cumulatively from MetaTrader 5 deal history for the current broker-server calendar day.

The qualifying Phase 6 cash-flow allowlist is:

- `DEAL_TYPE_BALANCE`
- `DEAL_TYPE_CREDIT`
- `DEAL_TYPE_BONUS`

Other deal types are not treated as baseline-adjusting cash flows unless a future explicit decision and validation justify adding them.

In particular, charges, corrections, commissions, fees, taxes, interest, swap-related effects, and ordinary trading deals are not silently excluded from the daily-loss result by this cash-flow adjustment.

Cash-flow reconstruction uses broker-server time. The history interval begins at the start of the persisted broker-server calendar day and ends at the captured current server time.

For each qualifying deal, XAUForge uses the signed `DEAL_PROFIT` value and accumulates a cumulative cash-flow total.

The persisted `DailyLossState` stores:

- the broker-server day identifier,
- the original day-start equity,
- the cumulative qualifying cash-flow total observed when the baseline was captured.

The persistence schema version is `2.0`.

The cash-flow baseline snapshot is stored under the `.C` terminal-global suffix within the existing account/server namespace.

Daily-loss evaluation derives post-baseline cash flow as:

`currentCashFlowTotal - cashFlowTotalAtBaseline`

Cash-flow values may be positive, zero, or negative, but must be finite.

History-selection failure, deal-ticket retrieval failure, required deal-property retrieval failure, invalid numeric values, incomplete schema-v2 persistence, or incompatible persisted schema causes safe failure rather than silently estimating or resetting the daily-loss budget.

The existing daily-loss day marker remains the final persistence commit marker.

### Rationale

A cumulative history-derived model is idempotent across restart because reconstruction produces the same cumulative result from the same broker history rather than replaying incremental application events.

Persisting the cumulative cash-flow value that existed when the baseline was captured allows XAUForge to distinguish funding activity already reflected in the original equity baseline from funding activity that occurs afterward.

Using broker-server time keeps the reconstruction boundary consistent with the frozen daily-loss definition.

Using an explicit allowlist avoids treating every non-buy/sell deal as external funding and accidentally removing genuine trading or account costs from the equity-loss gate.

Increasing the schema version makes the additional persisted field explicit and prevents older state from being interpreted as if it contained a valid cash-flow snapshot.

### Consequences

- Same-day cash-flow reconstruction is restart-safe and idempotent.
- Deposits and withdrawals represented as balance operations can adjust the daily-loss baseline without appearing as trading performance.
- Credit and bonus operations included by the allowlist are treated as non-trading baseline adjustments.
- Trading costs and non-allowlisted account operations continue to affect equity and therefore remain visible to the daily-loss gate.
- Persisted daily-loss state includes one additional terminal global variable using the `.C` suffix.
- Existing schema `1.0` daily-loss state is intentionally incompatible with schema `2.0` and must not be silently migrated or accepted.
- Cash-flow history failures cause fail-safe behavior.
- `DEAL_TYPE_BALANCE` is a coarse platform category. Broker-specific or exceptional balance operations may represent adjustments other than ordinary deposits or withdrawals, so representative broker validation must verify the classification before real-money use. Ambiguous balance semantics must not be inferred from broker-specific comments without an explicit validated rule.
- Cash-flow reconstruction remains a separate responsibility from the daily-loss percentage calculation and new-entry gate; those calculations are implemented and validated elsewhere in the Phase 6 RiskManager flow.

---

## ADR-016 — Repository Visibility Is Public During Active Development

**Status:** Accepted

### Context

ADR-004 originally required the `xauforge` repository to remain private throughout active development and to become public only after the formal Public Release Gate passed.

During Phase 6, the repository owner manually changed the repository to public before the full roadmap and formal Public Release Gate were complete so that XAUForge could be used as verifiable work-in-progress portfolio evidence for job applications.

The repository is therefore public while active development continues.

After the repository became public, and before relying on it as portfolio evidence, a focused current-tree and Git-history safety audit was performed. The inspected repository contained no tracked `.env`, `.log`, or `.ex5` files; no terminal runtime/config/history/cache directories; no obvious credential assignments or personal `C:\Users\...` paths in the current tree; and no matching sensitive artifact paths, credential-pattern content, or personal Windows user paths in the inspected Git history.

This audit is evidence for the inspected categories, not a guarantee that arbitrary future commits cannot introduce sensitive information.

### Decision

The `xauforge` repository may remain public while active development continues.

This decision supersedes ADR-004 only with respect to the timing requirement that public visibility must wait until the formal Public Release Gate has passed.

Repository visibility remains a manual owner decision and is never changed automatically.

Public visibility does not mean that XAUForge is complete, production-ready, validated for real-money use, or through the formal Public Release Gate.

The formal Public Release Gate remains an active release-quality checklist covering security/history review, recruiter-ready documentation, licensing, reproducible evidence, limitations/disclaimers, and honest performance claims.

### Rationale

A public work-in-progress repository provides verifiable portfolio evidence for current job applications and allows reviewers to inspect the actual engineering process, commit history, documentation, and implementation.

Keeping the repository state, README, roadmap, and decision log factually consistent is preferable to leaving an accepted private-repository decision that no longer matches reality.

Preserving the formal Public Release Gate as a quality gate keeps the original security, licensing, reproducibility, and honesty requirements in force even though repository visibility changed earlier than originally planned.

### Consequences

- ADR-004 is superseded for repository-visibility timing.
- The repository is publicly accessible while XAUForge development continues.
- Public visibility must not be interpreted as project completion, production readiness, real-money readiness, or evidence of profitability.
- README and project documentation must clearly distinguish implemented, validated, planned, and incomplete functionality.
- Secrets, broker credentials, account configuration, `.env` values, terminal runtime state, private notes, logs, and generated `.ex5` binaries remain prohibited from normal Git history.
- Because pushed commits and feature branches can become publicly visible immediately, secret/history hygiene is an ongoing requirement rather than a one-time publication task.
- If sensitive credentials are ever exposed, credential rotation takes priority; deleting the current file alone is not sufficient if the value exists in Git history.
- MIT licensing remains the baseline for XAUForge-owned source, while third-party licensing remains independent and subject to review.
- The formal Public Release Gate remains required before XAUForge is described as release-ready or fully validated.
- Repository visibility changes remain manual owner actions; no automation may make the repository public or private.

---

## ADR-017 — Position Sizing Uses Planned Equity Risk and Account-Currency Stop-Loss Evaluation

**Status:** Accepted

### Context

XAUForge needs a position-sizing method that expresses trade risk as a percentage of account equity without relying on hard-coded assumptions about XAUUSD pip value, contract value, tick value, account currency, or broker-specific symbol conventions.

The calculated risk budget is a planned price-risk budget. It is not a guarantee of the maximum realized loss because slippage, gaps, commissions, swap, fees, execution delay, and other broker or market effects can change the final realized P/L.

The initial strategy baseline also requires an explicit stop-distance and risk/reward model so sizing behavior remains reproducible and explainable.

### Decision

The baseline per-trade planned risk is calculated from current account equity:

`planned_risk_amount = equity * (RiskPercent / 100)`

The default `RiskPercent` is `1.0`.

The baseline stop distance is:

`ATR14 * 2.0`

The baseline `RiskRewardRatio` is `2.0`.

Position sizing uses the supplied candidate entry price and stop-loss price.

XAUForge uses `OrderCalcProfit()` to estimate the account-currency profit/loss for a valid reference volume between the supplied entry and stop prices.

The absolute reference loss is used to scale the reference volume to the planned monetary risk:

`raw_volume = planned_risk_amount / loss_for_reference_volume * reference_volume`

XAUForge does not hard-code a gold pip-value or monetary-per-point assumption.

If the reference loss cannot be evaluated, is non-finite, or is not strictly positive, sizing fails safely and the candidate entry is rejected.

Broker-volume normalization is a separate step governed by ADR-011.

Final broker stop/freeze validation, independent margin/request validation, and `OrderCheck` belong to Phase 7. If Phase 7 broker pre-flight changes the final entry-to-stop distance, position sizing must be recalculated from that final distance before `OrderCheck`.

### Rationale

`OrderCalcProfit()` evaluates the supplied trade parameters in the actual symbol/account environment and returns the estimated P/L in account currency.

Using the actual entry-to-stop move avoids embedding broker-specific XAUUSD value assumptions in the risk formula.

Basing the monetary budget on current equity makes the planned risk scale with the account while keeping the configured percentage explicit.

Keeping baseline risk geometry in Phase 6 and final broker pre-flight in Phase 7 preserves the separation between risk calculation and broker-valid execution.

### Consequences

- The default planned trade-risk budget is 1% of current account equity.
- Planned price risk is explicitly distinguished from guaranteed realized maximum loss.
- The baseline stop distance is ATR14 multiplied by `2.0`.
- The baseline risk/reward ratio is `2.0`.
- BUY and SELL sizing use their respective supplied entry and stop prices.
- Account-currency loss estimation is delegated to `OrderCalcProfit()` rather than a hard-coded XAUUSD pip-value formula.
- Invalid or unusable sizing inputs fail safely.
- Raw sizing can change whenever the supplied entry-to-stop distance changes.
- Broker-volume normalization remains governed by ADR-011.
- A broker-driven SL adjustment in Phase 7 requires re-sizing before `OrderCheck`.
- Changing the risk basis, ATR stop multiplier, or sizing method is a risk-policy change and requires explicit review.

---

## ADR-018 — EMA Crossover Uses Explicit Equality Semantics

**Status:** Accepted

### Context

ADR-007 fixes the crossover evaluation to completed bars from shift `2` to shift `1`, and ADR-010 fixes the EMA calculation to unshifted closing-price EMA20 and EMA50.

The exact comparison operators are also part of the strategy definition. Without an explicit rule, changing equality handling could alter signal timing and therefore change backtest and forward-validation results without an obvious strategy decision.

### Decision

The baseline BUY crossover is:

`EMA20[2] <= EMA50[2] && EMA20[1] > EMA50[1]`

The baseline SELL crossover is:

`EMA20[2] >= EMA50[2] && EMA20[1] < EMA50[1]`

Equality is therefore permitted on shift `2`, the earlier completed bar.

Shift `1`, the most recent completed bar, must show a strict relationship in the new direction.

If EMA20 and EMA50 are equal on shift `1`, no crossover signal is produced.

The baseline uses direct indicator-value comparisons and does not introduce an additional crossover epsilon/tolerance.

### Rationale

Allowing equality on shift `2` recognizes a valid transition where the two EMAs were equal on the earlier completed bar and then separated into a new direction on shift `1`.

Requiring a strict relationship on shift `1` prevents equality on the most recent completed bar from being treated as a completed bullish or bearish cross.

Making these operators explicit ensures that signal semantics are reproducible and reviewable rather than hidden inside implementation details.

### Consequences

- BUY requires the fast EMA to be at or below the slow EMA on shift `2` and strictly above it on shift `1`.
- SELL requires the fast EMA to be at or above the slow EMA on shift `2` and strictly below it on shift `1`.
- Equality on shift `1` produces `SIGNAL_NONE`.
- Bar `0` remains excluded from signal generation under ADR-007.
- EMA calculation remains `MODE_EMA`, `PRICE_CLOSE`, and `ma_shift = 0` under ADR-010.
- Changing the crossover comparison operators or introducing a comparison tolerance is a strategy change and requires explicit review.
- Future regression and backtest baselines must treat these crossover semantics as part of the strategy definition.
