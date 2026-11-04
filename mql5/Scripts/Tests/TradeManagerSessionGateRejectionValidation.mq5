#property strict

#include <XAUForge/TradeManager.mqh>

int g_passed = 0;
int g_failed = 0;

void CheckSessionGateCase(
   const string caseName,
   const string symbol,
   const datetime brokerTime,
   const bool expectedEvaluationSuccess,
   const bool expectedAllowed,
   const TradeSessionGateStatus expectedStatus
)
{
   TradeSessionGateResult result;

   const bool evaluated =
      EvaluateTradeSessionGate(symbol, brokerTime, result);

   const bool passed =
      evaluated == expectedEvaluationSuccess &&
      result.allowed == expectedAllowed &&
      result.status == expectedStatus;

   if(passed)
      g_passed++;
   else
      g_failed++;

   PrintFormat(
      "SESSION_GATE_REJECTION_TEST_%s | case=%s | evaluated=%s | allowed=%s | status=%s | expected_status=%s | broker_time=%s",
      passed ? "PASS" : "FAIL",
      caseName,
      evaluated ? "true" : "false",
      result.allowed ? "true" : "false",
      EnumToString(result.status),
      EnumToString(expectedStatus),
      TimeToString(brokerTime, TIME_DATE | TIME_SECONDS)
   );
}

void OnStart()
{
   const datetime saturday =
      D'2026.11.07 12:00:00';

   const datetime sunday =
      D'2026.11.08 12:00:00';

   // Deterministic invalid-input checks.
   CheckSessionGateCase(
      "empty_symbol",
      "",
      saturday,
      false,
      false,
      TRADE_SESSION_GATE_INVALID_INPUT
   );

   CheckSessionGateCase(
      "invalid_broker_time",
      _Symbol,
      (datetime)0,
      false,
      false,
      TRADE_SESSION_GATE_INVALID_INPUT
   );

   // Broker-aware checks using fixed synthetic server times.
   CheckSessionGateCase(
      "saturday_noon_outside",
      _Symbol,
      saturday,
      true,
      false,
      TRADE_SESSION_GATE_OUTSIDE_SESSION
   );

   CheckSessionGateCase(
      "sunday_noon_outside",
      _Symbol,
      sunday,
      true,
      false,
      TRADE_SESSION_GATE_OUTSIDE_SESSION
   );

   PrintFormat(
      "SESSION_GATE_REJECTION_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );
}
