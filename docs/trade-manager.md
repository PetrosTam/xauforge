# Trade Manager

## Scope and Current Status

Phase 7 consumes an already-approved signal/risk plan. It does **not** generate strategy signals, choose the risk budget or own the final order/deal/position lifecycle.

The `TradeManager.mqh` component has completed its scoped Phase 7 implementation and validation (PR #20 merged; Issue #17 closed). Its synchronous BUY submission path was exercised in the Strategy Tester under controlled conditions. **The main `XAUForge.mq5` EA does not yet call `ExecuteApprovedTradeIntent()`**, so component-level validation does not establish production EA trading integration or live-trading readiness.

## Pre-submission Flow

1. Validate the approved intent and execution settings.
2. Refresh `_Symbol` Bid/Ask and reject invalid, stale or inconsistent quotes.
3. Evaluate configured spread limits and current symbol trading mode/session.
4. Read broker stop/freeze properties and build tick-size-normalized final SL/TP geometry.
5. Recalculate final planned-risk volume from the final entry-to-SL distance using `OrderCalcProfit()`; normalize **downward** to broker volume constraints and reject below the minimum.
6. Validate margin capacity and construct a symbol-supported market request/filling policy.
7. Check terminal/account trading permissions; run `OrderCheck()` and reject failure or nonzero check retcodes.
8. Only after these gates, call synchronous `OrderSend()` and classify the **immediate** result.

A successful synchronous return or `TRADE_RETCODE_DONE` must not be treated as a substitute for the authoritative lifecycle information handled in later phases.

## Stop and Freeze Properties

- `SYMBOL_TRADE_STOPS_LEVEL` specifies a minimum distance from current price for placing Stop Loss, Take Profit and applicable pending orders.
- `SYMBOL_TRADE_FREEZE_LEVEL` describes a distance within which certain operations on existing orders/positions may be frozen, especially modification or cancellation.
- Phase 7 loads both properties but does **not** automatically impose the freeze distance as an extra initial-market-entry stop distance. This avoids conflating two distinct broker constraints. `OrderCheck()` and the trade server remain necessary pre-submission validation; broker-specific rejection is fail-safe.
- Position/order modification and close management are out of the current Phase 7 scope. If that scope changes, freeze-level applicability must be reviewed for the affected operation.

References: [MQL5 symbol properties](https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants), [MT5 symbol specification](https://www.metatrader5.com/en/terminal/help/trading/market_watch), [MetaQuotes discussion of freeze-level checks](https://www.mql5.com/en/articles/2555).

## Phase Boundaries and Known Limitations

- Position ownership and maximum-one-position enforcement: later Trade Lifecycle phase.
- Authoritative `OnTradeTransaction` state handling: later Transaction Tracking phase.
- Restart reconstruction of active positions: later Position Recovery phase.
- Production `OnTick()` integration: not enabled in the current baseline; must be explicitly reconciled with those safety boundaries.
- `MaxSpreadPoints` is **not finalized**; one live spread sample window does not justify a universal threshold.
- The quote-age policy must be explicitly configured; no undocumented production timeout is assumed.

See [Trade Manager validation evidence](trade-manager-validation.md) and [Issue #17](https://github.com/PetrosTam/xauforge/issues/17) for the scoped validation record and completed Phase 7 acceptance review.
