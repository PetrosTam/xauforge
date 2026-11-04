# Phase 7 — Validation Evidence

## Status and Provenance

Phase 7 is under final review. The results below were observed in the dedicated MetaTrader 5 / MetaEditor portable environment on **MetaTrader build 6235**, using the MetaQuotes-Demo XAUUSD symbol. Some scripts ran as one-shot chart scripts; others ran as controlled Strategy Tester validation EAs. They are focused engineering checks, **not** a complete production EA integration suite.

Most focused validation sources and terminal logs remain outside the repository. The orchestration validation EA source is maintained under `mql5/Experts/XAUForge/Validation/`. For final reproducibility, the selected scripts, source revision, execution inputs and run manifests still require review before the Phase 7 exit gate.

## Focused Regression Results

| Suite | Passed / total | Evidence scope |
| --- | ---: | --- |
| OrderCheck approval | 4 / 4 | Boolean/retcode approval predicate |
| Quote freshness | 11 / 11 | Synthetic timestamps and fail-safe input validation |
| Orchestration | 4 / 4 | One controlled BUY submission path plus negative gates |
| Final risk sizing | 17 / 17 | BUY/SELL stop-widening and account-currency loss estimates |
| Submission safety | 8 / 8 | Permission gates and invalid-volume `OrderCheck` rejection without `OrderSend()` |
| Request construction | 20 / 20 | BUY/SELL fields, execution modes, broker-supported filling |
| Trading sessions | 10 / 10 | Session start/end and overnight boundaries |
| Margin validation | 16 / 16 | BUY/SELL `OrderCalcMargin()` and margin capacity |
| Trade settings | 6 / 6 | Invalid spread/quote-age settings fail safe |
| Distance constraints | 4 / 4 | Broker property loading and structural checks |
| Spread gate | 5 / 5 | Spread threshold boundaries and invalid inputs |
| Trade-mode gate | 13 / 13 | FULL/LONGONLY/SHORTONLY/CLOSEONLY/DISABLED and invalid modes |
| **Total** | **118 / 118** | **Twelve focused suites only** |

Compilers reported **0 errors / 0 warnings** for the validation artifacts observed during the audit. `git diff --check` was clean after the two TradeManager safety changes.

## Selected Execution Evidence

- Strategy Tester: `TradeManagerOrchestrationValidation`, XAUUSD / H1, 2026-10-01 to 2026-10-02, `Open prices only`, 100,000 USD, 1:100, zero delay. The validated BUY request received `OrderSend() == true` and `retcode=10009` (`TRADE_RETCODE_DONE`). This is an immediate submission result, not a production EA lifecycle guarantee.
- Spread gate: `TRADE_EXECUTION_SPREAD_BLOCKED`, `order_send_attempted=false` with observed 66-point spread in the controlled test.
- Submission safety: invalid volume produced `OrderCheck` retcode `10014`, with `order_send_attempted=false`; `ValidationEnablePositiveSubmission=false`.
- Synthetic final risk sizing: BUY and SELL stop widening from `0.5` to `2.1` reduced raw volume from `20` to `4.7619`, normalized volume `4.76`, and estimated price loss to `999.60 USD` against a planned `1000 USD` budget.

## Broker Observations

- XAUUSD at the time of inspection: `SYMBOL_POINT=0.01`, `SYMBOL_TRADE_TICK_SIZE=0.01`, `stops_level=0`, `freeze_level=0`.
- Read-only spread probe: **1,000 accepted samples** from one window on **2026-11-03 around 03:10–03:12**, approximately 1 minute 45 seconds. `min=26`, `avg=47.25`, `median=48`, `p90=54`, `p95=56`, `p99=58`, `max=61` points.

These values are specific to the MetaQuotes-Demo symbol, account conditions and observation window. They do not justify selecting `MaxSpreadPoints` yet. Measurements across materially different market hours and execution conditions remain necessary.

## Orchestration Harness — Version-Controlled Reproduction

**Source:** [`mql5/Experts/XAUForge/Validation/TradeManagerOrchestrationValidation.mq5`](../mql5/Experts/XAUForge/Validation/TradeManagerOrchestrationValidation.mq5). This is a standalone Strategy Tester Expert Advisor; it is not a production entry point and is not included in `XAUForge.mqproj`'s compile target. Its `ValidationEnablePositiveSubmission` input defaults to `false`.

**Controlled environment (observed on 2026-11-03):** dedicated MT5/MetaEditor build 6235; MetaQuotes-Demo XAUUSD; H1; period 2026-10-01 00:00 through 2026-10-02 00:00; `Open prices only`; USD 100,000 starting deposit; leverage 1:100; zero-latency execution; optimization disabled; forward mode off; `ValidationMaxQuoteAgeSeconds=30`.

| Run | Input `ValidationEnablePositiveSubmission` | Observed summary | Trading evidence |
| --- | --- | --- | --- |
| Negative-only | `false` | `passed=3`, `failed=0`, `skipped=1`, `status=NEGATIVE_ONLY_PASS` | `positive_case=SKIPPED_DISABLED`, `order_send_attempted=false`, `no_retry=true`; balance unchanged |
| Explicit positive | `true` | `passed=4`, `failed=0`, `skipped=0`, `status=PASS` | `positive_case=EXECUTED`, `order_send_attempted=true`, `no_retry=true`; one simulated BUY (2.00 lots) at 4134.61, SL 4129.61, TP 4144.61 |

The positive run's simulated order reached Take Profit at 4144.61, with a final tester balance of USD 102,000. That result is an **execution-path fixture**, not an expectation of profitability. The `no_retry=true` message describes this harness's single-run control flow, not independently verified trade lifecycle state.

**How to reproduce:** verify the repository-to-MT5 `Experts/XAUForge` and `Include/XAUForge` junctions with `scripts/setup-mt5.ps1`. In MetaEditor, open the **repository-linked** Expert source above and compile it directly (F7, 0 errors / 0 warnings). In the MT5 Strategy Tester select `Experts\XAUForge\Validation\TradeManagerOrchestrationValidation.ex5`, set the environment and inputs above, and execute the default negative-only run first. The positive run requires an explicit `true` input and must only be performed in the Strategy Tester. Never attach this harness to a live chart.

**Repository-controlled verification (2026-11-03):** The corrected source was copied byte-for-byte into the repository and compiled with 0 errors and 0 warnings. Two Strategy Tester runs used `Experts\XAUForge\Validation\TradeManagerOrchestrationValidation.ex5`: negative-only at 16:18 local (3 PASS, 0 FAIL, 1 SKIP, no submission) and positive opt-in at 16:22 local (4 PASS, 0 FAIL, 0 SKIP, one simulated BUY submission, no retry reported). These runs are separate evidence from the historical 118/118 focused suite results. The final commit SHA, complete run manifests and selected execution logs remain to be recorded.

**Failure-injection regression (2026-11-04):** With
`ValidationMaxQuoteAgeSeconds=0` and
`ValidationEnablePositiveSubmission=true`, the harness
reported 2 PASS, 1 intentional FAIL and 1 SKIP.
The positive submission case was skipped after the
negative test failure, with `order_send_attempted=false`.
This validates the submission-inhibition branch, not
a normal successful test-suite run.
These runs exercise one controlled route with `Open prices only`. They are not the whole-EA integration, deterministic custom-symbol regression, or real-tick execution-delay validation layers required later in the roadmap.

## Repository-Controlled Request Construction Regression

**Observed:** 2026-11-04 at 03:26:50 local time, XAUUSD/H1.

**Source:** `mql5/Scripts/Tests/TradeManagerRequestConstructionValidation.mq5`

**Source SHA-256:** `47AB050E71C47BDBA5C8749FCBA8F8D91FFAA7D8B8C8B38F0ED210C9295A6D59`

The source was copied byte-for-byte from the previously executed local
validation script. The repository copy compiled with 0 errors and
0 warnings using the dedicated MetaEditor installation.

The script was executed through the verified repository-to-MT5
`Scripts/Tests` junction.

**Observed result:**

`REQUEST_BUILD_TEST_RESULT | passed=20 | failed=0 | total=20`

The 20 focused cases cover filling-policy selection, BUY/SELL request
construction, execution-mode-specific request fields, unsupported broker
capabilities, symbol consistency, and invalid geometry/risk inputs.

The read-only broker capability observation reported XAUUSD,
`SYMBOL_TRADE_EXECUTION_MARKET`, order mode 127, filling mode 3,
and selected `ORDER_FILLING_FOK`.

The script does not call `OrderCheck()` or `OrderSend()`.
This validates request-building decisions, not trade execution,
broker acceptance, or whole-EA integration.

## Repository-Controlled Spread Gate Regression

**Observed:** 2026-11-04 at 04:27:03 local time, XAUUSD/H1.

**Source:** `mql5/Scripts/Tests/TradeManagerSpreadGateValidation.mq5`

The original five-case spread-gate validation script was copied
into the repository and extended with eight deterministic negative
market-snapshot cases.

The repository source compiled with 0 errors and 0 warnings
using the dedicated MetaEditor installation.

**Observed result:**

`SPREAD_GATE_TEST_RESULT | passed=13 | failed=0 | total=13`

The five original cases cover spread thresholds, invalid
snapshot ordering, and invalid spread settings.

The eight added cases verify rejection of zero/negative Bid,
zero/negative Ask, zero/negative point, missing timestamp,
and empty symbol.

For invalid snapshots, the observed result was
`evaluation_success=false`, `allowed=false`, and
`SPREAD_GATE_INVALID_INPUT`.

The read-only broker snapshot observation returned
`loaded=true`, Bid 3938.53, Ask 3938.70, and point 0.01.

This validates deterministic rejection inside
`EvaluateSpreadGate()`. It does not directly inject a failed
`SymbolInfoTick()` call into `LoadPreTradeMarketSnapshot()`,
and it does not establish the full no-submission execution path.

The original five tests were already included in the
historical 118/118 focused results. The eight additional
cases are new and are reported separately here.

## Repository-Controlled Market Snapshot Loader Regression

**Observed:** 2026-11-04 at 04:51:21 local time.

**Source:** `mql5/Scripts/Tests/TradeManagerMarketSnapshotValidation.mq5`

**Initial source SHA-256:** `EC4D4EC212F236FFC338F4E6D730975CCEBBE06D2D81931EB2856694BA87C716`

The source compiled using the dedicated MetaEditor installation
with 0 errors and 0 warnings.

**Observed result:**

`MARKET_SNAPSHOT_TEST_RESULT | passed=2 | failed=0 | total=2`

Both tests passed: empty-symbol rejection and unavailable-symbol
tick-lookup failure. Both verified that the output snapshot was
reset after failure, preventing reuse of previously seeded values.

The unavailable-symbol test checked `SymbolExist()` before
calling the loader. `SymbolInfoTick()` failed with error 4302
(`ERR_MARKET_NOT_SELECTED`) in the observed terminal run.

The test does not submit orders or modify broker symbol selection.
It does not simulate malformed tick data returned by a
successful `SymbolInfoTick()` call, or prove the complete
execution-orchestration no-submit path.

## Repository-Controlled Trade Mode and Session Regression

**Observed:** 2026-11-04, XAUUSD/H1.

**Sources:**

- `mql5/Scripts/Tests/TradeManagerTradeModeGateValidation.mq5`
- `mql5/Scripts/Tests/TradeManagerSessionValidation.mq5`

Both scripts were copied byte-for-byte from the original
local validation sources.

**Original source SHA-256:**

- Trade Mode Gate: `F737233BDFB3E1FD9944AF71734EFD17FB4D6B1E92D19D4AFEBEAEEE42968129`
- Session: `259E9C1C999A975DF96749F5BF03331DE550D153FC136AB10A1DD922F1734EB4`

Both repository sources compiled using the dedicated
MetaEditor installation with 0 errors and 0 warnings.

**Observed results:**

- 2026-11-04 05:12:08:
  `TRADE_MODE_TEST_RESULT | passed=13 | failed=0 | total=13`
- 2026-11-04 05:13:00:
  `SESSION_WINDOW_TEST_RESULT | passed=10 | failed=0 | total=10`

The Trade Mode Gate regression covers BUY/SELL permissions
under FULL, LONGONLY, SHORTONLY, CLOSEONLY and DISABLED
modes, plus invalid direction, unknown mode and reset state.

The Session regression covers normal windows, exact
boundaries, full-day and cross-midnight windows, and
invalid inputs.

Read-only broker observations showed XAUUSD trade mode
FULL and a successful session evaluation with allowed=true.

**Scope limitation:** The session tests exercise
`IsTradeSessionWindowActive()` deterministically.
The real broker-session observation was allowed, not blocked.
These runs do not demonstrate a controlled
`TRADE_SESSION_GATE_OUTSIDE_SESSION` result, broker-session
lookup failure or the full execution no-submit path.

The 13 Trade Mode and 10 Session cases replay existing
historical suites and must not be counted as 23 additional
tests on top of the reported historical 118/118 result.

## Repository-Controlled Session Gate Rejection Regression

**Observed:** 2026-11-04 at 15:49:16 local time, XAUUSD chart.

**Source:** `mql5/Scripts/Tests/TradeManagerSessionGateRejectionValidation.mq5`

**Initial source SHA-256:** `8190000854F88C3C8F6B9C46D19BE5CFFC5636553DBB7ED4E7CDF1170466701C`

The source compiled with the dedicated MetaEditor installation
using 0 errors and 0 warnings.

**Observed result:**

`SESSION_GATE_REJECTION_TEST_RESULT | passed=4 | failed=0 | total=4`

Two invalid-input cases passed:

- Empty symbol rejected with `TRADE_SESSION_GATE_INVALID_INPUT`.
- Invalid broker time rejected with `TRADE_SESSION_GATE_INVALID_INPUT`.

Two broker-aware session rejection cases passed:

- Saturday 2026-11-07 12:00:00 returned
  `TRADE_SESSION_GATE_OUTSIDE_SESSION`.
- Sunday 2026-11-08 12:00:00 returned
  `TRADE_SESSION_GATE_OUTSIDE_SESSION`.

Both weekend checks returned `evaluation_success=true`
and `allowed=false`.

The weekend timestamps are controlled synthetic broker times,
not the actual time of execution. The checks use the broker's
published trading-session schedule for the attached symbol.

The script calls `EvaluateTradeSessionGate()` directly and
does not call `OrderCheck()` or `OrderSend()`.

**Scope limitation:** This validates the session-unavailable
rejection decision for the observed broker schedule. It does
not inject a session-lookup failure or demonstrate the complete
`ExecuteApprovedTradeIntent()` no-submission path.

These four new cases are reported separately from the
historical 118/118 focused results.

## Repository-Controlled Geometry and Final Risk Regression

**Observed:** 2026-11-04, XAUUSD chart, dedicated MT5/MetaEditor.

Four original validation sources were copied byte-for-byte into
`mql5/Scripts/Tests/` and verified with SHA-256.

| Source | Original SHA-256 |
| --- | --- |
| `TradeManagerDistanceConstraintsValidation.mq5` | `918451630BA69E104367FA14FCD701FF4605AB02A3EBB006F176D22DDEE301E1` |
| `TradeManagerGeometryBoundaryValidation.mq5` | `27628BE33539CDD417D30CD35CAA98B2F7A4DCFB86C2979BAB5B9F38FBC01E1B` |
| `TradeManagerGeometryValidation.mq5` | `B0D24A7D0E574DA9377F58A047A2B8D1EB64C855F8796EA380B807999A441509` |
| `TradeManagerFinalRiskSizingValidation.mq5` | `9242389C27C1D2446DE733C24640378F905C9EC523B4F6EE6838C5D302AC8790` |

All four scripts compiled with 0 errors and 0 warnings.

**Observed execution results:**

- 16:27:34 — `DISTANCE_CONSTRAINTS_TEST_RESULT | passed=4 | failed=0 | total=4`
- 16:28:02 — `GEOMETRY_BOUNDARY_TEST_RESULT | passed=2 | failed=0 | total=2`
- 16:28:24 — `GEOMETRY_TEST_RESULT | passed=22 | failed=0 | total=22`
- 16:29:24 — `FINAL_RISK_SIZING_TEST_RESULT | passed=17 | failed=0 | total=17`

**Total:** 45 passed, 0 failed across four repository-controlled suites.

The broker observation showed `point=0.01`, `tick_size=0.01`,
`stops_level=0` and `freeze_level=0`.

Synthetic BUY and SELL widening tests increased the original
stop distance from 0.50 to 2.10 price units, reducing raw
volume from 20.00 to approximately 4.7619 lots.

The tests verify that final volume sizing uses final geometry,
conservative volume normalization remains intact, and the
estimated SL loss stays within the planned monetary risk budget.

The geometry tests also cover invalid-plan rejection,
invalid-constraint rejection, tick normalization, and
final-distance-based TP calculation.

**Scope limitations:** StopsLevel widening was synthetic.
The observed broker StopsLevel and FreezeLevel were both zero.
These scripts do not demonstrate a nonzero FreezeLevel
restriction or the complete OrderSend no-submission path.
FreezeLevel is not applied as an initial market-entry
stop-distance rule in the Phase 7 baseline.

The 4 Distance Constraints and 17 Final Risk Sizing cases
were already included in the historical 118/118 total.
The 22 Geometry and 2 Geometry Boundary cases are reported
separately and are not part of that historical subtotal.

## Repository-Controlled Margin, OrderCheck and Permissions Regression

**Observed:** 2026-11-04, XAUUSD chart, dedicated MT5/MetaEditor.

**Sources:**

- `mql5/Scripts/Tests/TradeManagerMarginValidation.mq5`
- `mql5/Scripts/Tests/TradeManagerOrderCheckValidation.mq5`
- `mql5/Scripts/Tests/TradeManagerSubmissionPermissionValidation.mq5`

**Original source SHA-256:**

- Margin: `C85F0F763985CD79F836B8AB30E079E06AFB970FF04226DEB450017B92BE9B45`
- OrderCheck: `0B4E898060FAAF91C4D0828D344A6C50199D080BE0AC02295F01E67C891D12C9`
- Submission Permission: `D702954A31D1076BA72AF4F8AE47C0C4C6478B231FFB4A66989269270662D135`

The repository OrderCheck source was deliberately corrected
to derive expected approval from both the OrderCheck boolean
result and retcode == 0.

**Corrected OrderCheck source SHA-256:**
`64CCF14C9809B04501276BBA412118DFF3469A4042287F0BEC8506BA6F384942`

All three repository sources compiled with 0 errors and
0 warnings using the dedicated MetaEditor installation.

**Observed execution results:**

- 16:56:19: `MARGIN_TEST_RESULT | passed=16 | failed=0 | total=16`
- 16:56:49: `ORDER_CHECK_TEST_RESULT | passed=7 | failed=0 | total=7`
- 16:57:19: `SUBMISSION_PERMISSION_TEST_RESULT | passed=10 | failed=0 | total=10`

**Total observed:** 33 passed, 0 failed across three suites.

Margin tests covered synthetic insufficient free margin,
invalid inputs, broker OrderCalcMargin comparisons for BUY
and SELL, and current account margin consistency.

OrderCheck returned last_error=4752 and retcode=10027
(TRADE_RETCODE_CLIENT_DISABLES_AT), with the message
"AutoTrading disabled by client".

Both normal BUY/SELL requests and the request containing
zero volume were rejected under this terminal configuration.
The wrapper returned allowed=false and
TRADE_REQUEST_CHECK_REJECTED.

**Important limitation:** The zero-volume test passed
because the request was rejected, but its observed retcode
was 10027, not TRADE_RETCODE_INVALID_VOLUME (10014).
This run does not isolate invalid volume as the rejection
cause and does not exercise successful OrderCheck approval.

The current submission-permission observation reported
TRADE_SUBMISSION_PERMISSION_TERMINAL_TRADING_DISABLED.
Synthetic permission cases covered disconnected terminal,
disabled trading permissions, valid permissions, and
Strategy Tester connection handling.

These scripts do not call OrderSend and do not independently
prove a complete ExecuteApprovedTradeIntent no-submit path.
The OrderCheck script makes read-only preflight checks.

The 16 Margin tests replay a suite already included in the
historical 118/118 results. The 7 OrderCheck and 10
Submission Permission cases are recorded separately rather
than added to that historical subtotal.

## Open Evidence Before Phase 7 Exit

- Reconcile the 21 acceptance criteria and 16 validation requirements of [Issue #17](https://github.com/PetrosTam/xauforge/issues/17) against the final branch source and reproducible evidence.
- Review the production EA integration boundary without prematurely adding ownership or transaction-lifecycle behavior.
- Run the verified project-level PowerShell build gate on the final source and review the complete branch diff.
- Decide which currently external validation scripts belong in source control and retain enough configuration and provenance to reproduce important results.
- Finalize representative spread calibration, documentation and the phase-gate decision before the Phase 7 exit gate.

Passing historical or simulated validation does not establish future profitability or suitability for live trading.
