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
         "MARGIN_TEST_PASS | case=%s",
         caseName
      );

      return;
   }

   g_failed++;

   PrintFormat(
      "MARGIN_TEST_FAIL | case=%s",
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

void SetValidRiskSizing(
   FinalRiskSizingResult &riskSizing,
   const double rawVolume,
   const double normalizedVolume
)
{
   ResetFinalRiskSizingResult(
      riskSizing
   );

   riskSizing.valid = true;
   riskSizing.status =
      FINAL_RISK_SIZING_VALID;

   riskSizing.sizing.equity =
      100000.0;

   riskSizing.sizing.plannedRiskAmount =
      1000.0;

   riskSizing.sizing.referenceVolume =
      0.01;

   riskSizing.sizing.lossForReferenceVolume =
      10.0;

   riskSizing.sizing.rawVolume =
      rawVolume;

   riskSizing.normalizedVolume =
      normalizedVolume;
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

bool LoadCurrentMarketGeometry(
   FinalTradeGeometry &buyGeometry,
   FinalTradeGeometry &sellGeometry
)
{
   MqlTick tick = {};

   ResetLastError();

   if(!SymbolInfoTick(
      _Symbol,
      tick
   ))
   {
      PrintFormat(
         "MARGIN_TEST_ABORT | SymbolInfoTick failed | error=%d",
         GetLastError()
      );

      return(false);
   }

   double point = 0.0;

   if(!SymbolInfoDouble(
      _Symbol,
      SYMBOL_POINT,
      point
   ))
   {
      return(false);
   }

   if(
      !MathIsValidNumber(tick.bid) ||
      !MathIsValidNumber(tick.ask) ||
      !MathIsValidNumber(point) ||
      tick.bid <= 0.0 ||
      tick.ask <= 0.0 ||
      tick.ask < tick.bid ||
      point <= 0.0
   )
   {
      return(false);
   }

   const double buyDistance =
      MathMax(
         point * 100.0,
         tick.ask * 0.001
      );

   const double sellDistance =
      MathMax(
         point * 100.0,
         tick.bid * 0.001
      );

   if(
      buyDistance >= tick.ask ||
      sellDistance >= tick.bid
   )
   {
      return(false);
   }

   SetFinalGeometry(
      buyGeometry,
      SIGNAL_BUY,
      tick.ask,
      tick.ask - buyDistance,
      tick.ask + buyDistance * 2.0
   );

   SetFinalGeometry(
      sellGeometry,
      SIGNAL_SELL,
      tick.bid,
      tick.bid + sellDistance,
      tick.bid - sellDistance * 2.0
   );

   return(
      sellGeometry.takeProfitPrice > 0.0
   );
}

void OnStart()
{
   // ---------------------------------------------------------------
   // Case 1:
   // Reset must restore a known fail-safe state.
   // ---------------------------------------------------------------

   MarginValidationResult marginResult;

   marginResult.allowed = true;
   marginResult.status =
      MARGIN_VALIDATION_ALLOWED;
   marginResult.requiredMargin = 10.0;
   marginResult.freeMargin = 20.0;
   marginResult.remainingFreeMargin = 10.0;

   ResetMarginValidationResult(
      marginResult
   );

   RecordTestResult(
      "reset_state",
      !marginResult.allowed &&
      marginResult.status ==
         MARGIN_VALIDATION_NOT_EVALUATED &&
      marginResult.requiredMargin == 0.0 &&
      marginResult.freeMargin == 0.0 &&
      marginResult.remainingFreeMargin == 0.0
   );

   // ---------------------------------------------------------------
   // Case 2:
   // Sufficient synthetic free margin.
   // ---------------------------------------------------------------

   bool evaluationSuccess =
      EvaluateMarginCapacity(
         1000.0,
         5000.0,
         marginResult
      );

   RecordTestResult(
      "sufficient_margin_allowed",
      evaluationSuccess &&
      marginResult.allowed &&
      marginResult.status ==
         MARGIN_VALIDATION_ALLOWED &&
      NearlyEqual(
         marginResult.requiredMargin,
         1000.0
      ) &&
      NearlyEqual(
         marginResult.freeMargin,
         5000.0
      ) &&
      NearlyEqual(
         marginResult.remainingFreeMargin,
         4000.0
      )
   );

   // ---------------------------------------------------------------
   // Case 3:
   // Exact equality is sufficient.
   // ---------------------------------------------------------------

   evaluationSuccess =
      EvaluateMarginCapacity(
         1000.0,
         1000.0,
         marginResult
      );

   RecordTestResult(
      "exact_margin_boundary_allowed",
      evaluationSuccess &&
      marginResult.allowed &&
      marginResult.status ==
         MARGIN_VALIDATION_ALLOWED &&
      NearlyEqual(
         marginResult.remainingFreeMargin,
         0.0
      )
   );

   // ---------------------------------------------------------------
   // Case 4:
   // Insufficient free margin is a successfully evaluated rejection,
   // not a technical failure.
   // ---------------------------------------------------------------

   evaluationSuccess =
      EvaluateMarginCapacity(
         1000.0,
         999.0,
         marginResult
      );

   RecordTestResult(
      "insufficient_margin_rejected",
      evaluationSuccess &&
      !marginResult.allowed &&
      marginResult.status ==
         MARGIN_VALIDATION_INSUFFICIENT_FREE_MARGIN &&
      NearlyEqual(
         marginResult.remainingFreeMargin,
         -1.0
      )
   );

   // ---------------------------------------------------------------
   // Case 5:
   // Negative free margin is a valid observed account state for this
   // gate: evaluation succeeds, but a new trade is rejected.
   // ---------------------------------------------------------------

   evaluationSuccess =
      EvaluateMarginCapacity(
         1000.0,
         -100.0,
         marginResult
      );

   RecordTestResult(
      "negative_free_margin_rejected",
      evaluationSuccess &&
      !marginResult.allowed &&
      marginResult.status ==
         MARGIN_VALIDATION_INSUFFICIENT_FREE_MARGIN &&
      NearlyEqual(
         marginResult.remainingFreeMargin,
         -1100.0
      )
   );

   // ---------------------------------------------------------------
   // Case 6:
   // Zero required margin is structurally valid at this layer.
   // We do not invent a generic > 0 platform invariant.
   // ---------------------------------------------------------------

   evaluationSuccess =
      EvaluateMarginCapacity(
         0.0,
         1000.0,
         marginResult
      );

   RecordTestResult(
      "zero_required_margin_allowed",
      evaluationSuccess &&
      marginResult.allowed &&
      marginResult.status ==
         MARGIN_VALIDATION_ALLOWED &&
      NearlyEqual(
         marginResult.remainingFreeMargin,
         1000.0
      )
   );

   // ---------------------------------------------------------------
   // Case 7:
   // Negative required margin is invalid input.
   // ---------------------------------------------------------------

   evaluationSuccess =
      EvaluateMarginCapacity(
         -1.0,
         1000.0,
         marginResult
      );

   RecordTestResult(
      "negative_required_margin_rejected",
      !evaluationSuccess &&
      !marginResult.allowed &&
      marginResult.status ==
         MARGIN_VALIDATION_INVALID_INPUT
   );

   // ---------------------------------------------------------------
   // Prepare current-symbol runtime inputs.
   // ---------------------------------------------------------------

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
         "MARGIN_TEST_ABORT | unable to load volume rules for %s",
         _Symbol
      );

      return;
   }

   FinalTradeGeometry buyGeometry;
   FinalTradeGeometry sellGeometry;

   if(!LoadCurrentMarketGeometry(
      buyGeometry,
      sellGeometry
   ))
   {
      PrintFormat(
         "MARGIN_TEST_ABORT | unable to build current market geometry for %s",
         _Symbol
      );

      return;
   }

   FinalRiskSizingResult buyRiskSizing;
   FinalRiskSizingResult sellRiskSizing;

   const double equity =
      100000.0;

   const double riskPercent =
      1.0;

   const bool buySizingSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         buyGeometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         buyRiskSizing
      );

   const bool sellSizingSuccess =
      CalculateFinalRiskSizing(
         _Symbol,
         sellGeometry,
         equity,
         riskPercent,
         volumeMin,
         volumeMax,
         volumeStep,
         sellRiskSizing
      );

   if(
      !buySizingSuccess ||
      !sellSizingSuccess
   )
   {
      Print(
         "MARGIN_TEST_ABORT | unable to calculate runtime final risk sizing."
      );

      return;
   }

   // ---------------------------------------------------------------
   // Case 8:
   // BUY required margin must exactly match direct OrderCalcMargin.
   // ---------------------------------------------------------------

   double buyRequiredMargin = 0.0;

   const bool buyMarginSuccess =
      CalculateRequiredMargin(
         _Symbol,
         buyGeometry,
         buyRiskSizing,
         buyRequiredMargin
      );

   double directBuyMargin = 0.0;

   ResetLastError();

   const bool directBuySuccess =
      OrderCalcMargin(
         ORDER_TYPE_BUY,
         _Symbol,
         buyRiskSizing.normalizedVolume,
         buyGeometry.entryPrice,
         directBuyMargin
      );

   RecordTestResult(
      "buy_margin_matches_direct_order_calc_margin",
      buyMarginSuccess &&
      directBuySuccess &&
      NearlyEqual(
         buyRequiredMargin,
         directBuyMargin
      )
   );

   // ---------------------------------------------------------------
   // Case 9:
   // SELL required margin must exactly match direct OrderCalcMargin.
   // ---------------------------------------------------------------

   double sellRequiredMargin = 0.0;

   const bool sellMarginSuccess =
      CalculateRequiredMargin(
         _Symbol,
         sellGeometry,
         sellRiskSizing,
         sellRequiredMargin
      );

   double directSellMargin = 0.0;

   ResetLastError();

   const bool directSellSuccess =
      OrderCalcMargin(
         ORDER_TYPE_SELL,
         _Symbol,
         sellRiskSizing.normalizedVolume,
         sellGeometry.entryPrice,
         directSellMargin
      );

   RecordTestResult(
      "sell_margin_matches_direct_order_calc_margin",
      sellMarginSuccess &&
      directSellSuccess &&
      NearlyEqual(
         sellRequiredMargin,
         directSellMargin
      )
   );

   // ---------------------------------------------------------------
   // Case 10:
   // Invalid geometry must be rejected before OrderCalcMargin.
   // ---------------------------------------------------------------

   FinalTradeGeometry invalidGeometry =
      buyGeometry;

   invalidGeometry.valid = false;

   double invalidRequiredMargin = 0.0;

   const bool invalidGeometrySuccess =
      CalculateRequiredMargin(
         _Symbol,
         invalidGeometry,
         buyRiskSizing,
         invalidRequiredMargin
      );

   RecordTestResult(
      "invalid_geometry_rejected",
      !invalidGeometrySuccess &&
      invalidRequiredMargin == 0.0
   );

   // ---------------------------------------------------------------
   // Case 11:
   // Invalid risk-sizing contract must be rejected.
   // ---------------------------------------------------------------

   FinalRiskSizingResult invalidRiskSizing =
      buyRiskSizing;

   invalidRiskSizing.valid = false;

   invalidRequiredMargin = 0.0;

   const bool invalidRiskSizingSuccess =
      CalculateRequiredMargin(
         _Symbol,
         buyGeometry,
         invalidRiskSizing,
         invalidRequiredMargin
      );

   RecordTestResult(
      "invalid_risk_sizing_rejected",
      !invalidRiskSizingSuccess &&
      invalidRequiredMargin == 0.0
   );

   // ---------------------------------------------------------------
   // Case 12:
   // Corrupted normalized volume must not exceed raw risk volume.
   // ---------------------------------------------------------------

   FinalRiskSizingResult corruptedRiskSizing =
      buyRiskSizing;

   corruptedRiskSizing.normalizedVolume =
      corruptedRiskSizing.sizing.rawVolume +
      MathMax(
         1.0,
         corruptedRiskSizing.sizing.rawVolume
      );

   invalidRequiredMargin = 0.0;

   const bool corruptedRiskSizingSuccess =
      CalculateRequiredMargin(
         _Symbol,
         buyGeometry,
         corruptedRiskSizing,
         invalidRequiredMargin
      );

   RecordTestResult(
      "normalized_volume_above_raw_rejected",
      !corruptedRiskSizingSuccess &&
      invalidRequiredMargin == 0.0
   );

   // ---------------------------------------------------------------
   // Case 13:
   // Empty symbol must fail safe.
   // ---------------------------------------------------------------

   invalidRequiredMargin = 0.0;

   const bool emptySymbolSuccess =
      CalculateRequiredMargin(
         "",
         buyGeometry,
         buyRiskSizing,
         invalidRequiredMargin
      );

   RecordTestResult(
      "empty_symbol_rejected",
      !emptySymbolSuccess &&
      invalidRequiredMargin == 0.0
   );

   // ---------------------------------------------------------------
   // Case 14:
   // Current account free-margin loader must match AccountInfoDouble.
   // ---------------------------------------------------------------

   double loadedFreeMargin = 0.0;

   const bool freeMarginLoaded =
      LoadCurrentFreeMargin(
         loadedFreeMargin
      );

   const double directFreeMargin =
      AccountInfoDouble(
         ACCOUNT_MARGIN_FREE
      );

   RecordTestResult(
      "free_margin_matches_account_state",
      freeMarginLoaded &&
      MathIsValidNumber(directFreeMargin) &&
      NearlyEqual(
         loadedFreeMargin,
         directFreeMargin
      )
   );

   // ---------------------------------------------------------------
   // Case 15:
   // End-to-end current BUY margin evaluation.
   // Either ALLOWED or INSUFFICIENT is a valid successful evaluation.
   // ---------------------------------------------------------------

   MarginValidationResult currentBuyResult;

   const bool currentBuySuccess =
      EvaluateCurrentMarginCapacity(
         _Symbol,
         buyGeometry,
         buyRiskSizing,
         currentBuyResult
      );

   const bool currentBuyStatusValid =
      currentBuyResult.status ==
         MARGIN_VALIDATION_ALLOWED ||
      currentBuyResult.status ==
         MARGIN_VALIDATION_INSUFFICIENT_FREE_MARGIN;

   const bool currentBuyDecisionConsistent =
      (
         currentBuyResult.allowed &&
         currentBuyResult.requiredMargin <=
            currentBuyResult.freeMargin
      ) ||
      (
         !currentBuyResult.allowed &&
         currentBuyResult.requiredMargin >
            currentBuyResult.freeMargin
      );

   RecordTestResult(
      "current_buy_margin_evaluation_consistent",
      currentBuySuccess &&
      currentBuyStatusValid &&
      currentBuyDecisionConsistent &&
      NearlyEqual(
         currentBuyResult.requiredMargin,
         buyRequiredMargin
      ) &&
      NearlyEqual(
         currentBuyResult.freeMargin,
         directFreeMargin
      ) &&
      NearlyEqual(
         currentBuyResult.remainingFreeMargin,
         currentBuyResult.freeMargin -
         currentBuyResult.requiredMargin
      )
   );

   // ---------------------------------------------------------------
   // Case 16:
   // End-to-end current SELL margin evaluation.
   // ---------------------------------------------------------------

   MarginValidationResult currentSellResult;

   const bool currentSellSuccess =
      EvaluateCurrentMarginCapacity(
         _Symbol,
         sellGeometry,
         sellRiskSizing,
         currentSellResult
      );

   const bool currentSellStatusValid =
      currentSellResult.status ==
         MARGIN_VALIDATION_ALLOWED ||
      currentSellResult.status ==
         MARGIN_VALIDATION_INSUFFICIENT_FREE_MARGIN;

   const bool currentSellDecisionConsistent =
      (
         currentSellResult.allowed &&
         currentSellResult.requiredMargin <=
            currentSellResult.freeMargin
      ) ||
      (
         !currentSellResult.allowed &&
         currentSellResult.requiredMargin >
            currentSellResult.freeMargin
      );

   RecordTestResult(
      "current_sell_margin_evaluation_consistent",
      currentSellSuccess &&
      currentSellStatusValid &&
      currentSellDecisionConsistent &&
      NearlyEqual(
         currentSellResult.requiredMargin,
         sellRequiredMargin
      ) &&
      NearlyEqual(
         currentSellResult.freeMargin,
         directFreeMargin
      ) &&
      NearlyEqual(
         currentSellResult.remainingFreeMargin,
         currentSellResult.freeMargin -
         currentSellResult.requiredMargin
      )
   );

   // ---------------------------------------------------------------
   // Final deterministic/runtime result.
   // ---------------------------------------------------------------

   PrintFormat(
      "MARGIN_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );

   PrintFormat(
      "MARGIN_BUY_OBSERVATION | symbol=%s | evaluation_success=%s | allowed=%s | status=%s | entry=%G | volume=%G | required_margin=%G | free_margin=%G | remaining_free_margin=%G",
      _Symbol,
      currentBuySuccess ? "true" : "false",
      currentBuyResult.allowed ? "true" : "false",
      EnumToString(currentBuyResult.status),
      buyGeometry.entryPrice,
      buyRiskSizing.normalizedVolume,
      currentBuyResult.requiredMargin,
      currentBuyResult.freeMargin,
      currentBuyResult.remainingFreeMargin
   );

   PrintFormat(
      "MARGIN_SELL_OBSERVATION | symbol=%s | evaluation_success=%s | allowed=%s | status=%s | entry=%G | volume=%G | required_margin=%G | free_margin=%G | remaining_free_margin=%G",
      _Symbol,
      currentSellSuccess ? "true" : "false",
      currentSellResult.allowed ? "true" : "false",
      EnumToString(currentSellResult.status),
      sellGeometry.entryPrice,
      sellRiskSizing.normalizedVolume,
      currentSellResult.requiredMargin,
      currentSellResult.freeMargin,
      currentSellResult.remainingFreeMargin
   );
}
