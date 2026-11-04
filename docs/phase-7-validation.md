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

## Open Evidence Before Phase 7 Exit

- Reconcile the 21 acceptance criteria and 16 validation requirements of [Issue #17](https://github.com/PetrosTam/xauforge/issues/17) against the final branch source and reproducible evidence.
- Review the production EA integration boundary without prematurely adding ownership or transaction-lifecycle behavior.
- Run the verified project-level PowerShell build gate on the final source and review the complete branch diff.
- Decide which currently external validation scripts belong in source control and retain enough configuration and provenance to reproduce important results.
- Finalize representative spread calibration, documentation and the phase-gate decision before the Phase 7 exit gate.

Passing historical or simulated validation does not establish future profitability or suitability for live trading.
