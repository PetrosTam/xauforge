#property strict

#include <XAUForge/TradeManager.mqh>

const double VALIDATION_RISK_PERCENT = 1.0;
const double VALIDATION_RISK_REWARD_RATIO = 2.0;
const double VALIDATION_ATR_VALUE = 2.5;

const ulong VALIDATION_MAGIC_NUMBER = 970002;
const ulong VALIDATION_DEVIATION_POINTS = 20;

// Validation fixture only. This is not a production freshness policy.
input int ValidationMaxQuoteAgeSeconds = 30;
// Explicit opt-in for the only path that can submit a simulated trade.
input bool ValidationEnablePositiveSubmission = false;

bool g_validationFinished = false;

int g_passed = 0;
int g_failed = 0;
int g_skipped = 0;

void RecordTestResult(
   const string caseName,
   const bool passed
)
{
   if(passed)
   {
      g_passed++;

      PrintFormat(
         "ORCHESTRATION_TEST_PASS | case=%s",
         caseName
      );

      return;
   }

   g_failed++;

   PrintFormat(
      "ORCHESTRATION_TEST_FAIL | case=%s",
      caseName
   );
}

void RecordTestSkip(
   const string caseName,
   const string reason
)
{
   g_skipped++;

   PrintFormat(
      "ORCHESTRATION_TEST_SKIP | case=%s | reason=%s",
      caseName,
      reason
   );
}

void LogValidationSummary(
   const string positiveCaseStatus,
   const bool orderSendAttempted
)
{
   string runStatus = "PASS";

   if(g_failed > 0)
      runStatus = "FAIL";
   else if(g_skipped > 0)
      runStatus = "NEGATIVE_ONLY_PASS";

   PrintFormat(
      "ORCHESTRATION_TEST_RESULT | passed=%d | failed=%d | skipped=%d | total=%d | status=%s",
      g_passed,
      g_failed,
      g_skipped,
      g_passed + g_failed + g_skipped,
      runStatus
   );

   PrintFormat(
      "ORCHESTRATION_VALIDATION_COMPLETE | positive_case=%s | order_send_attempted=%s | no_retry=true",
      positiveCaseStatus,
      orderSendAttempted ? "true" : "false"
   );
}

bool LoadValidationVolumeModel(
   double &volumeMin,
   double &volumeMax,
   double &volumeStep
)
{
   volumeMin = 0.0;
   volumeMax = 0.0;
   volumeStep = 0.0;

   ResetLastError();

   if(!SymbolInfoDouble(
      _Symbol,
      SYMBOL_VOLUME_MIN,
      volumeMin
   ))
   {
      PrintFormat(
         "ORCHESTRATION_VALIDATION_ABORT | SYMBOL_VOLUME_MIN lookup failed | error=%d",
         GetLastError()
      );

      return(false);
   }

   ResetLastError();

   if(!SymbolInfoDouble(
      _Symbol,
      SYMBOL_VOLUME_MAX,
      volumeMax
   ))
   {
      PrintFormat(
         "ORCHESTRATION_VALIDATION_ABORT | SYMBOL_VOLUME_MAX lookup failed | error=%d",
         GetLastError()
      );

      return(false);
   }

   ResetLastError();

   if(!SymbolInfoDouble(
      _Symbol,
      SYMBOL_VOLUME_STEP,
      volumeStep
   ))
   {
      PrintFormat(
         "ORCHESTRATION_VALIDATION_ABORT | SYMBOL_VOLUME_STEP lookup failed | error=%d",
         GetLastError()
      );

      return(false);
   }

   if(
      !MathIsValidNumber(volumeMin) ||
      !MathIsValidNumber(volumeMax) ||
      !MathIsValidNumber(volumeStep) ||
      volumeMin <= 0.0 ||
      volumeMax < volumeMin ||
      volumeStep <= 0.0
   )
   {
      PrintFormat(
         "ORCHESTRATION_VALIDATION_ABORT | invalid volume model | min=%G | max=%G | step=%G",
         volumeMin,
         volumeMax,
         volumeStep
      );

      return(false);
   }

   return(true);
}

bool BuildApprovedValidationRiskPlan(
   const PreTradeMarketSnapshot &snapshot,
   RiskTradePlan &riskPlan
)
{
   if(
      StringLen(snapshot.symbol) == 0 ||
      snapshot.timeMsc <= 0 ||
      !MathIsValidNumber(snapshot.ask) ||
      snapshot.ask <= 0.0
   )
   {
      Print(
         "ORCHESTRATION_VALIDATION_ABORT | invalid seed market snapshot."
      );

      return(false);
   }

   if(!BuildBaselineRiskTradePlan(
      SIGNAL_BUY,
      snapshot.ask,
      VALIDATION_ATR_VALUE,
      VALIDATION_RISK_REWARD_RATIO,
      riskPlan
   ))
   {
      Print(
         "ORCHESTRATION_VALIDATION_ABORT | baseline risk plan build failed."
      );

      return(false);
   }

   PrintFormat(
      "ORCHESTRATION_VALIDATION_PLAN | direction=%s | entry=%G | sl=%G | tp=%G | stop_distance=%G",
      EnumToString(
         riskPlan.direction
      ),
      riskPlan.entryPrice,
      riskPlan.stopLossPrice,
      riskPlan.takeProfitPrice,
      riskPlan.stopDistance
   );

   return(true);
}

bool IsImmediatePositiveSubmissionStatus(
   const TradeSubmissionStatus status
)
{
   return(
      status == TRADE_SUBMISSION_SERVER_PLACED ||
      status == TRADE_SUBMISSION_SERVER_DONE ||
      status == TRADE_SUBMISSION_SERVER_DONE_PARTIAL
   );
}

void LogExecutionResult(
   const string caseName,
   const bool evaluationSuccess,
   const TradeExecutionResult &result
)
{
   PrintFormat(
      "ORCHESTRATION_RESULT | case=%s | evaluation_success=%s | status=%s | bid=%G | ask=%G | spread_points=%G | trade_mode=%s | session_allowed=%s | geometry_valid=%s | entry=%G | sl=%G | tp=%G | original_stop_distance=%G | final_stop_distance=%G | stop_distance_changed=%s | equity=%G | raw_volume=%G | normalized_volume=%G | margin_allowed=%s | required_margin=%G | free_margin=%G | request_valid=%s | request_volume=%G | request_filling=%s | order_send_attempted=%s | submission_stage=%s | order_send_returned_true=%s | submission_status=%s | last_error=%d | retcode=%u | order=%I64u | deal=%I64u | execution_volume=%G | execution_price=%G | result_bid=%G | result_ask=%G | request_id=%u | comment=%s",
      caseName,
      evaluationSuccess
         ? "true"
         : "false",
      EnumToString(
         result.status
      ),
      result.marketSnapshot.bid,
      result.marketSnapshot.ask,
      result.spreadGate.observedSpreadPoints,
      EnumToString(
         result.tradeMode
      ),
      result.sessionGate.allowed
         ? "true"
         : "false",
      result.geometry.valid
         ? "true"
         : "false",
      result.geometry.entryPrice,
      result.geometry.stopLossPrice,
      result.geometry.takeProfitPrice,
      result.geometry.originalStopDistance,
      result.geometry.finalStopDistance,
      result.geometry.stopDistanceChanged
         ? "true"
         : "false",
      result.equity,
      result.riskSizing.sizing.rawVolume,
      result.riskSizing.normalizedVolume,
      result.marginValidation.allowed
         ? "true"
         : "false",
      result.marginValidation.requiredMargin,
      result.marginValidation.freeMargin,
      result.requestBuild.valid
         ? "true"
         : "false",
      result.requestBuild.request.volume,
      EnumToString(
         result.requestBuild.request.type_filling
      ),
      result.submission.orderSendAttempted
         ? "true"
         : "false",
      EnumToString(
         result.submission.status
      ),
      result.submission.submissionResult.orderSendReturnedTrue
         ? "true"
         : "false",
      EnumToString(
         result.submission.submissionResult.status
      ),
      result.submission.submissionResult.lastError,
      result.submission.submissionResult.tradeResult.retcode,
      result.submission.submissionResult.tradeResult.order,
      result.submission.submissionResult.tradeResult.deal,
      result.submission.submissionResult.tradeResult.volume,
      result.submission.submissionResult.tradeResult.price,
      result.submission.submissionResult.tradeResult.bid,
      result.submission.submissionResult.tradeResult.ask,
      result.submission.submissionResult.tradeResult.request_id,
      result.submission.submissionResult.tradeResult.comment
   );
}

int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER))
   {
      Print(
         "ORCHESTRATION_VALIDATION_ABORT | Strategy Tester execution required."
      );

      return(INIT_FAILED);
   }

   if(MQLInfoInteger(MQL_OPTIMIZATION))
   {
      Print(
         "ORCHESTRATION_VALIDATION_ABORT | Optimization execution is not allowed."
      );

      return(INIT_FAILED);
   }

   PrintFormat(
      "ORCHESTRATION_VALIDATION_INIT | symbol=%s | timeframe=%s | tester=true | optimization=false | terminal_build=%d | positive_submission_enabled=%s",
      _Symbol,
      EnumToString(
         (ENUM_TIMEFRAMES)_Period
      ),
      (int)TerminalInfoInteger(
         TERMINAL_BUILD
      ),
      ValidationEnablePositiveSubmission ? "true" : "false"
   );

   return(INIT_SUCCEEDED);
}

void OnTick()
{
   if(g_validationFinished)
      return;

   if(!MQLInfoInteger(MQL_TESTER))
   {
      Print(
         "ORCHESTRATION_VALIDATION_ABORT | Strategy Tester execution required."
      );

      g_validationFinished = true;

      return;
   }

   if(MQLInfoInteger(MQL_OPTIMIZATION))
   {
      Print(
         "ORCHESTRATION_VALIDATION_ABORT | Optimization execution is not allowed."
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
         "ORCHESTRATION_VALIDATION_ABORT | tester state is not clean | positions=%d | orders=%d",
         PositionsTotal(),
         OrdersTotal()
      );

      g_validationFinished = true;

      return;
   }

   PreTradeMarketSnapshot seedSnapshot;

   if(!LoadPreTradeMarketSnapshot(
      _Symbol,
      seedSnapshot
   ))
   {
      Print(
         "ORCHESTRATION_VALIDATION_ABORT | seed market snapshot failed."
      );

      g_validationFinished = true;

      return;
   }

   const double observedSpreadPoints =
      (
         seedSnapshot.ask -
         seedSnapshot.bid
      ) /
      seedSnapshot.point;

   if(
      !MathIsValidNumber(
         observedSpreadPoints
      ) ||
      observedSpreadPoints <= 0.0
   )
   {
      PrintFormat(
         "ORCHESTRATION_VALIDATION_ABORT | invalid observed spread | bid=%G | ask=%G | point=%G | spread_points=%G",
         seedSnapshot.bid,
         seedSnapshot.ask,
         seedSnapshot.point,
         observedSpreadPoints
      );

      g_validationFinished = true;

      return;
   }

   double volumeMin = 0.0;
   double volumeMax = 0.0;
   double volumeStep = 0.0;

   if(!LoadValidationVolumeModel(
      volumeMin,
      volumeMax,
      volumeStep
   ))
   {
      g_validationFinished = true;

      return;
   }

   RiskTradePlan riskPlan;

   if(!BuildApprovedValidationRiskPlan(
      seedSnapshot,
      riskPlan
   ))
   {
      g_validationFinished = true;

      return;
   }

   TradeExecutionSettings allowedSettings;

   allowedSettings.maxSpreadPoints =
      observedSpreadPoints +
      MathMax(
         1000.0,
         observedSpreadPoints
      );

   allowedSettings.maxQuoteAgeSeconds =
      ValidationMaxQuoteAgeSeconds;

   // ---------------------------------------------------------------
   // Case 1:
   // Empty symbol must fail before any submission can be attempted.
   // ---------------------------------------------------------------

   TradeExecutionResult invalidSymbolResult;

   const bool invalidSymbolEvaluation =
      ExecuteApprovedTradeIntent(
         "",
         riskPlan,
         VALIDATION_RISK_PERCENT,
         VALIDATION_RISK_REWARD_RATIO,
         volumeMin,
         volumeMax,
         volumeStep,
         allowedSettings,
         VALIDATION_MAGIC_NUMBER,
         VALIDATION_DEVIATION_POINTS,
         invalidSymbolResult
      );

   RecordTestResult(
      "invalid_symbol_rejected",
      !invalidSymbolEvaluation &&
      invalidSymbolResult.status ==
         TRADE_EXECUTION_INVALID_INPUT &&
      !invalidSymbolResult.submission.orderSendAttempted
   );

   // ---------------------------------------------------------------
   // Case 2:
   // Invalid execution settings must fail before broker execution.
   // ---------------------------------------------------------------

   TradeExecutionSettings invalidSettings;

   invalidSettings.maxSpreadPoints = 0.0;
   invalidSettings.maxQuoteAgeSeconds =
      ValidationMaxQuoteAgeSeconds;

   TradeExecutionResult invalidSettingsResult;

   const bool invalidSettingsEvaluation =
      ExecuteApprovedTradeIntent(
         _Symbol,
         riskPlan,
         VALIDATION_RISK_PERCENT,
         VALIDATION_RISK_REWARD_RATIO,
         volumeMin,
         volumeMax,
         volumeStep,
         invalidSettings,
         VALIDATION_MAGIC_NUMBER,
         VALIDATION_DEVIATION_POINTS,
         invalidSettingsResult
      );

   RecordTestResult(
      "invalid_settings_rejected",
      !invalidSettingsEvaluation &&
      invalidSettingsResult.status ==
         TRADE_EXECUTION_SETTINGS_INVALID &&
      !invalidSettingsResult.submission.orderSendAttempted
   );

   // ---------------------------------------------------------------
   // Case 3:
   // A valid but deliberately tight spread limit must block safely.
   // ---------------------------------------------------------------

   TradeExecutionSettings blockedSpreadSettings;

   blockedSpreadSettings.maxSpreadPoints =
      observedSpreadPoints / 2.0;

   blockedSpreadSettings.maxQuoteAgeSeconds =
      ValidationMaxQuoteAgeSeconds;

   TradeExecutionResult spreadBlockedResult;

   const bool spreadBlockedEvaluation =
      ExecuteApprovedTradeIntent(
         _Symbol,
         riskPlan,
         VALIDATION_RISK_PERCENT,
         VALIDATION_RISK_REWARD_RATIO,
         volumeMin,
         volumeMax,
         volumeStep,
         blockedSpreadSettings,
         VALIDATION_MAGIC_NUMBER,
         VALIDATION_DEVIATION_POINTS,
         spreadBlockedResult
      );

   RecordTestResult(
      "spread_gate_blocks_before_submission",
      spreadBlockedEvaluation &&
      spreadBlockedResult.status ==
         TRADE_EXECUTION_SPREAD_BLOCKED &&
      !spreadBlockedResult.submission.orderSendAttempted
   );

   LogExecutionResult(
      "spread_blocked",
      spreadBlockedEvaluation,
      spreadBlockedResult
   );

   // ---------------------------------------------------------------
   // Case 4:
   // Optional controlled submission in the Strategy Tester only.
   // Never execute after a failed negative test or without opt-in.
   // ---------------------------------------------------------------

   if(g_failed > 0)
   {
      RecordTestSkip(
         "full_orchestration_submits_once",
         "negative_tests_failed"
      );

      LogValidationSummary("SKIPPED_NEGATIVE_FAILURE", false);
      g_validationFinished = true;
      return;
   }

   if(!ValidationEnablePositiveSubmission)
   {
      RecordTestSkip(
         "full_orchestration_submits_once",
         "positive_submission_disabled"
      );

      LogValidationSummary("SKIPPED_DISABLED", false);
      g_validationFinished = true;
      return;
   }

   Print("ORCHESTRATION_TEST_EXECUTE | case=full_orchestration_submits_once | tester=true | positive_submission_enabled=true");

   TradeExecutionResult fullExecutionResult;

   const bool fullExecutionEvaluation =
      ExecuteApprovedTradeIntent(
         _Symbol,
         riskPlan,
         VALIDATION_RISK_PERCENT,
         VALIDATION_RISK_REWARD_RATIO,
         volumeMin,
         volumeMax,
         volumeStep,
         allowedSettings,
         VALIDATION_MAGIC_NUMBER,
         VALIDATION_DEVIATION_POINTS,
         fullExecutionResult
      );

   const bool positiveSubmission =
      fullExecutionEvaluation &&
      fullExecutionResult.status ==
         TRADE_EXECUTION_ORDER_SEND_EVALUATED &&
      fullExecutionResult.submission.orderSendAttempted &&
      fullExecutionResult.submission.submissionResult.
         orderSendReturnedTrue &&
      IsImmediatePositiveSubmissionStatus(
         fullExecutionResult.submission.
            submissionResult.status
      );

   RecordTestResult(
      "full_orchestration_submits_once",
      positiveSubmission
   );

   LogExecutionResult(
      "full_execution",
      fullExecutionEvaluation,
      fullExecutionResult
   );

   LogValidationSummary(
      "EXECUTED",
      fullExecutionResult.submission.orderSendAttempted
   );

   g_validationFinished = true;
}
