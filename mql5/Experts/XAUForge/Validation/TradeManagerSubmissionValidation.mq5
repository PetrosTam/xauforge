#property strict

#include <XAUForge/TradeManager.mqh>

const ulong VALIDATION_MAGIC_NUMBER = 970001;
const ulong VALIDATION_DEVIATION_POINTS = 20;

// Must be enabled explicitly; never submit from this harness by default.
input bool ValidationEnablePositiveSubmission = false;

bool g_validationFinished = false;
bool g_submissionAttempted = false;

int g_submissionSafetyPassed = 0;
int g_submissionSafetyFailed = 0;

void RecordSubmissionSafetyTest(
   const string caseName,
   const bool passed
)
{
   if(passed)
      g_submissionSafetyPassed++;
   else
      g_submissionSafetyFailed++;

   PrintFormat(
      "SUBMISSION_SAFETY_TEST_%s | case=%s",
      passed ? "PASS" : "FAIL",
      caseName
   );
}

int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER))
   {
      Print(
         "SUBMISSION_VALIDATION_ABORT | Strategy Tester execution required."
      );

      return(INIT_FAILED);
   }

   if(MQLInfoInteger(MQL_OPTIMIZATION))
   {
      Print(
         "SUBMISSION_VALIDATION_ABORT | Optimization execution is not allowed."
      );

      return(INIT_FAILED);
   }

   PrintFormat(
      "SUBMISSION_VALIDATION_INIT | symbol=%s | timeframe=%s | tester=true | optimization=false | terminal_build=%d",
      _Symbol,
      EnumToString(
         (ENUM_TIMEFRAMES)_Period
      ),
      (int)TerminalInfoInteger(
         TERMINAL_BUILD
      )
   );

   return(INIT_SUCCEEDED);
}

bool LoadValidationGeometryInputs(
   MqlTick &tick,
   int &digits,
   double &point,
   double &tickSize,
   double &volumeMin,
   long &stopsLevelPoints
)
{
   ZeroMemory(
      tick
   );

   digits = 0;
   point = 0.0;
   tickSize = 0.0;
   volumeMin = 0.0;
   stopsLevelPoints = 0;

   ResetLastError();

   if(!SymbolInfoTick(
      _Symbol,
      tick
   ))
   {
      PrintFormat(
         "SUBMISSION_VALIDATION_ABORT | SymbolInfoTick failed | error=%d",
         GetLastError()
      );

      return(false);
   }

   long digitsValue = 0;

   if(!SymbolInfoInteger(
      _Symbol,
      SYMBOL_DIGITS,
      digitsValue
   ))
   {
      PrintFormat(
         "SUBMISSION_VALIDATION_ABORT | SYMBOL_DIGITS lookup failed | error=%d",
         GetLastError()
      );

      return(false);
   }

   if(!SymbolInfoDouble(
      _Symbol,
      SYMBOL_POINT,
      point
   ))
   {
      PrintFormat(
         "SUBMISSION_VALIDATION_ABORT | SYMBOL_POINT lookup failed | error=%d",
         GetLastError()
      );

      return(false);
   }

   if(!SymbolInfoDouble(
      _Symbol,
      SYMBOL_TRADE_TICK_SIZE,
      tickSize
   ))
   {
      PrintFormat(
         "SUBMISSION_VALIDATION_ABORT | SYMBOL_TRADE_TICK_SIZE lookup failed | error=%d",
         GetLastError()
      );

      return(false);
   }

   if(!SymbolInfoDouble(
      _Symbol,
      SYMBOL_VOLUME_MIN,
      volumeMin
   ))
   {
      PrintFormat(
         "SUBMISSION_VALIDATION_ABORT | SYMBOL_VOLUME_MIN lookup failed | error=%d",
         GetLastError()
      );

      return(false);
   }

   if(!SymbolInfoInteger(
      _Symbol,
      SYMBOL_TRADE_STOPS_LEVEL,
      stopsLevelPoints
   ))
   {
      PrintFormat(
         "SUBMISSION_VALIDATION_ABORT | SYMBOL_TRADE_STOPS_LEVEL lookup failed | error=%d",
         GetLastError()
      );

      return(false);
   }

   if(
      tick.time_msc <= 0 ||
      !MathIsValidNumber(tick.bid) ||
      !MathIsValidNumber(tick.ask) ||
      !MathIsValidNumber(point) ||
      !MathIsValidNumber(tickSize) ||
      !MathIsValidNumber(volumeMin) ||
      tick.bid <= 0.0 ||
      tick.ask <= 0.0 ||
      tick.ask < tick.bid ||
      digitsValue < 0 ||
      point <= 0.0 ||
      tickSize <= 0.0 ||
      volumeMin <= 0.0 ||
      stopsLevelPoints < 0
   )
   {
      PrintFormat(
         "SUBMISSION_VALIDATION_ABORT | invalid symbol inputs | time_msc=%I64d | bid=%G | ask=%G | digits=%I64d | point=%G | tick_size=%G | volume_min=%G | stops_level=%I64d",
         tick.time_msc,
         tick.bid,
         tick.ask,
         digitsValue,
         point,
         tickSize,
         volumeMin,
         stopsLevelPoints
      );

      return(false);
   }

   digits =
      (int)digitsValue;

   return(true);
}

bool BuildValidationGeometry(
   const MqlTick &tick,
   const int digits,
   const double point,
   const double tickSize,
   const long stopsLevelPoints,
   FinalTradeGeometry &geometry
)
{
   ResetFinalTradeGeometry(
      geometry
   );

   if(
      tick.time_msc <= 0 ||
      !MathIsValidNumber(tick.bid) ||
      !MathIsValidNumber(tick.ask) ||
      !MathIsValidNumber(point) ||
      !MathIsValidNumber(tickSize) ||
      tick.bid <= 0.0 ||
      tick.ask <= 0.0 ||
      tick.ask < tick.bid ||
      point <= 0.0 ||
      tickSize <= 0.0 ||
      stopsLevelPoints < 0
   )
   {
      Print(
         "SUBMISSION_VALIDATION_ABORT | invalid geometry inputs."
      );

      return(false);
   }

   const double brokerMinimumStopDistance =
      (double)stopsLevelPoints *
      point;

   const double validationProtectionDistance =
      MathMax(
         brokerMinimumStopDistance +
         tickSize * 20.0,
         tickSize * 500.0
      );

   if(
      !MathIsValidNumber(
         validationProtectionDistance
      ) ||
      validationProtectionDistance <= 0.0
   )
   {
      Print(
         "SUBMISSION_VALIDATION_ABORT | invalid validation protection distance."
      );

      return(false);
   }

   geometry.direction =
      SIGNAL_BUY;

   geometry.entryPrice =
      tick.ask;

   const double rawStopLoss =
      tick.bid -
      validationProtectionDistance;

   geometry.stopLossPrice =
      NormalizeDouble(
         MathFloor(
            rawStopLoss /
            tickSize
         ) *
         tickSize,
         digits
      );

   if(
      !MathIsValidNumber(
         geometry.stopLossPrice
      ) ||
      geometry.stopLossPrice <= 0.0 ||
      geometry.stopLossPrice >=
         tick.bid
   )
   {
      PrintFormat(
         "SUBMISSION_VALIDATION_ABORT | invalid BUY Stop Loss | bid=%G | ask=%G | sl=%G",
         tick.bid,
         tick.ask,
         geometry.stopLossPrice
      );

      ResetFinalTradeGeometry(
         geometry
      );

      return(false);
   }

   geometry.finalStopDistance =
      geometry.entryPrice -
      geometry.stopLossPrice;

   if(
      !MathIsValidNumber(
         geometry.finalStopDistance
      ) ||
      geometry.finalStopDistance <= 0.0
   )
   {
      Print(
         "SUBMISSION_VALIDATION_ABORT | invalid final stop distance."
      );

      ResetFinalTradeGeometry(
         geometry
      );

      return(false);
   }

   const double rawTakeProfit =
      geometry.entryPrice +
      geometry.finalStopDistance * 2.0;

   geometry.takeProfitPrice =
      NormalizeDouble(
         MathCeil(
            rawTakeProfit /
            tickSize
         ) *
         tickSize,
         digits
      );

   if(
      !MathIsValidNumber(
         geometry.takeProfitPrice
      ) ||
      geometry.takeProfitPrice <=
         geometry.entryPrice
   )
   {
      Print(
         "SUBMISSION_VALIDATION_ABORT | invalid BUY Take Profit."
      );

      ResetFinalTradeGeometry(
         geometry
      );

      return(false);
   }

   const double stopDistanceFromBid =
      tick.bid -
      geometry.stopLossPrice;

   if(
      !MathIsValidNumber(
         stopDistanceFromBid
      ) ||
      stopDistanceFromBid <
         brokerMinimumStopDistance
   )
   {
      PrintFormat(
         "SUBMISSION_VALIDATION_ABORT | BUY Stop Loss violates broker stop distance | bid=%G | sl=%G | observed_distance=%G | required_distance=%G",
         tick.bid,
         geometry.stopLossPrice,
         stopDistanceFromBid,
         brokerMinimumStopDistance
      );

      ResetFinalTradeGeometry(
         geometry
      );

      return(false);
   }

   geometry.originalStopDistance =
      geometry.finalStopDistance;

   geometry.stopDistanceChanged =
      false;

   geometry.valid = true;
   geometry.status =
      TRADE_GEOMETRY_VALID;

   PrintFormat(
      "SUBMISSION_VALIDATION_GEOMETRY | bid=%G | ask=%G | spread=%G | stops_level_points=%I64d | minimum_stop_distance=%G | sl=%G | sl_distance_from_bid=%G | final_stop_distance=%G | tp=%G",
      tick.bid,
      tick.ask,
      tick.ask - tick.bid,
      stopsLevelPoints,
      brokerMinimumStopDistance,
      geometry.stopLossPrice,
      stopDistanceFromBid,
      geometry.finalStopDistance,
      geometry.takeProfitPrice
   );

   return(true);
}

bool BuildValidationRiskSizing(
   const double volumeMin,
   FinalRiskSizingResult &riskSizing
)
{
   ResetFinalRiskSizingResult(
      riskSizing
   );

   const double currentEquity =
      AccountInfoDouble(
         ACCOUNT_EQUITY
      );

   if(
      !MathIsValidNumber(
         currentEquity
      ) ||
      currentEquity <= 0.0 ||
      !MathIsValidNumber(
         volumeMin
      ) ||
      volumeMin <= 0.0
   )
   {
      PrintFormat(
         "SUBMISSION_VALIDATION_ABORT | invalid validation sizing inputs | equity=%G | volume_min=%G",
         currentEquity,
         volumeMin
      );

      return(false);
   }

   riskSizing.valid = true;
   riskSizing.status =
      FINAL_RISK_SIZING_VALID;

   riskSizing.sizing.equity =
      currentEquity;

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

   return(true);
}

bool BuildValidationRequest(
   MarketTradeRequestBuildResult &requestBuild
)
{
   ResetMarketTradeRequestBuildResult(
      requestBuild
   );

   MqlTick tick = {};

   int digits = 0;
   double point = 0.0;
   double tickSize = 0.0;
   double volumeMin = 0.0;
   long stopsLevelPoints = 0;

   if(!LoadValidationGeometryInputs(
      tick,
      digits,
      point,
      tickSize,
      volumeMin,
      stopsLevelPoints
   ))
   {
      return(false);
   }

   FinalTradeGeometry geometry;

   if(!BuildValidationGeometry(
      tick,
      digits,
      point,
      tickSize,
      stopsLevelPoints,
      geometry
   ))
   {
      return(false);
   }

   FinalRiskSizingResult riskSizing;

   if(!BuildValidationRiskSizing(
      volumeMin,
      riskSizing
   ))
   {
      return(false);
   }

   TradeRequestCapabilities capabilities;

   if(!LoadCurrentTradeRequestCapabilities(
      _Symbol,
      capabilities
   ))
   {
      Print(
         "SUBMISSION_VALIDATION_ABORT | request capabilities could not be loaded."
      );

      return(false);
   }

   if(!BuildMarketTradeRequest(
      _Symbol,
      geometry,
      riskSizing,
      capabilities,
      VALIDATION_MAGIC_NUMBER,
      VALIDATION_DEVIATION_POINTS,
      requestBuild
   ))
   {
      Print(
         "SUBMISSION_VALIDATION_ABORT | BuildMarketTradeRequest failed."
      );

      return(false);
   }

   if(
      !requestBuild.valid ||
      requestBuild.status !=
         MARKET_REQUEST_BUILD_VALID
   )
   {
      PrintFormat(
         "SUBMISSION_VALIDATION_ABORT | request build is not valid | status=%s",
         EnumToString(
            requestBuild.status
         )
      );

      return(false);
   }

   PrintFormat(
      "SUBMISSION_VALIDATION_REQUEST | symbol=%s | type=%s | volume=%G | price=%G | sl=%G | tp=%G | filling=%s | magic=%I64u | deviation=%I64u",
      requestBuild.request.symbol,
      EnumToString(
         requestBuild.request.type
      ),
      requestBuild.request.volume,
      requestBuild.request.price,
      requestBuild.request.sl,
      requestBuild.request.tp,
      EnumToString(
         requestBuild.request.type_filling
      ),
      requestBuild.request.magic,
      requestBuild.request.deviation
   );

   return(true);
}

void LogSubmissionResult(
   const bool evaluationSuccess,
   const SynchronousTradeSubmissionResult &result
)
{
   PrintFormat(
      "SUBMISSION_VALIDATION_RESULT | evaluation_success=%s | stage_status=%s | order_send_attempted=%s | permission_allowed=%s | permission_status=%s | check_allowed=%s | check_status=%s | check_last_error=%d | check_retcode=%u | check_comment=%s | order_send_returned_true=%s | submission_status=%s | order_send_last_error=%d | retcode=%u | retcode_external=%d | order=%I64u | deal=%I64u | volume=%G | price=%G | bid=%G | ask=%G | request_id=%u | comment=%s",
      evaluationSuccess
         ? "true"
         : "false",
      EnumToString(
         result.status
      ),
      result.orderSendAttempted
         ? "true"
         : "false",
      result.permissionResult.allowed
         ? "true"
         : "false",
      EnumToString(
         result.permissionResult.status
      ),
      result.requestCheckResult.allowed
         ? "true"
         : "false",
      EnumToString(
         result.requestCheckResult.status
      ),
      result.requestCheckResult.lastError,
      result.requestCheckResult.checkResult.retcode,
      result.requestCheckResult.checkResult.comment,
      result.submissionResult.orderSendReturnedTrue
         ? "true"
         : "false",
      EnumToString(
         result.submissionResult.status
      ),
      result.submissionResult.lastError,
      result.submissionResult.tradeResult.retcode,
      result.submissionResult.tradeResult.retcode_external,
      result.submissionResult.tradeResult.order,
      result.submissionResult.tradeResult.deal,
      result.submissionResult.tradeResult.volume,
      result.submissionResult.tradeResult.price,
      result.submissionResult.tradeResult.bid,
      result.submissionResult.tradeResult.ask,
      result.submissionResult.tradeResult.request_id,
      result.submissionResult.tradeResult.comment
   );
}

// These cases use invalid requests or synthetic permission snapshots.
// A valid OrderSend path remains disabled unless the tester input is enabled.
bool RunSubmissionSafetyTests(
   const MarketTradeRequestBuildResult &validRequest
)
{
   MarketTradeRequestBuildResult invalidBuild;
   ResetMarketTradeRequestBuildResult(invalidBuild);

   SynchronousTradeSubmissionResult invalidBuildResult;
   const bool invalidBuildEvaluated =
      ExecuteSynchronousMarketSubmission(
         invalidBuild,
         invalidBuildResult
      );

   RecordSubmissionSafetyTest(
      "invalid_request_rejected_before_ordercheck",
      !invalidBuildEvaluated &&
      invalidBuildResult.status ==
         SYNCHRONOUS_TRADE_SUBMISSION_INVALID_INPUT &&
      !invalidBuildResult.orderSendAttempted
   );

   TradeSubmissionPermissionSnapshot permissions;
   ResetTradeSubmissionPermissionSnapshot(permissions);
   TradeSubmissionPermissionResult permissionResult;

   const bool invalidPermissionsEvaluated =
      EvaluateTradeSubmissionPermissions(
         permissions,
         permissionResult
      );

   RecordSubmissionSafetyTest(
      "invalid_permission_snapshot_rejected",
      !invalidPermissionsEvaluated &&
      permissionResult.status ==
         TRADE_SUBMISSION_PERMISSION_INVALID_INPUT &&
      !permissionResult.allowed
   );

   permissions.valid = true;
   permissions.testerMode = true;
   permissions.terminalConnected = true;
   permissions.terminalTradeAllowed = true;
   permissions.programTradeAllowed = true;
   permissions.accountTradeAllowed = true;
   permissions.accountExpertTradeAllowed = true;

   const bool validPermissionsEvaluated =
      EvaluateTradeSubmissionPermissions(
         permissions,
         permissionResult
      );

   RecordSubmissionSafetyTest(
      "synthetic_permissions_allowed",
      validPermissionsEvaluated &&
      permissionResult.allowed &&
      permissionResult.status ==
         TRADE_SUBMISSION_PERMISSION_ALLOWED
   );

   permissions.programTradeAllowed = false;
   const bool programEvaluated =
      EvaluateTradeSubmissionPermissions(
         permissions,
         permissionResult
      );

   RecordSubmissionSafetyTest(
      "synthetic_program_trading_blocked",
      programEvaluated &&
      !permissionResult.allowed &&
      permissionResult.status ==
         TRADE_SUBMISSION_PERMISSION_PROGRAM_TRADING_DISABLED
   );

   permissions.programTradeAllowed = true;
   permissions.terminalTradeAllowed = false;
   const bool terminalEvaluated =
      EvaluateTradeSubmissionPermissions(
         permissions,
         permissionResult
      );

   RecordSubmissionSafetyTest(
      "synthetic_terminal_trading_blocked",
      terminalEvaluated &&
      !permissionResult.allowed &&
      permissionResult.status ==
         TRADE_SUBMISSION_PERMISSION_TERMINAL_TRADING_DISABLED
   );

   permissions.terminalTradeAllowed = true;
   permissions.accountTradeAllowed = false;
   const bool accountEvaluated =
      EvaluateTradeSubmissionPermissions(
         permissions,
         permissionResult
      );

   RecordSubmissionSafetyTest(
      "synthetic_account_trading_blocked",
      accountEvaluated &&
      !permissionResult.allowed &&
      permissionResult.status ==
         TRADE_SUBMISSION_PERMISSION_ACCOUNT_TRADING_DISABLED
   );

   permissions.accountTradeAllowed = true;
   permissions.accountExpertTradeAllowed = false;
   const bool expertEvaluated =
      EvaluateTradeSubmissionPermissions(
         permissions,
         permissionResult
      );

   RecordSubmissionSafetyTest(
      "synthetic_account_expert_trading_blocked",
      expertEvaluated &&
      !permissionResult.allowed &&
      permissionResult.status ==
         TRADE_SUBMISSION_PERMISSION_ACCOUNT_EXPERT_TRADING_DISABLED
   );

   // Deliberately invalid volume. OrderCheck must reject it and no
   // OrderSend should be attempted. Run in Strategy Tester only.
   MarketTradeRequestBuildResult invalidVolumeBuild =
      validRequest;
   invalidVolumeBuild.request.volume = 0.0;

   SynchronousTradeSubmissionResult invalidVolumeResult;
   const bool invalidVolumeEvaluated =
      ExecuteSynchronousMarketSubmission(
         invalidVolumeBuild,
         invalidVolumeResult
      );

   PrintFormat(
      "SUBMISSION_SAFETY_OBSERVATION | case=zero_volume | evaluation_success=%s | stage=%s | permission_allowed=%s | check_status=%s | check_retcode=%u | order_send_attempted=%s",
      invalidVolumeEvaluated ? "true" : "false",
      EnumToString(invalidVolumeResult.status),
      invalidVolumeResult.permissionResult.allowed ? "true" : "false",
      EnumToString(invalidVolumeResult.requestCheckResult.status),
      invalidVolumeResult.requestCheckResult.checkResult.retcode,
      invalidVolumeResult.orderSendAttempted ? "true" : "false"
   );

   RecordSubmissionSafetyTest(
      "zero_volume_ordercheck_rejected_without_ordersend",
      invalidVolumeEvaluated &&
      invalidVolumeResult.status ==
         SYNCHRONOUS_TRADE_SUBMISSION_ORDER_CHECK_REJECTED &&
      invalidVolumeResult.requestCheckResult.status ==
         TRADE_REQUEST_CHECK_REJECTED &&
      !invalidVolumeResult.requestCheckResult.allowed &&
      !invalidVolumeResult.orderSendAttempted &&
      PositionsTotal() == 0 &&
      OrdersTotal() == 0
   );

   PrintFormat(
      "SUBMISSION_SAFETY_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_submissionSafetyPassed,
      g_submissionSafetyFailed,
      g_submissionSafetyPassed + g_submissionSafetyFailed
   );

   return(g_submissionSafetyFailed == 0);
}

void OnTick()
{
   if(g_validationFinished)
      return;

   if(g_submissionAttempted)
      return;

   if(!MQLInfoInteger(MQL_TESTER))
   {
      Print(
         "SUBMISSION_VALIDATION_ABORT | Strategy Tester execution required."
      );

      g_validationFinished = true;

      return;
   }

   if(MQLInfoInteger(MQL_OPTIMIZATION))
   {
      Print(
         "SUBMISSION_VALIDATION_ABORT | Optimization execution is not allowed."
      );

      g_validationFinished = true;

      return;
   }

   if(
      PositionsTotal() != 0 ||
      OrdersTotal() != 0
   )
   {
      PrintFormat(
         "SUBMISSION_VALIDATION_ABORT | tester state is not clean | positions=%d | orders=%d",
         PositionsTotal(),
         OrdersTotal()
      );

      g_validationFinished = true;

      return;
   }

   MarketTradeRequestBuildResult requestBuild;

   if(!BuildValidationRequest(
      requestBuild
   ))
   {
      g_validationFinished = true;

      return;
   }

   if(!RunSubmissionSafetyTests(requestBuild))
   {
      Print(
         "SUBMISSION_VALIDATION_ABORT | Negative-path tests failed. Positive submission is blocked."
      );

      g_validationFinished = true;
      return;
   }

   if(!ValidationEnablePositiveSubmission)
   {
      Print(
         "SUBMISSION_VALIDATION_COMPLETE | positive_path_invoked=false | order_send_attempted=false"
      );

      g_validationFinished = true;
      return;
   }

   g_submissionAttempted = true;

   SynchronousTradeSubmissionResult submissionResult;

   const bool evaluationSuccess =
      ExecuteSynchronousMarketSubmission(
         requestBuild,
         submissionResult
      );

   LogSubmissionResult(
      evaluationSuccess,
      submissionResult
   );

   PrintFormat(
      "SUBMISSION_VALIDATION_COMPLETE | positive_path_invoked=true | order_send_attempted=%s",
      submissionResult.orderSendAttempted
         ? "true"
         : "false"
   );

   g_validationFinished = true;
}
