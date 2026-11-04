# Symbol and Account Capabilities

This document describes the implemented Phase 5 broker-symbol and account-mode contract. It distinguishes initialization-time capability discovery from dynamic pre-trade validation and from the position ownership work planned for Phase 8.

## Runtime Symbol Contract

The Gold / XAUUSD strategy is attached to the broker's actual gold symbol. XAUForge uses `_Symbol` at runtime, so broker-specific names and suffixes are preserved. It does not automatically search for or alias alternative gold symbols.

`XAUForge.mq5` calls `LoadSymbolCapabilities(_Symbol, ...)` and `ValidateSymbolCapabilities(...)` during `OnInit()`. A failure prevents initialization rather than allowing trading with unknown broker specifications.

## `SymbolCapabilities` Snapshot

The [`SymbolManager.mqh`](../mql5/Include/XAUForge/SymbolManager.mqh) structure records:

| Group | Stored fields | Purpose |
| --- | --- | --- |
| Symbol identity | `symbol` | Identify the attached broker instrument. |
| Price model | `digits`, `point`, `tickSize`, `tickValue` | Describe display precision, price increments, and reference tick valuation. |
| Volume model | `volumeMin`, `volumeMax`, `volumeStep` | Establish broker lot-size bounds and increments. |
| Distance properties | `stopsLevel`, `freezeLevel` | Expose broker stop-distance and freeze constraints. |
| Trading capabilities | `tradeMode`, `orderMode` | Describe symbol trade permissions and allowed order types. |
| Execution capabilities | `executionMode`, `fillingMode` | Support appropriate request/filling-policy selection. |
| Contract/calculation model | `contractSize`, `calculationMode` | Describe contract properties and the broker calculation model. |

The loader reads properties through `SymbolInfoInteger()` and `SymbolInfoDouble()` rather than assuming common XAUUSD specifications across brokers. Validation rejects missing or inconsistent critical data, including invalid volume bounds or step sizes. A tick-value property being present does **not** replace the project's `OrderCalcProfit()`-based risk calculation.

The saved structure is an **initialization snapshot**, not proof that trading will be permitted later. Before any order, the Phase 7 TradeManager refreshes the market snapshot and checks spread, quote age, trade mode/session, distance constraints, margin, and supported request parameters. In particular, `FreezeLevel` is inspected but is not automatically treated as an additional minimum initial-entry stop distance. Modification and close restrictions require separate lifecycle-phase handling.

## Netting and Hedging Detection

`DetectAccountPositionMode()` reads `ACCOUNT_MARGIN_MODE` and maps:

| Account margin mode | XAUForge classification |
| --- | --- |
| `ACCOUNT_MARGIN_MODE_RETAIL_NETTING` | `ACCOUNT_POSITION_MODE_NETTING` |
| `ACCOUNT_MARGIN_MODE_EXCHANGE` | `ACCOUNT_POSITION_MODE_NETTING` |
| `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING` | `ACCOUNT_POSITION_MODE_HEDGING` |
| Unknown/unsupported mode | Detection fails; EA initialization is rejected. |

In a netting account, a symbol has aggregate net position exposure. In a hedging account, multiple distinct positions may exist for the same symbol. The correct classification influences later position selection, ownership and recovery behavior.

**Detection is not ownership enforcement.** The current EA records the mode but does not yet implement a `PositionManager`, prove ownership using magic/ticket/position identifiers, or enforce the maximum-one-XAUForge-position rule. Those responsibilities belong to Phase 8 and later phases.

## Ownership and Safe-Failure Boundary

The approved ownership policy requires XAUForge to avoid acting on unrelated manual trades or positions created by other EAs. In netting mode, when existing exposure contains manual/foreign activity and its ownership cannot be demonstrated unambiguously, a future ownership implementation must reject opening, modifying, or closing that exposure and report an explicit ambiguity reason. The current Phase 5 code **must not** be represented as already enforcing this policy.

Likewise, loading a broker's stop, volume and filling properties does not itself approve a trade. Risk sizing, up-to-date preflight, final request checking, and later lifecycle tracking are separate responsibilities.

## Evidence and Related Documentation

The implemented contract is visible in [`SymbolManager.mqh`](../mql5/Include/XAUForge/SymbolManager.mqh) and its initialization calls in [`XAUForge.mq5`](../mql5/Experts/XAUForge/XAUForge.mq5). The Phase 7 preflight behavior is described in [Trade Manager](trade-manager.md) and its [validation record](trade-manager-validation.md). The broader [architecture](architecture.md), [risk model](risk-management.md), and [roadmap](../ROADMAP.md) define the neighboring responsibilities and phase gates.

This document does not claim a complete broker matrix, full position-ownership tests, or production trading readiness.
