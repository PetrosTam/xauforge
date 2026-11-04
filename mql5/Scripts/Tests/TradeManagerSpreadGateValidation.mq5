#property strict

#include <XAUForge/TradeManager.mqh>

int g_passed = 0;
int g_failed = 0;

bool NearlyEqual(
   const double left,
   const double right
)
{
   return(
      MathAbs(left - right) <= 0.000000001
   );
}

void SetSnapshot(
   PreTradeMarketSnapshot &snapshot,
   const string symbol,
   const long timeMsc,
   const double bid,
   const double ask,
   const double point
)
{
   snapshot.symbol = symbol;
   snapshot.timeMsc = timeMsc;
   snapshot.bid = bid;
   snapshot.ask = ask;
   snapshot.point = point;
}

void CheckSpreadCase(
   const string caseName,
   const double maxSpreadPoints,
   const PreTradeMarketSnapshot &snapshot,
   const bool expectedEvaluationSuccess,
   const bool expectedAllowed,
   const SpreadGateStatus expectedStatus,
   const double expectedObservedSpreadPoints
)
{
   TradeExecutionSettings settings = {};
   settings.maxSpreadPoints = maxSpreadPoints;

   SpreadGateResult result;

   const bool evaluationSuccess =
      EvaluateSpreadGate(
         settings,
         snapshot,
         result
      );

   bool passed =
      evaluationSuccess == expectedEvaluationSuccess &&
      result.allowed == expectedAllowed &&
      result.status == expectedStatus;

   if(expectedEvaluationSuccess)
   {
      passed =
         passed &&
         NearlyEqual(
            result.observedSpreadPoints,
            expectedObservedSpreadPoints
         );
   }

   if(passed)
   {
      g_passed++;

      PrintFormat(
         "SPREAD_GATE_TEST_PASS | case=%s | evaluation_success=%s | allowed=%s | status=%s | observed=%G | max=%G",
         caseName,
         evaluationSuccess ? "true" : "false",
         result.allowed ? "true" : "false",
         EnumToString(result.status),
         result.observedSpreadPoints,
         result.maxSpreadPoints
      );

      return;
   }

   g_failed++;

   PrintFormat(
      "SPREAD_GATE_TEST_FAIL | case=%s | evaluation_success=%s | allowed=%s | status=%s | observed=%G | max=%G",
      caseName,
      evaluationSuccess ? "true" : "false",
      result.allowed ? "true" : "false",
      EnumToString(result.status),
      result.observedSpreadPoints,
      result.maxSpreadPoints
   );
}

void OnStart()
{
   PreTradeMarketSnapshot snapshot = {};

   // Case 1:
   // 30 points observed with maximum 50 -> allowed.
   SetSnapshot(
      snapshot,
      "TEST",
      1,
      100.00,
      100.30,
      0.01
   );

   CheckSpreadCase(
      "below_limit",
      50.0,
      snapshot,
      true,
      true,
      SPREAD_GATE_ALLOWED,
      30.0
   );

   // Case 2:
   // Exactly 50 points with maximum 50 -> allowed.
   SetSnapshot(
      snapshot,
      "TEST",
      1,
      100.00,
      100.50,
      0.01
   );

   CheckSpreadCase(
      "at_limit",
      50.0,
      snapshot,
      true,
      true,
      SPREAD_GATE_ALLOWED,
      50.0
   );

   // Case 3:
   // 51 points with maximum 50 -> rejected by policy.
   SetSnapshot(
      snapshot,
      "TEST",
      1,
      100.00,
      100.51,
      0.01
   );

   CheckSpreadCase(
      "above_limit",
      50.0,
      snapshot,
      true,
      false,
      SPREAD_GATE_TOO_WIDE,
      51.0
   );

   // Case 4:
   // Ask below Bid -> invalid snapshot.
   SetSnapshot(
      snapshot,
      "TEST",
      1,
      100.00,
      99.99,
      0.01
   );

   CheckSpreadCase(
      "invalid_snapshot",
      50.0,
      snapshot,
      false,
      false,
      SPREAD_GATE_INVALID_INPUT,
      0.0
   );

   // Case 5:
   // Zero maximum spread -> invalid execution settings.
   SetSnapshot(
      snapshot,
      "TEST",
      1,
      100.00,
      100.30,
      0.01
   );

   CheckSpreadCase(
      "invalid_settings",
      0.0,
      snapshot,
      false,
      false,
      SPREAD_GATE_INVALID_INPUT,
      0.0
   );

   // Deterministic invalid market snapshot regression cases.
   // Every case must be rejected by the spread gate.

   SetSnapshot(snapshot, "TEST", 1, 0.0, 100.30, 0.01);
   CheckSpreadCase("zero_bid_rejected", 50.0, snapshot, false, false, SPREAD_GATE_INVALID_INPUT, 0.0);

   SetSnapshot(snapshot, "TEST", 1, -1.0, 100.30, 0.01);
   CheckSpreadCase("negative_bid_rejected", 50.0, snapshot, false, false, SPREAD_GATE_INVALID_INPUT, 0.0);

   SetSnapshot(snapshot, "TEST", 1, 100.00, 0.0, 0.01);
   CheckSpreadCase("zero_ask_rejected", 50.0, snapshot, false, false, SPREAD_GATE_INVALID_INPUT, 0.0);

   SetSnapshot(snapshot, "TEST", 1, 100.00, -1.0, 0.01);
   CheckSpreadCase("negative_ask_rejected", 50.0, snapshot, false, false, SPREAD_GATE_INVALID_INPUT, 0.0);

   SetSnapshot(snapshot, "TEST", 1, 100.00, 100.30, 0.0);
   CheckSpreadCase("zero_point_rejected", 50.0, snapshot, false, false, SPREAD_GATE_INVALID_INPUT, 0.0);

   SetSnapshot(snapshot, "TEST", 1, 100.00, 100.30, -0.01);
   CheckSpreadCase("negative_point_rejected", 50.0, snapshot, false, false, SPREAD_GATE_INVALID_INPUT, 0.0);

   SetSnapshot(snapshot, "TEST", 0, 100.00, 100.30, 0.01);
   CheckSpreadCase("missing_timestamp_rejected", 50.0, snapshot, false, false, SPREAD_GATE_INVALID_INPUT, 0.0);

   SetSnapshot(snapshot, "", 1, 100.00, 100.30, 0.01);
   CheckSpreadCase("empty_symbol_rejected", 50.0, snapshot, false, false, SPREAD_GATE_INVALID_INPUT, 0.0);

   PrintFormat(
      "SPREAD_GATE_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );

   PreTradeMarketSnapshot brokerSnapshot;

   const bool brokerSnapshotLoaded =
      LoadPreTradeMarketSnapshot(
         _Symbol,
         brokerSnapshot
      );

   PrintFormat(
      "PRETRADE_SNAPSHOT_OBSERVATION | symbol=%s | loaded=%s | time_msc=%I64d | bid=%G | ask=%G | point=%G",
      _Symbol,
      brokerSnapshotLoaded ? "true" : "false",
      brokerSnapshot.timeMsc,
      brokerSnapshot.bid,
      brokerSnapshot.ask,
      brokerSnapshot.point
   );
}
