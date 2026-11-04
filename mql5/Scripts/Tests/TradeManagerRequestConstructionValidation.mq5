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
         "REQUEST_BUILD_TEST_PASS | case=%s",
         caseName
      );

      return;
   }

   g_failed++;

   PrintFormat(
      "REQUEST_BUILD_TEST_FAIL | case=%s",
      caseName
   );
}

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

void SetCapabilities(
   TradeRequestCapabilities &capabilities,
   const ENUM_SYMBOL_TRADE_EXECUTION executionMode,
   const long orderMode,
   const long fillingMode
)
{
   ResetTradeRequestCapabilities(
      capabilities
   );

   capabilities.valid = true;
   capabilities.symbol = "TEST";
   capabilities.executionMode =
      executionMode;
   capabilities.orderMode =
      orderMode;
   capabilities.fillingMode =
      fillingMode;
}

void SetGeometry(
   FinalTradeGeometry &geometry,
   const SignalDirection direction
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

   if(direction == SIGNAL_BUY)
   {
      geometry.entryPrice = 100.20;
      geometry.stopLossPrice = 99.20;
      geometry.takeProfitPrice = 102.20;
   }
   else
   {
      geometry.entryPrice = 100.00;
      geometry.stopLossPrice = 101.00;
      geometry.takeProfitPrice = 98.00;
   }

   geometry.originalStopDistance = 1.0;
   geometry.finalStopDistance = 1.0;
   geometry.stopDistanceChanged = false;
}

void SetRiskSizing(
   FinalRiskSizingResult &riskSizing
)
{
   ResetFinalRiskSizingResult(
      riskSizing
   );

   riskSizing.valid = true;
   riskSizing.status =
      FINAL_RISK_SIZING_VALID;

   riskSizing.sizing.equity = 100000.0;
   riskSizing.sizing.plannedRiskAmount = 1000.0;
   riskSizing.sizing.referenceVolume = 0.01;
   riskSizing.sizing.lossForReferenceVolume = 10.0;
   riskSizing.sizing.rawVolume = 1.12613;

   riskSizing.normalizedVolume = 1.12;
}

long RequiredOrderModeFlags()
{
   return(
      (long)SYMBOL_ORDER_MARKET |
      (long)SYMBOL_ORDER_SL |
      (long)SYMBOL_ORDER_TP
   );
}

void OnStart()
{
   TradeRequestCapabilities capabilities;
   FillingPolicySelectionResult fillingResult;

   const long requiredOrderFlags =
      RequiredOrderModeFlags();

   // ---------------------------------------------------------------
   // Filling policy tests.
   // ---------------------------------------------------------------

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_REQUEST,
      requiredOrderFlags,
      0
   );

   bool selectionSuccess =
      SelectSupportedMarketFillingPolicy(
         capabilities,
         fillingResult
      );

   RecordTestResult(
      "request_execution_selects_fok",
      selectionSuccess &&
      fillingResult.selected &&
      fillingResult.status ==
         FILLING_POLICY_SELECTED_FOK &&
      fillingResult.fillingPolicy ==
         ORDER_FILLING_FOK
   );

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_INSTANT,
      requiredOrderFlags,
      0
   );

   selectionSuccess =
      SelectSupportedMarketFillingPolicy(
         capabilities,
         fillingResult
      );

   RecordTestResult(
      "instant_execution_selects_fok",
      selectionSuccess &&
      fillingResult.fillingPolicy ==
         ORDER_FILLING_FOK
   );

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_MARKET,
      requiredOrderFlags,
      (long)SYMBOL_FILLING_FOK |
      (long)SYMBOL_FILLING_IOC
   );

   selectionSuccess =
      SelectSupportedMarketFillingPolicy(
         capabilities,
         fillingResult
      );

   RecordTestResult(
      "market_prefers_fok",
      selectionSuccess &&
      fillingResult.fillingPolicy ==
         ORDER_FILLING_FOK
   );

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_MARKET,
      requiredOrderFlags,
      (long)SYMBOL_FILLING_IOC
   );

   selectionSuccess =
      SelectSupportedMarketFillingPolicy(
         capabilities,
         fillingResult
      );

   RecordTestResult(
      "market_falls_back_to_ioc",
      selectionSuccess &&
      fillingResult.status ==
         FILLING_POLICY_SELECTED_IOC &&
      fillingResult.fillingPolicy ==
         ORDER_FILLING_IOC
   );

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_MARKET,
      requiredOrderFlags,
      0
   );

   selectionSuccess =
      SelectSupportedMarketFillingPolicy(
         capabilities,
         fillingResult
      );

   RecordTestResult(
      "market_without_fok_or_ioc_rejected",
      !selectionSuccess &&
      !fillingResult.selected &&
      fillingResult.status ==
         FILLING_POLICY_NO_SUPPORTED_MODE
   );

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_EXCHANGE,
      requiredOrderFlags,
      (long)SYMBOL_FILLING_FOK
   );

   selectionSuccess =
      SelectSupportedMarketFillingPolicy(
         capabilities,
         fillingResult
      );

   RecordTestResult(
      "exchange_selects_fok",
      selectionSuccess &&
      fillingResult.fillingPolicy ==
         ORDER_FILLING_FOK
   );

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_EXCHANGE,
      requiredOrderFlags,
      (long)SYMBOL_FILLING_IOC
   );

   selectionSuccess =
      SelectSupportedMarketFillingPolicy(
         capabilities,
         fillingResult
      );

   RecordTestResult(
      "exchange_falls_back_to_ioc",
      selectionSuccess &&
      fillingResult.fillingPolicy ==
         ORDER_FILLING_IOC
   );

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_EXCHANGE,
      requiredOrderFlags,
      0
   );

   selectionSuccess =
      SelectSupportedMarketFillingPolicy(
         capabilities,
         fillingResult
      );

   RecordTestResult(
      "exchange_falls_back_to_return",
      selectionSuccess &&
      fillingResult.status ==
         FILLING_POLICY_SELECTED_RETURN &&
      fillingResult.fillingPolicy ==
         ORDER_FILLING_RETURN
   );

   // ---------------------------------------------------------------
   // Request construction tests.
   // ---------------------------------------------------------------

   FinalTradeGeometry geometry;
   FinalRiskSizingResult riskSizing;
   MarketTradeRequestBuildResult buildResult;

   SetRiskSizing(
      riskSizing
   );

   SetGeometry(
      geometry,
      SIGNAL_BUY
   );

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_REQUEST,
      requiredOrderFlags,
      0
   );

   const ulong testMagic =
      12345678;

   const ulong testDeviation =
      25;

   bool buildSuccess =
      BuildMarketTradeRequest(
         "TEST",
         geometry,
         riskSizing,
         capabilities,
         testMagic,
         testDeviation,
         buildResult
      );

   RecordTestResult(
      "buy_request_execution_fields",
      buildSuccess &&
      buildResult.valid &&
      buildResult.status ==
         MARKET_REQUEST_BUILD_VALID &&
      buildResult.request.action ==
         TRADE_ACTION_DEAL &&
      buildResult.request.type ==
         ORDER_TYPE_BUY &&
      buildResult.request.symbol ==
         "TEST" &&
      NearlyEqual(
         buildResult.request.volume,
         riskSizing.normalizedVolume
      ) &&
      NearlyEqual(
         buildResult.request.price,
         geometry.entryPrice
      ) &&
      NearlyEqual(
         buildResult.request.sl,
         geometry.stopLossPrice
      ) &&
      NearlyEqual(
         buildResult.request.tp,
         geometry.takeProfitPrice
      ) &&
      buildResult.request.magic ==
         testMagic &&
      buildResult.request.deviation ==
         testDeviation &&
      buildResult.request.type_filling ==
         ORDER_FILLING_FOK
   );

   SetGeometry(
      geometry,
      SIGNAL_SELL
   );

   buildSuccess =
      BuildMarketTradeRequest(
         "TEST",
         geometry,
         riskSizing,
         capabilities,
         testMagic,
         testDeviation,
         buildResult
      );

   RecordTestResult(
      "sell_request_execution_fields",
      buildSuccess &&
      buildResult.request.type ==
         ORDER_TYPE_SELL &&
      NearlyEqual(
         buildResult.request.volume,
         riskSizing.normalizedVolume
      ) &&
      NearlyEqual(
         buildResult.request.price,
         geometry.entryPrice
      ) &&
      NearlyEqual(
         buildResult.request.sl,
         geometry.stopLossPrice
      ) &&
      NearlyEqual(
         buildResult.request.tp,
         geometry.takeProfitPrice
      )
   );

   SetGeometry(
      geometry,
      SIGNAL_BUY
   );

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_MARKET,
      requiredOrderFlags,
      (long)SYMBOL_FILLING_IOC
   );

   buildSuccess =
      BuildMarketTradeRequest(
         "TEST",
         geometry,
         riskSizing,
         capabilities,
         testMagic,
         testDeviation,
         buildResult
      );

   RecordTestResult(
      "market_execution_zeroes_price_and_deviation",
      buildSuccess &&
      buildResult.request.price == 0.0 &&
      buildResult.request.deviation == 0 &&
      buildResult.request.type_filling ==
         ORDER_FILLING_IOC
   );

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_EXCHANGE,
      requiredOrderFlags,
      0
   );

   buildSuccess =
      BuildMarketTradeRequest(
         "TEST",
         geometry,
         riskSizing,
         capabilities,
         testMagic,
         testDeviation,
         buildResult
      );

   RecordTestResult(
      "exchange_uses_return_and_zero_price",
      buildSuccess &&
      buildResult.request.price == 0.0 &&
      buildResult.request.deviation == 0 &&
      buildResult.request.type_filling ==
         ORDER_FILLING_RETURN
   );

   // ---------------------------------------------------------------
   // Capability rejection tests.
   // ---------------------------------------------------------------

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_MARKET,
      (long)SYMBOL_ORDER_SL |
      (long)SYMBOL_ORDER_TP,
      (long)SYMBOL_FILLING_FOK
   );

   buildSuccess =
      BuildMarketTradeRequest(
         "TEST",
         geometry,
         riskSizing,
         capabilities,
         testMagic,
         testDeviation,
         buildResult
      );

   RecordTestResult(
      "market_order_unsupported_rejected",
      !buildSuccess &&
      buildResult.status ==
         MARKET_REQUEST_BUILD_MARKET_ORDER_UNSUPPORTED
   );

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_MARKET,
      (long)SYMBOL_ORDER_MARKET |
      (long)SYMBOL_ORDER_TP,
      (long)SYMBOL_FILLING_FOK
   );

   buildSuccess =
      BuildMarketTradeRequest(
         "TEST",
         geometry,
         riskSizing,
         capabilities,
         testMagic,
         testDeviation,
         buildResult
      );

   RecordTestResult(
      "stop_loss_unsupported_rejected",
      !buildSuccess &&
      buildResult.status ==
         MARKET_REQUEST_BUILD_STOP_LOSS_UNSUPPORTED
   );

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_MARKET,
      (long)SYMBOL_ORDER_MARKET |
      (long)SYMBOL_ORDER_SL,
      (long)SYMBOL_FILLING_FOK
   );

   buildSuccess =
      BuildMarketTradeRequest(
         "TEST",
         geometry,
         riskSizing,
         capabilities,
         testMagic,
         testDeviation,
         buildResult
      );

   RecordTestResult(
      "take_profit_unsupported_rejected",
      !buildSuccess &&
      buildResult.status ==
         MARKET_REQUEST_BUILD_TAKE_PROFIT_UNSUPPORTED
   );

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_MARKET,
      requiredOrderFlags,
      0
   );

   buildSuccess =
      BuildMarketTradeRequest(
         "TEST",
         geometry,
         riskSizing,
         capabilities,
         testMagic,
         testDeviation,
         buildResult
      );

   RecordTestResult(
      "unsupported_market_filling_rejected",
      !buildSuccess &&
      buildResult.status ==
         MARKET_REQUEST_BUILD_FILLING_UNSUPPORTED
   );

   // ---------------------------------------------------------------
   // Identity and contract tests.
   // ---------------------------------------------------------------

   SetCapabilities(
      capabilities,
      SYMBOL_TRADE_EXECUTION_REQUEST,
      requiredOrderFlags,
      0
   );

   buildSuccess =
      BuildMarketTradeRequest(
         "TEST",
         geometry,
         riskSizing,
         capabilities,
         0,
         testDeviation,
         buildResult
      );

   RecordTestResult(
      "zero_magic_is_copied",
      buildSuccess &&
      buildResult.request.magic == 0
   );

   buildSuccess =
      BuildMarketTradeRequest(
         "OTHER",
         geometry,
         riskSizing,
         capabilities,
         testMagic,
         testDeviation,
         buildResult
      );

   RecordTestResult(
      "symbol_mismatch_rejected",
      !buildSuccess &&
      buildResult.status ==
         MARKET_REQUEST_BUILD_INVALID_INPUT
   );

   FinalTradeGeometry invalidGeometry =
      geometry;

   invalidGeometry.valid = false;

   buildSuccess =
      BuildMarketTradeRequest(
         "TEST",
         invalidGeometry,
         riskSizing,
         capabilities,
         testMagic,
         testDeviation,
         buildResult
      );

   RecordTestResult(
      "invalid_geometry_rejected",
      !buildSuccess &&
      buildResult.status ==
         MARKET_REQUEST_BUILD_INVALID_INPUT
   );

   FinalRiskSizingResult invalidRiskSizing =
      riskSizing;

   invalidRiskSizing.valid = false;

   buildSuccess =
      BuildMarketTradeRequest(
         "TEST",
         geometry,
         invalidRiskSizing,
         capabilities,
         testMagic,
         testDeviation,
         buildResult
      );

   RecordTestResult(
      "invalid_risk_sizing_rejected",
      !buildSuccess &&
      buildResult.status ==
         MARKET_REQUEST_BUILD_INVALID_INPUT
   );

   // ---------------------------------------------------------------
   // Current broker observation.
   // No OrderCheck and no OrderSend.
   // ---------------------------------------------------------------

   TradeRequestCapabilities currentCapabilities;

   const bool capabilitiesLoaded =
      LoadCurrentTradeRequestCapabilities(
         _Symbol,
         currentCapabilities
      );

   FillingPolicySelectionResult currentFilling;

   ResetFillingPolicySelectionResult(
      currentFilling
   );

   bool currentFillingSelected = false;

   if(capabilitiesLoaded)
   {
      currentFillingSelected =
         SelectSupportedMarketFillingPolicy(
            currentCapabilities,
            currentFilling
         );
   }

   PrintFormat(
      "REQUEST_CAPABILITIES_OBSERVATION | symbol=%s | loaded=%s | execution_mode=%s | order_mode=%I64d | filling_mode=%I64d | filling_selected=%s | selected_filling=%s | selection_status=%s",
      _Symbol,
      capabilitiesLoaded ? "true" : "false",
      EnumToString(
         currentCapabilities.executionMode
      ),
      currentCapabilities.orderMode,
      currentCapabilities.fillingMode,
      currentFillingSelected
         ? "true"
         : "false",
      EnumToString(
         currentFilling.fillingPolicy
      ),
      EnumToString(
         currentFilling.status
      )
   );

   PrintFormat(
      "REQUEST_BUILD_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );
}
