#property strict

#include <XAUForge/TradeManager.mqh>

int g_passed = 0;
int g_failed = 0;

void RecordResult(
   const string caseName,
   const bool passed
)
{
   if(passed)
   {
      g_passed++;

      PrintFormat(
         "GEOMETRY_BOUNDARY_TEST_PASS | case=%s",
         caseName
      );

      return;
   }

   g_failed++;

   PrintFormat(
      "GEOMETRY_BOUNDARY_TEST_FAIL | case=%s",
      caseName
   );
}

void BuildCommonSnapshot(
   PreTradeMarketSnapshot &snapshot
)
{
   ResetPreTradeMarketSnapshot(
      snapshot
   );

   snapshot.symbol = "TEST";
   snapshot.timeMsc = 1;

   snapshot.bid = 4133.95;
   snapshot.ask = 4184.21;
   snapshot.point = 0.01;
}

void BuildZeroStopsConstraints(
   TradeDistanceConstraints &constraints
)
{
   ResetTradeDistanceConstraints(
      constraints
   );

   constraints.digits = 2;
   constraints.point = 0.01;
   constraints.tickSize = 0.01;

   constraints.stopsLevelPoints = 0;
   constraints.freezeLevelPoints = 0;
}

void TestBuyZeroStopsBoundary()
{
   PreTradeMarketSnapshot snapshot;

   BuildCommonSnapshot(
      snapshot
   );

   TradeDistanceConstraints constraints;

   BuildZeroStopsConstraints(
      constraints
   );

   RiskTradePlan riskPlan;

   riskPlan.direction = SIGNAL_BUY;
   riskPlan.entryPrice = snapshot.ask;

   riskPlan.stopDistance = 5.0;

   riskPlan.stopLossPrice =
      riskPlan.entryPrice -
      riskPlan.stopDistance;

   riskPlan.takeProfitPrice =
      riskPlan.entryPrice +
      riskPlan.stopDistance * 2.0;

   FinalTradeGeometry geometry;

   const bool success =
      BuildFinalTradeGeometry(
         riskPlan,
         2.0,
         snapshot,
         constraints,
         geometry
      );

   const bool passed =
      success &&
      geometry.valid &&
      geometry.status ==
         TRADE_GEOMETRY_VALID &&
      geometry.stopLossPrice <
         snapshot.bid &&
      geometry.stopLossPrice <=
         snapshot.bid -
         constraints.tickSize &&
      geometry.finalStopDistance >
         snapshot.ask -
         snapshot.bid;

   RecordResult(
      "buy_zero_stops_spread_exceeds_original_stop",
      passed
   );

   PrintFormat(
      "GEOMETRY_BOUNDARY_BUY_OBSERVATION | success=%s | status=%s | bid=%G | ask=%G | tick_size=%G | stops_level=%d | sl=%G | final_stop_distance=%G",
      success
         ? "true"
         : "false",
      EnumToString(
         geometry.status
      ),
      snapshot.bid,
      snapshot.ask,
      constraints.tickSize,
      constraints.stopsLevelPoints,
      geometry.stopLossPrice,
      geometry.finalStopDistance
   );
}

void TestSellZeroStopsBoundary()
{
   PreTradeMarketSnapshot snapshot;

   BuildCommonSnapshot(
      snapshot
   );

   TradeDistanceConstraints constraints;

   BuildZeroStopsConstraints(
      constraints
   );

   RiskTradePlan riskPlan;

   riskPlan.direction = SIGNAL_SELL;
   riskPlan.entryPrice = snapshot.bid;

   riskPlan.stopDistance = 5.0;

   riskPlan.stopLossPrice =
      riskPlan.entryPrice +
      riskPlan.stopDistance;

   riskPlan.takeProfitPrice =
      riskPlan.entryPrice -
      riskPlan.stopDistance * 2.0;

   FinalTradeGeometry geometry;

   const bool success =
      BuildFinalTradeGeometry(
         riskPlan,
         2.0,
         snapshot,
         constraints,
         geometry
      );

   const bool passed =
      success &&
      geometry.valid &&
      geometry.status ==
         TRADE_GEOMETRY_VALID &&
      geometry.stopLossPrice >
         snapshot.ask &&
      geometry.stopLossPrice >=
         snapshot.ask +
         constraints.tickSize &&
      geometry.finalStopDistance >
         snapshot.ask -
         snapshot.bid;

   RecordResult(
      "sell_zero_stops_spread_exceeds_original_stop",
      passed
   );

   PrintFormat(
      "GEOMETRY_BOUNDARY_SELL_OBSERVATION | success=%s | status=%s | bid=%G | ask=%G | tick_size=%G | stops_level=%d | sl=%G | final_stop_distance=%G",
      success
         ? "true"
         : "false",
      EnumToString(
         geometry.status
      ),
      snapshot.bid,
      snapshot.ask,
      constraints.tickSize,
      constraints.stopsLevelPoints,
      geometry.stopLossPrice,
      geometry.finalStopDistance
   );
}

void OnStart()
{
   TestBuyZeroStopsBoundary();
   TestSellZeroStopsBoundary();

   PrintFormat(
      "GEOMETRY_BOUNDARY_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );
}
