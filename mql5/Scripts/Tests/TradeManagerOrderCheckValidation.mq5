#property strict

#include <XAUForge/TradeManager.mqh>

int g_passed = 0;
int g_failed = 0;

void RecordTestResult(
   const string caseName,
   const bool passed
)
{
   if(passed)
   {
      g_passed++;

      PrintFormat(
         "ORDER_CHECK_TEST_PASS | case=%s",
         caseName
      );

      return;
   }

   g_failed++;

   PrintFormat(
      "ORDER_CHECK_TEST_FAIL | case=%s",
      caseName
   );
}

bool LoadCurrentRequestInputs(
   const SignalDirection direction,
   MarketTradeRequestBuildResult &requestBuild
)
{
   ResetMarketTradeRequestBuildResult(
      requestBuild
   );

   if(
      direction != SIGNAL_BUY &&
      direction != SIGNAL_SELL
   )
   {
      return(false);
   }

   MqlTick tick = {};

   ResetLastError();

   if(!SymbolInfoTick(
      _Symbol,
      tick
   ))
   {
      PrintFormat(
         "ORDER_CHECK_TEST_ABORT | SymbolInfoTick failed | error=%d",
         GetLastError()
      );

      return(false);
   }

   double point = 0.0;
   double tickSize = 0.0;
   double volumeMin = 0.0;

   long digitsValue = 0;
   long stopsLevelValue = 0;

   if(
      !SymbolInfoDouble(
         _Symbol,
         SYMBOL_POINT,
         point
      ) ||
      !SymbolInfoDouble(
         _Symbol,
         SYMBOL_TRADE_TICK_SIZE,
         tickSize
      ) ||
      !SymbolInfoDouble(
         _Symbol,
         SYMBOL_VOLUME_MIN,
         volumeMin
      ) ||
      !SymbolInfoInteger(
         _Symbol,
         SYMBOL_DIGITS,
         digitsValue
      ) ||
      !SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_STOPS_LEVEL,
         stopsLevelValue
      )
   )
   {
      Print(
         "ORDER_CHECK_TEST_ABORT | unable to load current symbol constraints."
      );

      return(false);
   }

   if(
      !MathIsValidNumber(point) ||
      !MathIsValidNumber(tickSize) ||
      !MathIsValidNumber(volumeMin) ||
      point <= 0.0 ||
      tickSize <= 0.0 ||
      volumeMin <= 0.0 ||
      digitsValue < 0 ||
      stopsLevelValue < 0
   )
   {
      return(false);
   }

   const int digits =
      (int)digitsValue;

   const double minimumStopDistance =
      (double)stopsLevelValue *
      point;

   const double validationDistance =
      MathMax(
         minimumStopDistance +
         tickSize * 20.0,
         tickSize * 500.0
      );

   FinalTradeGeometry geometry;

   ResetFinalTradeGeometry(
      geometry
   );

   geometry.valid = true;
   geometry.status =
      TRADE_GEOMETRY_VALID;

   geometry.direction =
      direction;

   if(direction == SIGNAL_BUY)
   {
      geometry.entryPrice =
         tick.ask;

      const double rawStopLoss =
         geometry.entryPrice -
         validationDistance;

      const double rawTakeProfit =
         geometry.entryPrice +
         validationDistance * 2.0;

      geometry.stopLossPrice =
         NormalizeDouble(
            MathFloor(
               rawStopLoss /
               tickSize
            ) *
            tickSize,
            digits
         );

      geometry.takeProfitPrice =
         NormalizeDouble(
            MathCeil(
               rawTakeProfit /
               tickSize
            ) *
            tickSize,
            digits
         );
   }
   else
   {
      geometry.entryPrice =
         tick.bid;

      const double rawStopLoss =
         geometry.entryPrice +
         validationDistance;

      const double rawTakeProfit =
         geometry.entryPrice -
         validationDistance * 2.0;

      geometry.stopLossPrice =
         NormalizeDouble(
            MathCeil(
               rawStopLoss /
               tickSize
            ) *
            tickSize,
            digits
         );

      geometry.takeProfitPrice =
         NormalizeDouble(
            MathFloor(
               rawTakeProfit /
               tickSize
            ) *
            tickSize,
            digits
         );
   }

   if(
      geometry.entryPrice <= 0.0 ||
      geometry.stopLossPrice <= 0.0 ||
      geometry.takeProfitPrice <= 0.0
   )
   {
      return(false);
   }

   geometry.originalStopDistance =
      MathAbs(
         geometry.entryPrice -
         geometry.stopLossPrice
      );

   geometry.finalStopDistance =
      geometry.originalStopDistance;

   geometry.stopDistanceChanged =
      false;

   FinalRiskSizingResult riskSizing;

   ResetFinalRiskSizingResult(
      riskSizing
   );

   riskSizing.valid = true;
   riskSizing.status =
      FINAL_RISK_SIZING_VALID;

   riskSizing.sizing.equity =
      AccountInfoDouble(
         ACCOUNT_EQUITY
      );

   riskSizing.sizing.plannedRiskAmount =
      1.0;

   riskSizing.sizing.referenceVolume =
      volumeMin;

   riskSizing.sizing.lossForReferenceVolume =
      1.0;

   riskSizing.sizing.rawVolume =
      volumeMin;

   riskSizing.normalizedVolume =
      volumeMin;

   TradeRequestCapabilities capabilities;

   if(!LoadCurrentTradeRequestCapabilities(
      _Symbol,
      capabilities
   ))
   {
      Print(
         "ORDER_CHECK_TEST_ABORT | unable to load request capabilities."
      );

      return(false);
   }

   return(
      BuildMarketTradeRequest(
         _Symbol,
         geometry,
         riskSizing,
         capabilities,
         0,
         25,
         requestBuild
      )
   );
}

bool WrapperMatchesDirectCheck(
   const MarketTradeRequestBuildResult &requestBuild,
   const bool directPassed,
   const int directLastError,
   const MqlTradeCheckResult &directResult,
   const bool wrapperEvaluationSuccess,
   const TradeRequestCheckResult &wrapperResult
)
{
   const bool expectedApproved =
      directPassed &&
      directResult.retcode == 0;

   const TradeRequestCheckStatus expectedStatus =
      expectedApproved
      ? TRADE_REQUEST_CHECK_PASSED
      : TRADE_REQUEST_CHECK_REJECTED;

   return(
      wrapperEvaluationSuccess &&
      wrapperResult.allowed ==
         expectedApproved &&
      wrapperResult.status ==
         expectedStatus &&
      wrapperResult.lastError ==
         directLastError &&
      wrapperResult.checkResult.retcode ==
         directResult.retcode &&
      wrapperResult.checkResult.comment ==
         directResult.comment &&
      requestBuild.valid &&
      requestBuild.status ==
         MARKET_REQUEST_BUILD_VALID
   );
}

void OnStart()
{
   // ---------------------------------------------------------------
   // Case 1:
   // Reset state must be fail-safe and deterministic.
   // ---------------------------------------------------------------

   TradeRequestCheckResult checkResult;

   checkResult.allowed = true;
   checkResult.status =
      TRADE_REQUEST_CHECK_PASSED;
   checkResult.lastError = 123;

   ResetTradeRequestCheckResult(
      checkResult
   );

   RecordTestResult(
      "reset_state",
      !checkResult.allowed &&
      checkResult.status ==
         TRADE_REQUEST_CHECK_NOT_EVALUATED &&
      checkResult.lastError == 0 &&
      checkResult.checkResult.retcode == 0
   );

   // ---------------------------------------------------------------
   // Case 2:
   // Internal invalid request-build contract must fail before
   // OrderCheck is called.
   // ---------------------------------------------------------------

   MarketTradeRequestBuildResult invalidBuild;

   ResetMarketTradeRequestBuildResult(
      invalidBuild
   );

   bool evaluationSuccess =
      EvaluateTradeRequestCheck(
         invalidBuild,
         checkResult
      );

   RecordTestResult(
      "invalid_request_build_rejected",
      !evaluationSuccess &&
      !checkResult.allowed &&
      checkResult.status ==
         TRADE_REQUEST_CHECK_INVALID_INPUT
   );

   // ---------------------------------------------------------------
   // Prepare current BUY request.
   // ---------------------------------------------------------------

   MarketTradeRequestBuildResult buyBuild;

   const bool buyBuilt =
      LoadCurrentRequestInputs(
         SIGNAL_BUY,
         buyBuild
      );

   if(!buyBuilt)
   {
      Print(
         "ORDER_CHECK_TEST_ABORT | unable to build current BUY request."
      );

      return;
   }

   // ---------------------------------------------------------------
   // Case 3:
   // BUY wrapper outcome must match direct OrderCheck.
   // ---------------------------------------------------------------

   MqlTradeRequest directBuyRequest =
      buyBuild.request;

   MqlTradeCheckResult directBuyResult = {};

   ResetLastError();

   const bool directBuyPassed =
      OrderCheck(
         directBuyRequest,
         directBuyResult
      );

   const int directBuyLastError =
      GetLastError();

   TradeRequestCheckResult buyCheck;

   const bool buyEvaluationSuccess =
      EvaluateTradeRequestCheck(
         buyBuild,
         buyCheck
      );

   RecordTestResult(
      "current_buy_matches_direct_order_check",
      WrapperMatchesDirectCheck(
         buyBuild,
         directBuyPassed,
         directBuyLastError,
         directBuyResult,
         buyEvaluationSuccess,
         buyCheck
      )
   );

   // ---------------------------------------------------------------
   // Case 4:
   // Captured BUY result must preserve the OrderCheck diagnostics.
   // ---------------------------------------------------------------

   RecordTestResult(
      "current_buy_check_result_captured",
      buyCheck.checkResult.retcode ==
         directBuyResult.retcode &&
      buyCheck.checkResult.comment ==
         directBuyResult.comment
   );

   // ---------------------------------------------------------------
   // Prepare current SELL request.
   // ---------------------------------------------------------------

   MarketTradeRequestBuildResult sellBuild;

   const bool sellBuilt =
      LoadCurrentRequestInputs(
         SIGNAL_SELL,
         sellBuild
      );

   if(!sellBuilt)
   {
      Print(
         "ORDER_CHECK_TEST_ABORT | unable to build current SELL request."
      );

      return;
   }

   // ---------------------------------------------------------------
   // Case 5:
   // SELL wrapper outcome must match direct OrderCheck.
   // ---------------------------------------------------------------

   MqlTradeRequest directSellRequest =
      sellBuild.request;

   MqlTradeCheckResult directSellResult = {};

   ResetLastError();

   const bool directSellPassed =
      OrderCheck(
         directSellRequest,
         directSellResult
      );

   const int directSellLastError =
      GetLastError();

   TradeRequestCheckResult sellCheck;

   const bool sellEvaluationSuccess =
      EvaluateTradeRequestCheck(
         sellBuild,
         sellCheck
      );

   RecordTestResult(
      "current_sell_matches_direct_order_check",
      WrapperMatchesDirectCheck(
         sellBuild,
         directSellPassed,
         directSellLastError,
         directSellResult,
         sellEvaluationSuccess,
         sellCheck
      )
   );

   // ---------------------------------------------------------------
   // Case 6:
   // Captured SELL result must preserve diagnostics.
   // ---------------------------------------------------------------

   RecordTestResult(
      "current_sell_check_result_captured",
      sellCheck.checkResult.retcode ==
         directSellResult.retcode &&
      sellCheck.checkResult.comment ==
         directSellResult.comment
   );

   // ---------------------------------------------------------------
   // Case 7:
   // A structurally marked-valid build with deliberately invalid
   // volume must be rejected by OrderCheck.
   // ---------------------------------------------------------------

   MarketTradeRequestBuildResult invalidVolumeBuild =
      buyBuild;

   invalidVolumeBuild.request.volume =
      0.0;

   TradeRequestCheckResult invalidVolumeCheck;

   const bool invalidVolumeEvaluationSuccess =
      EvaluateTradeRequestCheck(
         invalidVolumeBuild,
         invalidVolumeCheck
      );

   RecordTestResult(
      "zero_volume_rejected_by_order_check",
      invalidVolumeEvaluationSuccess &&
      !invalidVolumeCheck.allowed &&
      invalidVolumeCheck.status ==
         TRADE_REQUEST_CHECK_REJECTED
   );

   // ---------------------------------------------------------------
   // Final result.
   // ---------------------------------------------------------------

   PrintFormat(
      "ORDER_CHECK_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );

   PrintFormat(
      "ORDER_CHECK_BUY_OBSERVATION | symbol=%s | evaluation_success=%s | allowed=%s | status=%s | last_error=%d | retcode=%u | balance=%G | equity=%G | margin=%G | margin_free=%G | margin_level=%G | comment=%s",
      _Symbol,
      buyEvaluationSuccess ? "true" : "false",
      buyCheck.allowed ? "true" : "false",
      EnumToString(
         buyCheck.status
      ),
      buyCheck.lastError,
      buyCheck.checkResult.retcode,
      buyCheck.checkResult.balance,
      buyCheck.checkResult.equity,
      buyCheck.checkResult.margin,
      buyCheck.checkResult.margin_free,
      buyCheck.checkResult.margin_level,
      buyCheck.checkResult.comment
   );

   PrintFormat(
      "ORDER_CHECK_SELL_OBSERVATION | symbol=%s | evaluation_success=%s | allowed=%s | status=%s | last_error=%d | retcode=%u | balance=%G | equity=%G | margin=%G | margin_free=%G | margin_level=%G | comment=%s",
      _Symbol,
      sellEvaluationSuccess ? "true" : "false",
      sellCheck.allowed ? "true" : "false",
      EnumToString(
         sellCheck.status
      ),
      sellCheck.lastError,
      sellCheck.checkResult.retcode,
      sellCheck.checkResult.balance,
      sellCheck.checkResult.equity,
      sellCheck.checkResult.margin,
      sellCheck.checkResult.margin_free,
      sellCheck.checkResult.margin_level,
      sellCheck.checkResult.comment
   );

   PrintFormat(
      "ORDER_CHECK_INVALID_VOLUME_OBSERVATION | evaluation_success=%s | allowed=%s | status=%s | last_error=%d | retcode=%u | comment=%s",
      invalidVolumeEvaluationSuccess
         ? "true"
         : "false",
      invalidVolumeCheck.allowed
         ? "true"
         : "false",
      EnumToString(
         invalidVolumeCheck.status
      ),
      invalidVolumeCheck.lastError,
      invalidVolumeCheck.checkResult.retcode,
      invalidVolumeCheck.checkResult.comment
   );
}
