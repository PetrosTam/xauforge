#property strict

#include <XAUForge/TradeManager.mqh>

int g_passed = 0;
int g_failed = 0;

bool NearlyEqual(
   const double left,
   const double right
)
{
   if(
      !MathIsValidNumber(left) ||
      !MathIsValidNumber(right)
   )
   {
      return(false);
   }

   const double tolerance =
      MathMax(
         0.000000001,
         CalculatePriceComparisonTolerance(
            left,
            right
         )
      );

   return(
      MathAbs(left - right) <=
      tolerance
   );
}

void RecordTestResult(
   const string caseName,
   const bool passed
)
{
   if(passed)
   {
      g_passed++;

      PrintFormat(
         "GEOMETRY_TEST_PASS | case=%s",
         caseName
      );

      return;
   }

   g_failed++;

   PrintFormat(
      "GEOMETRY_TEST_FAIL | case=%s",
      caseName
   );
}

void SetRiskPlan(
   RiskTradePlan &plan,
   const SignalDirection direction,
   const double entryPrice,
   const double stopDistance,
   const double riskRewardRatio
)
{
   plan.direction = direction;
   plan.entryPrice = entryPrice;
   plan.stopDistance = stopDistance;

   if(direction == SIGNAL_BUY)
   {
      plan.stopLossPrice =
         entryPrice -
         stopDistance;

      plan.takeProfitPrice =
         entryPrice +
         stopDistance *
         riskRewardRatio;

      return;
   }

   if(direction == SIGNAL_SELL)
   {
      plan.stopLossPrice =
         entryPrice +
         stopDistance;

      plan.takeProfitPrice =
         entryPrice -
         stopDistance *
         riskRewardRatio;

      return;
   }

   plan.stopLossPrice = 0.0;
   plan.takeProfitPrice = 0.0;
}

void SetMarketSnapshot(
   PreTradeMarketSnapshot &snapshot,
   const double bid,
   const double ask,
   const double point
)
{
   snapshot.symbol = "TEST";
   snapshot.timeMsc = 1;
   snapshot.bid = bid;
   snapshot.ask = ask;
   snapshot.point = point;
}

void SetTradeDistanceConstraints(
   TradeDistanceConstraints &constraints,
   const int digits,
   const double point,
   const double tickSize,
   const int stopsLevelPoints,
   const int freezeLevelPoints
)
{
   constraints.digits = digits;
   constraints.point = point;
   constraints.tickSize = tickSize;
   constraints.stopsLevelPoints =
      stopsLevelPoints;
   constraints.freezeLevelPoints =
      freezeLevelPoints;
}

bool GeometryMatches(
   const FinalTradeGeometry &geometry,
   const SignalDirection expectedDirection,
   const double expectedEntryPrice,
   const double expectedStopLossPrice,
   const double expectedTakeProfitPrice,
   const double expectedFinalStopDistance,
   const bool expectedStopDistanceChanged
)
{
   return(
      geometry.valid &&
      geometry.status ==
         TRADE_GEOMETRY_VALID &&
      geometry.direction ==
         expectedDirection &&
      NearlyEqual(
         geometry.entryPrice,
         expectedEntryPrice
      ) &&
      NearlyEqual(
         geometry.stopLossPrice,
         expectedStopLossPrice
      ) &&
      NearlyEqual(
         geometry.takeProfitPrice,
         expectedTakeProfitPrice
      ) &&
      NearlyEqual(
         geometry.finalStopDistance,
         expectedFinalStopDistance
      ) &&
      geometry.stopDistanceChanged ==
         expectedStopDistanceChanged
   );
}

void OnStart()
{
   const double riskRewardRatio = 2.0;

   RiskTradePlan plan;
   PreTradeMarketSnapshot snapshot;
   TradeDistanceConstraints constraints;
   FinalTradeGeometry geometry;

   bool buildSuccess = false;

   // ------------------------------------------------------------------
   // Case 1:
   // BUY geometry already lies on the broker tick grid.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_BUY,
      100.20,
      1.00,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      0,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   const bool buyOnGridPassed =
      buildSuccess &&
      GeometryMatches(
         geometry,
         SIGNAL_BUY,
         100.20,
         99.20,
         102.20,
         1.00,
         false
      );

   RecordTestResult(
      "buy_on_grid",
      buyOnGridPassed
   );

   // ------------------------------------------------------------------
   // Case 2:
   // SELL geometry already lies on the broker tick grid.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_SELL,
      100.00,
      1.00,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      0,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   const bool sellOnGridPassed =
      buildSuccess &&
      GeometryMatches(
         geometry,
         SIGNAL_SELL,
         100.00,
         101.00,
         98.00,
         1.00,
         false
      );

   RecordTestResult(
      "sell_on_grid",
      sellOnGridPassed
   );

   // ------------------------------------------------------------------
   // Case 3:
   // BUY SL is off-grid.
   // It must normalize DOWN, away from the BUY entry.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_BUY,
      100.20,
      1.003,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      0,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   const bool buyOffGridPassed =
      buildSuccess &&
      GeometryMatches(
         geometry,
         SIGNAL_BUY,
         100.20,
         99.19,
         102.22,
         1.01,
         true
      );

   RecordTestResult(
      "buy_off_grid_sl_rounds_down",
      buyOffGridPassed
   );

   // ------------------------------------------------------------------
   // Case 4:
   // SELL SL is off-grid.
   // It must normalize UP, away from the SELL entry.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_SELL,
      100.00,
      1.003,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      0,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   const bool sellOffGridPassed =
      buildSuccess &&
      GeometryMatches(
         geometry,
         SIGNAL_SELL,
         100.00,
         101.01,
         97.98,
         1.01,
         true
      );

   RecordTestResult(
      "sell_off_grid_sl_rounds_up",
      sellOffGridPassed
   );

   // ------------------------------------------------------------------
   // Case 5:
   // BUY StopsLevel forces the stop farther away.
   //
   // Bid = 100.00
   // Ask = 100.20
   // StopsLevel = 30 points = 0.30
   //
   // Broker SL boundary:
   // 100.00 - 0.30 = 99.70
   //
   // Final distance from Ask:
   // 100.20 - 99.70 = 0.50
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_BUY,
      100.20,
      0.10,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      30,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   const bool buyStopsLevelPassed =
      buildSuccess &&
      GeometryMatches(
         geometry,
         SIGNAL_BUY,
         100.20,
         99.70,
         101.20,
         0.50,
         true
      );

   RecordTestResult(
      "buy_stops_level_forces_wider_stop",
      buyStopsLevelPassed
   );

   // ------------------------------------------------------------------
   // Case 6:
   // SELL StopsLevel forces the stop farther away.
   //
   // Ask = 100.20
   // StopsLevel = 0.30
   //
   // Broker SL boundary:
   // 100.20 + 0.30 = 100.50
   //
   // Final distance from Bid:
   // 100.50 - 100.00 = 0.50
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_SELL,
      100.00,
      0.10,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      30,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   const bool sellStopsLevelPassed =
      buildSuccess &&
      GeometryMatches(
         geometry,
         SIGNAL_SELL,
         100.00,
         100.50,
         99.00,
         0.50,
         true
      );

   RecordTestResult(
      "sell_stops_level_forces_wider_stop",
      sellStopsLevelPassed
   );

   // ------------------------------------------------------------------
   // Case 7:
   // BUY TP must be based on FINAL widened stop distance.
   // ------------------------------------------------------------------

   const bool buyFinalRrPassed =
      buildSuccess;

   // Rebuild BUY widened case because the previous build is SELL.

   SetRiskPlan(
      plan,
      SIGNAL_BUY,
      100.20,
      0.10,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      30,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   const double buyFinalTakeProfitDistance =
      geometry.takeProfitPrice -
      geometry.entryPrice;

   RecordTestResult(
      "buy_tp_uses_final_stop_distance",
      buildSuccess &&
      buyFinalRrPassed &&
      NearlyEqual(
         buyFinalTakeProfitDistance,
         geometry.finalStopDistance *
         riskRewardRatio
      )
   );

   // ------------------------------------------------------------------
   // Case 8:
   // SELL TP must be based on FINAL widened stop distance.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_SELL,
      100.00,
      0.10,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      30,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   const double sellFinalTakeProfitDistance =
      geometry.entryPrice -
      geometry.takeProfitPrice;

   RecordTestResult(
      "sell_tp_uses_final_stop_distance",
      buildSuccess &&
      NearlyEqual(
         sellFinalTakeProfitDistance,
         geometry.finalStopDistance *
         riskRewardRatio
      )
   );

   // ------------------------------------------------------------------
   // Case 9:
   // On-grid geometry must report unchanged stop distance.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_BUY,
      100.20,
      1.00,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      0,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   RecordTestResult(
      "unchanged_stop_distance_detected",
      buildSuccess &&
      !geometry.stopDistanceChanged
   );

   // ------------------------------------------------------------------
   // Case 10:
   // Tick normalization must report changed stop distance.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_BUY,
      100.20,
      1.003,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      0,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   RecordTestResult(
      "tick_normalization_changes_stop_distance",
      buildSuccess &&
      geometry.stopDistanceChanged
   );

   // ------------------------------------------------------------------
   // Case 11:
   // StopsLevel widening must report changed stop distance.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_BUY,
      100.20,
      0.10,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      30,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   RecordTestResult(
      "stops_level_changes_stop_distance",
      buildSuccess &&
      geometry.stopDistanceChanged
   );

   // ------------------------------------------------------------------
   // Case 12:
   // Invalid BUY plan: SL is above entry.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_BUY,
      100.20,
      1.00,
      riskRewardRatio
   );

   plan.stopLossPrice =
      plan.entryPrice +
      0.10;

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      0,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   RecordTestResult(
      "invalid_buy_plan_rejected",
      !buildSuccess &&
      !geometry.valid &&
      geometry.status ==
         TRADE_GEOMETRY_INVALID_INPUT
   );

   // ------------------------------------------------------------------
   // Case 13:
   // Invalid SELL plan: SL is below entry.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_SELL,
      100.00,
      1.00,
      riskRewardRatio
   );

   plan.stopLossPrice =
      plan.entryPrice -
      0.10;

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      0,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   RecordTestResult(
      "invalid_sell_plan_rejected",
      !buildSuccess &&
      !geometry.valid &&
      geometry.status ==
         TRADE_GEOMETRY_INVALID_INPUT
   );

   // ------------------------------------------------------------------
   // Case 14:
   // Invalid market snapshot.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_BUY,
      100.20,
      1.00,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   snapshot.timeMsc = 0;

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      0,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   RecordTestResult(
      "invalid_snapshot_rejected",
      !buildSuccess &&
      !geometry.valid &&
      geometry.status ==
         TRADE_GEOMETRY_INVALID_INPUT
   );

   // ------------------------------------------------------------------
   // Case 15:
   // Invalid broker constraints.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_BUY,
      100.20,
      1.00,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.0,
      0,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   RecordTestResult(
      "invalid_constraints_rejected",
      !buildSuccess &&
      !geometry.valid &&
      geometry.status ==
         TRADE_GEOMETRY_INVALID_INPUT
   );

   // ------------------------------------------------------------------
   // Case 16:
   // Snapshot Point and constraint Point must agree.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_BUY,
      100.20,
      1.00,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.10,
      0.01,
      0,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   RecordTestResult(
      "point_mismatch_rejected",
      !buildSuccess &&
      !geometry.valid &&
      geometry.status ==
         TRADE_GEOMETRY_INVALID_INPUT
   );

   // ------------------------------------------------------------------
   // Case 17:
   // Normalize DOWN on-grid.
   // ------------------------------------------------------------------

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.05,
      0,
      0
   );

   double normalizedPrice = 0.0;

   const bool downOnGridSuccess =
      NormalizePriceDownToTick(
         100.25,
         constraints,
         normalizedPrice
      );

   RecordTestResult(
      "normalize_down_on_grid",
      downOnGridSuccess &&
      NearlyEqual(
         normalizedPrice,
         100.25
      )
   );

   // ------------------------------------------------------------------
   // Case 18:
   // Normalize DOWN off-grid.
   // ------------------------------------------------------------------

   normalizedPrice = 0.0;

   const bool downOffGridSuccess =
      NormalizePriceDownToTick(
         100.27,
         constraints,
         normalizedPrice
      );

   RecordTestResult(
      "normalize_down_off_grid",
      downOffGridSuccess &&
      NearlyEqual(
         normalizedPrice,
         100.25
      )
   );

   // ------------------------------------------------------------------
   // Case 19:
   // Normalize UP on-grid.
   // ------------------------------------------------------------------

   normalizedPrice = 0.0;

   const bool upOnGridSuccess =
      NormalizePriceUpToTick(
         100.25,
         constraints,
         normalizedPrice
      );

   RecordTestResult(
      "normalize_up_on_grid",
      upOnGridSuccess &&
      NearlyEqual(
         normalizedPrice,
         100.25
      )
   );

   // ------------------------------------------------------------------
   // Case 20:
   // Normalize UP off-grid.
   // ------------------------------------------------------------------

   normalizedPrice = 0.0;

   const bool upOffGridSuccess =
      NormalizePriceUpToTick(
         100.27,
         constraints,
         normalizedPrice
      );

   RecordTestResult(
      "normalize_up_off_grid",
      upOffGridSuccess &&
      NearlyEqual(
         normalizedPrice,
         100.30
      )
   );

   // ------------------------------------------------------------------
   // Case 21:
   // BUY must re-anchor to the fresh Ask even when the approved
   // RiskTradePlan was created from an older entry price.
   //
   // Note that the stop DISTANCE may remain unchanged even though
   // the absolute entry/SL/TP prices all change.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_BUY,
      99.80,
      1.00,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      0,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   RecordTestResult(
      "buy_reanchors_to_fresh_ask",
      buildSuccess &&
      GeometryMatches(
         geometry,
         SIGNAL_BUY,
         100.20,
         99.20,
         102.20,
         1.00,
         false
      )
   );

   // ------------------------------------------------------------------
   // Case 22:
   // SELL must re-anchor to the fresh Bid even when the approved
   // RiskTradePlan was created from an older entry price.
   // ------------------------------------------------------------------

   SetRiskPlan(
      plan,
      SIGNAL_SELL,
      100.40,
      1.00,
      riskRewardRatio
   );

   SetMarketSnapshot(
      snapshot,
      100.00,
      100.20,
      0.01
   );

   SetTradeDistanceConstraints(
      constraints,
      2,
      0.01,
      0.01,
      0,
      0
   );

   buildSuccess =
      BuildFinalTradeGeometry(
         plan,
         riskRewardRatio,
         snapshot,
         constraints,
         geometry
      );

   RecordTestResult(
      "sell_reanchors_to_fresh_bid",
      buildSuccess &&
      GeometryMatches(
         geometry,
         SIGNAL_SELL,
         100.00,
         101.00,
         98.00,
         1.00,
         false
      )
   );

   // ------------------------------------------------------------------
   // Final deterministic result.
   // ------------------------------------------------------------------

   PrintFormat(
      "GEOMETRY_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );

   // ------------------------------------------------------------------
   // Real broker-property observation.
   //
   // This is intentionally not counted as a deterministic test.
   // It confirms the current runtime values that the geometry code
   // would consume on the attached symbol.
   // ------------------------------------------------------------------

   TradeDistanceConstraints brokerConstraints;

   const bool brokerConstraintsLoaded =
      LoadCurrentTradeDistanceConstraints(
         _Symbol,
         brokerConstraints
      );

   PrintFormat(
      "GEOMETRY_CONSTRAINTS_OBSERVATION | symbol=%s | loaded=%s | digits=%d | point=%G | tick_size=%G | stops_level=%d | freeze_level=%d",
      _Symbol,
      brokerConstraintsLoaded
         ? "true"
         : "false",
      brokerConstraints.digits,
      brokerConstraints.point,
      brokerConstraints.tickSize,
      brokerConstraints.stopsLevelPoints,
      brokerConstraints.freezeLevelPoints
   );
}
