#property strict

#include <XAUForge/TradeManager.mqh>

// Read-only deterministic checks for the Phase 7 trade-mode gate.
// No OrderCheck, OrderSend, or other trading requests.

int g_passed = 0;
int g_failed = 0;

void CheckTradeModeCase(
   const string caseName,
   const SignalDirection direction,
   const ENUM_SYMBOL_TRADE_MODE mode,
   const bool expectedEvaluationSuccess,
   const bool expectedAllowed,
   const TradeModeGateStatus expectedStatus
)
{
   TradeModeGateResult result;
   const bool evaluated = EvaluateTradeModeGate(direction, mode, result);

   const bool passed =
      evaluated == expectedEvaluationSuccess &&
      result.allowed == expectedAllowed &&
      result.status == expectedStatus &&
      result.direction == direction &&
      result.tradeMode == mode;

   if(passed)
      g_passed++;
   else
      g_failed++;

   PrintFormat(
      "TRADE_MODE_TEST_%s | case=%s | evaluated=%s | allowed=%s | status=%s | mode=%s | direction=%s",
      passed ? "PASS" : "FAIL",
      caseName,
      evaluated ? "true" : "false",
      result.allowed ? "true" : "false",
      EnumToString(result.status),
      EnumToString(mode),
      EnumToString(direction)
   );
}

void OnStart()
{
   TradeModeGateResult resetResult;
   ResetTradeModeGateResult(resetResult);

   const bool resetPassed =
      !resetResult.allowed &&
      resetResult.status == TRADE_MODE_GATE_NOT_EVALUATED &&
      resetResult.direction == SIGNAL_NONE &&
      resetResult.tradeMode == SYMBOL_TRADE_MODE_DISABLED;

   if(resetPassed)
      g_passed++;
   else
      g_failed++;

   PrintFormat(
      "TRADE_MODE_TEST_%s | case=reset_state",
      resetPassed ? "PASS" : "FAIL"
   );

   CheckTradeModeCase("full_buy_allowed", SIGNAL_BUY, SYMBOL_TRADE_MODE_FULL,
      true, true, TRADE_MODE_GATE_ALLOWED);
   CheckTradeModeCase("full_sell_allowed", SIGNAL_SELL, SYMBOL_TRADE_MODE_FULL,
      true, true, TRADE_MODE_GATE_ALLOWED);
   CheckTradeModeCase("longonly_buy_allowed", SIGNAL_BUY, SYMBOL_TRADE_MODE_LONGONLY,
      true, true, TRADE_MODE_GATE_ALLOWED);
   CheckTradeModeCase("longonly_sell_blocked", SIGNAL_SELL, SYMBOL_TRADE_MODE_LONGONLY,
      true, false, TRADE_MODE_GATE_DIRECTION_NOT_ALLOWED);
   CheckTradeModeCase("shortonly_buy_blocked", SIGNAL_BUY, SYMBOL_TRADE_MODE_SHORTONLY,
      true, false, TRADE_MODE_GATE_DIRECTION_NOT_ALLOWED);
   CheckTradeModeCase("shortonly_sell_allowed", SIGNAL_SELL, SYMBOL_TRADE_MODE_SHORTONLY,
      true, true, TRADE_MODE_GATE_ALLOWED);
   CheckTradeModeCase("closeonly_buy_blocked", SIGNAL_BUY, SYMBOL_TRADE_MODE_CLOSEONLY,
      true, false, TRADE_MODE_GATE_CLOSE_ONLY);
   CheckTradeModeCase("closeonly_sell_blocked", SIGNAL_SELL, SYMBOL_TRADE_MODE_CLOSEONLY,
      true, false, TRADE_MODE_GATE_CLOSE_ONLY);
   CheckTradeModeCase("disabled_buy_blocked", SIGNAL_BUY, SYMBOL_TRADE_MODE_DISABLED,
      true, false, TRADE_MODE_GATE_TRADING_DISABLED);
   CheckTradeModeCase("disabled_sell_blocked", SIGNAL_SELL, SYMBOL_TRADE_MODE_DISABLED,
      true, false, TRADE_MODE_GATE_TRADING_DISABLED);
   CheckTradeModeCase("no_signal_rejected", SIGNAL_NONE, SYMBOL_TRADE_MODE_FULL,
      false, false, TRADE_MODE_GATE_INVALID_INPUT);
   CheckTradeModeCase("unknown_mode_rejected", SIGNAL_BUY, (ENUM_SYMBOL_TRADE_MODE)999,
      false, false, TRADE_MODE_GATE_INVALID_INPUT);

   PrintFormat(
      "TRADE_MODE_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed, g_failed, g_passed + g_failed
   );

   ENUM_SYMBOL_TRADE_MODE observedMode = SYMBOL_TRADE_MODE_DISABLED;
   const bool loaded = LoadCurrentTradeMode(_Symbol, observedMode);
   PrintFormat(
      "TRADE_MODE_OBSERVATION | symbol=%s | loaded=%s | mode=%s",
      _Symbol, loaded ? "true" : "false", EnumToString(observedMode)
   );
}
