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

   const double scale =
      MathMax(
         1.0,
         MathMax(
            MathAbs(left),
            MathAbs(right)
         )
      );

   const double tolerance =
      MathMax(
         0.000000001,
         DBL_EPSILON * scale * 32.0
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
         "FINAL_RISK_SIZING_TEST_PASS | case=%s",
         caseName
      );

      return;
   }

   g_failed++;

   PrintFormat(
      "FINAL_RISK_SIZING_TEST_FAIL | case=%s",
      caseName
   );
}

void SetFinalGeometry(
   FinalTradeGeometry &geometry,
   const SignalDirection direction,
   const double entryPrice,
   const double stopLossPrice,
   const double takeProfitPrice
)
{
   ResetFinalTradeGeometry(
      geometry
   );

   geometry.valid = true;
   geometry.status =
      TRADE_GEOMETRY_VALID;

   geometry.direction =
      direction;

   geometry.entryPrice =
      entryPrice;

   geometry.stopLossPrice =
      stopLossPrice;

   geometry.takeProfitPrice =
      takeProfitPrice;

   geometry.originalStopDistance =
      MathAbs(
         entryPrice -
         stopLossPrice
      );

   geometry.finalStopDistance =
      geometry.originalStopDistance;

   geometry.stopDistanceChanged =
      false;
}

bool LoadCurrentVolumeRules(
   const string symbol,
   double &volumeMin,
   double &volumeMax,
   double &volumeStep
)
{
   volumeMin = 0.0;
   volumeMax = 0.0;
   volumeStep = 0.0;

   if(
      !SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MIN,
         volumeMin
      ) ||
      !SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MAX,
         volumeMax
      ) ||
      !SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_STEP,
         volumeStep
      )
   )
   {
      return(false);
   }

   return(
      MathIsValidNumber(volumeMin) &&
      MathIsValidNumber(volumeMax) &&
      MathIsValidNumber(volumeStep) &&
      volumeMin > 0.0 &&
      volumeMax > 0.0 &&
      volumeStep > 0.0 &&
      volumeMin <= volumeMax
   );
}

bool CalculateDirectRiskSizing(
   const string symbol,
   const FinalTradeGeometry &geometry,
   const double equity,
   const double riskPercent,
   const double volumeMin,
   const double volumeMax,
   const double volumeStep,
   RiskSizingResult &sizing,
   double &normalizedVolume
)
{
   normalizedVolume = 0.0;

   if(!CalculateRawRiskVolume(
      symbol,
      geometry.direction,
      geometry.entryPrice,
      geometry.stopLossPrice,
      equity,
      riskPercent,
      volumeMin,
      sizing
   ))
   {
      return(false);
   }

   return(
      NormalizeRiskVolumeDown(
         sizing.rawVolume,
         volumeMin,
         volumeMax,
         volumeStep,
         normalizedVolume
      )
   );
}

bool RiskSizingMatches(
   const FinalRiskSizingResult &wrapped,
   const RiskSizingResult &direct,
   const double directNormalizedVolume
)
{
   return(
      wrapped.valid &&
      wrapped.status ==
         FINAL_RISK_SIZING_VALID &&
      NearlyEqual(
         wrapped.sizing.equity,
         direct.equity
      ) &&
      NearlyEqual(
         wrapped.sizing.plannedRiskAmount,
         direct.plannedRiskAmount
      ) &&
      NearlyEqual(
         wrapped.sizing.referenceVolume,
         direct.referenceVolume
      ) &&
      NearlyEqual(
         wrapped.sizing.lossForReferenceVolume,
         direct.lossForReferenceVolume
      ) &&
      NearlyEqual(
         wrapped.sizing.rawVolume,
         direct.rawVolume
      ) &&
      NearlyEqual(
         wrapped.normalizedVolume,
         directNormalizedVolume
      )
   );
}

// Focused integration fixture: a synthetic broker stops level widens
// an approved 0.50 price-unit stop. No request or order is submitted.
bool VerifyStopWideningPreservesRiskBudget(
   const SignalDirection direction,
   const double equity,
   const double riskPercent,
   const double volumeMin,
   const double volumeMax,
   const double volumeStep
)
{
   PreTradeMarketSnapshot snapshot;
   ResetPreTradeMarketSnapshot(snapshot);

   snapshot.symbol = _Symbol;
   snapshot.timeMsc = 1000;
   snapshot.bid = 4000.00;
   snapshot.ask = 4000.10;
   snapshot.point = 0.01;

   TradeDistanceConstraints constraints;
   ResetTradeDistanceConstraints(constraints);

   constraints.digits = 2;
   constraints.point = 0.01;
   constraints.tickSize = 0.01;
   constraints.stopsLevelPoints = 200;
   constraints.freezeLevelPoints = 0;

   const double riskRewardRatio = 2.0;
   const double originalStopDistance = 0.50;

   RiskTradePlan plan;
   plan.direction = direction;
   plan.entryPrice =
      (direction == SIGNAL_BUY)
      ? snapshot.ask
      : snapshot.bid;
   plan.stopDistance = originalStopDistance;

   if(direction == SIGNAL_BUY)
   {
      plan.stopLossPrice =
         plan.entryPrice - originalStopDistance;
      plan.takeProfitPrice =
         plan.entryPrice + originalStopDistance * riskRewardRatio;
   }
   else if(direction == SIGNAL_SELL)
   {
      plan.stopLossPrice =
         plan.entryPrice + originalStopDistance;
      plan.takeProfitPrice =
         plan.entryPrice - originalStopDistance * riskRewardRatio;
   }
   else
   {
      return(false);
   }

   FinalTradeGeometry initialGeometry;
   SetFinalGeometry(
      initialGeometry,
      direction,
      plan.entryPrice,
      plan.stopLossPrice,
      plan.takeProfitPrice
   );

   FinalTradeGeometry finalGeometry;

   if(!BuildFinalTradeGeometry(
      plan,
      riskRewardRatio,
      snapshot,
      constraints,
      finalGeometry
   ))
   {
      return(false);
   }

   if(
      !finalGeometry.valid ||
      !finalGeometry.stopDistanceChanged ||
      finalGeometry.finalStopDistance <= originalStopDistance
   )
   {
      return(false);
   }

   FinalRiskSizingResult initialSizing;
   FinalRiskSizingResult finalSizing;

   if(!CalculateFinalRiskSizing(
      _Symbol,
      initialGeometry,
      equity,
      riskPercent,
      volumeMin,
      volumeMax,
      volumeStep,
      initialSizing
   ))
   {
      return(false);
   }

   if(!CalculateFinalRiskSizing(
      _Symbol,
      finalGeometry,
      equity,
      riskPercent,
      volumeMin,
      volumeMax,
      volumeStep,
      finalSizing
   ))
   {
      return(false);
   }

   double projectedProfitAtStop = 0.0;

   const ENUM_ORDER_TYPE orderType =
      (direction == SIGNAL_BUY)
      ? ORDER_TYPE_BUY
      : ORDER_TYPE_SELL;

   if(!OrderCalcProfit(
      orderType,
      _Symbol,
      finalSizing.normalizedVolume,
      finalGeometry.entryPrice,
      finalGeometry.stopLossPrice,
      projectedProfitAtStop
   ))
   {
      return(false);
   }

   const double plannedRisk = equity * riskPercent / 100.0;
   const double estimatedLoss = -projectedProfitAtStop;
   const double moneyTolerance =
      0.0000001 * MathMax(1.0, plannedRisk);

   PrintFormat(
      "FINAL_RISK_SIZING_WIDENED_STOP | direction=%s | initial_stop=%G | final_stop=%G | initial_raw_volume=%G | final_raw_volume=%G | final_normalized_volume=%G | planned_risk=%G | estimated_stop_loss=%G",
      EnumToString(direction),
      originalStopDistance,
      finalGeometry.finalStopDistance,
      initialSizing.sizing.rawVolume,
      finalSizing.sizing.rawVolume,
      finalSizing.normalizedVolume,
      plannedRisk,
      estimatedLoss
   );

   return(
      MathIsValidNumber(projectedProfitAtStop) &&
      projectedProfitAtStop < 0.0 &&
      finalSizing.sizing.rawVolume < initialSizing.sizing.rawVolume &&
      finalSizing.normalizedVolume <=
         finalSizing.sizing.rawVolume + 0.000000001 &&
      estimatedLoss <= plannedRisk + moneyTolerance
   );
}

void OnStart()
{
   double volumeMin = 0.0;
   double volumeMax = 0.0;
   double volumeStep = 0.0;

   if(!LoadCurrentVolumeRules(
      _Symbol,
      volumeMin,
      volumeMax,
      volumeStep
   ))
   {
      PrintFormat(
         "FINAL_RISK_SIZING_TEST_ABORT | unable to load volume rules for %s",
         _Symbol
      );

      return;
   }

   const double equity =
      100000.0;

   const double riskPercent =
      1.0;

   FinalTradeGeometry geometry;
   FinalRiskSizingResult wrappedResult;
   RiskSizingResult directSizing;

   double directNormalizedVolume =
      0.0;

   bool wrappedSuccess = false;
   bool directSuccess = false;

   // ---------------------------------------------------------------
   // Case 1:
   // Valid BUY final geometry.
   // ---------------------------------------------------------------

   SetFinalGeometry(
      geometry,
      SIGNAL_BUY,
      4000.0,
      3990.0,
      4020.0
   );

   wrappedSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         wrappedResult
      );

   directSuccess =
      CalculateDirectRiskSizing(
         _Symbol,
         geometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         directSizing,
         directNormalizedVolume
      );

   RecordTestResult(
      "valid_buy_matches_direct_risk_manager",
      wrappedSuccess &&
      directSuccess &&
      RiskSizingMatches(
         wrappedResult,
         directSizing,
         directNormalizedVolume
      )
   );

   // ---------------------------------------------------------------
   // Case 2:
   // Valid SELL final geometry.
   // ---------------------------------------------------------------

   SetFinalGeometry(
      geometry,
      SIGNAL_SELL,
      4000.0,
      4010.0,
      3980.0
   );

   wrappedSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         wrappedResult
      );

   directSuccess =
      CalculateDirectRiskSizing(
         _Symbol,
         geometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         directSizing,
         directNormalizedVolume
      );

   RecordTestResult(
      "valid_sell_matches_direct_risk_manager",
      wrappedSuccess &&
      directSuccess &&
      RiskSizingMatches(
         wrappedResult,
         directSizing,
         directNormalizedVolume
      )
   );

   // ---------------------------------------------------------------
   // Case 3:
   // Planned monetary risk must remain equity × RiskPercent.
   // ---------------------------------------------------------------

   SetFinalGeometry(
      geometry,
      SIGNAL_BUY,
      4000.0,
      3990.0,
      4020.0
   );

   wrappedSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         wrappedResult
      );

   const double expectedPlannedRisk =
      equity *
      (riskPercent / 100.0);

   RecordTestResult(
      "planned_risk_amount_preserved",
      wrappedSuccess &&
      NearlyEqual(
         wrappedResult.sizing.plannedRiskAmount,
         expectedPlannedRisk
      )
   );

   // ---------------------------------------------------------------
   // Case 4:
   // Conservative normalization must never exceed raw risk volume
   // except for negligible floating-point tolerance.
   // ---------------------------------------------------------------

   RecordTestResult(
      "normalized_volume_not_above_raw_volume",
      wrappedSuccess &&
      wrappedResult.normalizedVolume <=
         wrappedResult.sizing.rawVolume +
         0.000000001
   );

   // ---------------------------------------------------------------
   // Case 5:
   // Empty symbol must fail before raw sizing.
   // ---------------------------------------------------------------

   wrappedSuccess =
      CalculateFinalRiskSizing(
         "",
         geometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         wrappedResult
      );

   RecordTestResult(
      "empty_symbol_rejected",
      !wrappedSuccess &&
      !wrappedResult.valid &&
      wrappedResult.status ==
         FINAL_RISK_SIZING_INVALID_INPUT
   );

   // ---------------------------------------------------------------
   // Case 6:
   // Geometry not marked valid must fail safe.
   // ---------------------------------------------------------------

   SetFinalGeometry(
      geometry,
      SIGNAL_BUY,
      4000.0,
      3990.0,
      4020.0
   );

   geometry.valid = false;

   wrappedSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         wrappedResult
      );

   RecordTestResult(
      "invalid_geometry_rejected",
      !wrappedSuccess &&
      !wrappedResult.valid &&
      wrappedResult.status ==
         FINAL_RISK_SIZING_INVALID_INPUT
   );

   // ---------------------------------------------------------------
   // Case 7:
   // Stored final stop distance must match entry-to-SL geometry.
   // ---------------------------------------------------------------

   SetFinalGeometry(
      geometry,
      SIGNAL_BUY,
      4000.0,
      3990.0,
      4020.0
   );

   geometry.finalStopDistance =
      11.0;

   wrappedSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         wrappedResult
      );

   RecordTestResult(
      "inconsistent_final_stop_distance_rejected",
      !wrappedSuccess &&
      !wrappedResult.valid &&
      wrappedResult.status ==
         FINAL_RISK_SIZING_INVALID_INPUT
   );

   // ---------------------------------------------------------------
   // Case 8:
   // Invalid equity is rejected by the existing RiskManager.
   // ---------------------------------------------------------------

   SetFinalGeometry(
      geometry,
      SIGNAL_BUY,
      4000.0,
      3990.0,
      4020.0
   );

   wrappedSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         0.0,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         wrappedResult
      );

   RecordTestResult(
      "invalid_equity_rejected",
      !wrappedSuccess &&
      !wrappedResult.valid &&
      wrappedResult.status ==
         FINAL_RISK_SIZING_RAW_CALCULATION_FAILED
   );

   // ---------------------------------------------------------------
   // Case 9:
   // Invalid RiskPercent is rejected by the existing RiskManager.
   // ---------------------------------------------------------------

   wrappedSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         equity,
         0.0,
         volumeMin,
         volumeMax,
         volumeStep,
         wrappedResult
      );

   RecordTestResult(
      "invalid_risk_percent_rejected",
      !wrappedSuccess &&
      !wrappedResult.valid &&
      wrappedResult.status ==
         FINAL_RISK_SIZING_RAW_CALCULATION_FAILED
   );

   // ---------------------------------------------------------------
   // Case 10:
   // Invalid volumeMin also invalidates the reference volume used
   // by CalculateRawRiskVolume().
   // ---------------------------------------------------------------

   wrappedSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         equity,
         riskPercent,
         0.0,
         volumeMax,
         volumeStep,
         wrappedResult
      );

   RecordTestResult(
      "invalid_volume_min_rejected",
      !wrappedSuccess &&
      !wrappedResult.valid &&
      wrappedResult.status ==
         FINAL_RISK_SIZING_RAW_CALCULATION_FAILED
   );

   // ---------------------------------------------------------------
   // Case 11:
   // volumeMax below volumeMin must fail during conservative
   // normalization.
   // ---------------------------------------------------------------

   wrappedSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMin * 0.5,
         volumeStep,
         wrappedResult
      );

   RecordTestResult(
      "invalid_volume_bounds_rejected",
      !wrappedSuccess &&
      !wrappedResult.valid &&
      wrappedResult.status ==
         FINAL_RISK_SIZING_NORMALIZATION_FAILED
   );

   // ---------------------------------------------------------------
   // Case 12:
   // Invalid volume step must fail during normalization.
   // ---------------------------------------------------------------

   wrappedSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         0.0,
         wrappedResult
      );

   RecordTestResult(
      "invalid_volume_step_rejected",
      !wrappedSuccess &&
      !wrappedResult.valid &&
      wrappedResult.status ==
         FINAL_RISK_SIZING_NORMALIZATION_FAILED
   );

   // ---------------------------------------------------------------
   // Case 13:
   // A valid but extremely small risk budget must not be rounded UP
   // to the broker minimum volume.
   // ---------------------------------------------------------------

   const double tinyRiskPercent =
      0.0000001;

   wrappedSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         equity,
         tinyRiskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         wrappedResult
      );

   RecordTestResult(
      "below_minimum_volume_rejected",
      !wrappedSuccess &&
      !wrappedResult.valid &&
      wrappedResult.status ==
         FINAL_RISK_SIZING_NORMALIZATION_FAILED
   );

   // ---------------------------------------------------------------
   // Case 14:
   // Very large raw risk sizing may be capped DOWN by broker
   // volumeMax, but it must still match direct RiskManager behavior.
   // ---------------------------------------------------------------

   const double largeEquity =
      1000000000000.0;

   const double largeRiskPercent =
      100.0;

   wrappedSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         largeEquity,
         largeRiskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         wrappedResult
      );

   directSuccess =
      CalculateDirectRiskSizing(
         _Symbol,
         geometry,
         largeEquity,
         largeRiskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         directSizing,
         directNormalizedVolume
      );

   RecordTestResult(
      "large_volume_caps_down_consistently",
      wrappedSuccess &&
      directSuccess &&
      RiskSizingMatches(
         wrappedResult,
         directSizing,
         directNormalizedVolume
      ) &&
      wrappedResult.normalizedVolume <=
         volumeMax + 0.000000001
   );

   // ---------------------------------------------------------------
   // Case 15:
   // Final sizing must be driven by FINAL geometry, not any original
   // Phase 6 plan. Two different final stop distances should produce
   // different raw sizing for the same equity/risk budget.
   // ---------------------------------------------------------------

   SetFinalGeometry(
      geometry,
      SIGNAL_BUY,
      4000.0,
      3990.0,
      4020.0
   );

   FinalRiskSizingResult narrowStopResult;

   const bool narrowStopSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         narrowStopResult
      );

   SetFinalGeometry(
      geometry,
      SIGNAL_BUY,
      4000.0,
      3980.0,
      4040.0
   );

   FinalRiskSizingResult wideStopResult;

   const bool wideStopSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         wideStopResult
      );

   RecordTestResult(
      "final_stop_distance_drives_resizing",
      narrowStopSuccess &&
      wideStopSuccess &&
      wideStopResult.sizing.rawVolume <
         narrowStopResult.sizing.rawVolume
   );

   // ---------------------------------------------------------------
   // Cases 16-17:
   // Simulated stops-level widening must trigger smaller final sizing
   // and keep estimated SL loss within the same monetary risk budget.
   // This exercises geometry -> sizing, not live broker submission.
   // ---------------------------------------------------------------

   RecordTestResult(
      "synthetic_buy_stop_widening_resizes_within_budget",
      VerifyStopWideningPreservesRiskBudget(
         SIGNAL_BUY,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep
      )
   );

   RecordTestResult(
      "synthetic_sell_stop_widening_resizes_within_budget",
      VerifyStopWideningPreservesRiskBudget(
         SIGNAL_SELL,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep
      )
   );

   // ---------------------------------------------------------------
   // Final broker-aware validation result.
   // ---------------------------------------------------------------

   PrintFormat(
      "FINAL_RISK_SIZING_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );

   // ---------------------------------------------------------------
   // Runtime observation using the current attached symbol.
   // No order is submitted.
   // ---------------------------------------------------------------

   SetFinalGeometry(
      geometry,
      SIGNAL_BUY,
      4000.0,
      3990.0,
      4020.0
   );

   wrappedSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         geometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         wrappedResult
      );

   PrintFormat(
      "FINAL_RISK_SIZING_OBSERVATION | symbol=%s | success=%s | status=%s | equity=%G | risk_percent=%G | planned_risk=%G | reference_volume=%G | reference_loss=%G | raw_volume=%G | normalized_volume=%G | volume_min=%G | volume_max=%G | volume_step=%G",
      _Symbol,
      wrappedSuccess ? "true" : "false",
      EnumToString(wrappedResult.status),
      wrappedResult.sizing.equity,
      riskPercent,
      wrappedResult.sizing.plannedRiskAmount,
      wrappedResult.sizing.referenceVolume,
      wrappedResult.sizing.lossForReferenceVolume,
      wrappedResult.sizing.rawVolume,
      wrappedResult.normalizedVolume,
      volumeMin,
      volumeMax,
      volumeStep
   );
}
