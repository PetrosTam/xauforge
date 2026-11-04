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
         "SUBMISSION_PERMISSION_TEST_PASS | case=%s",
         caseName
      );

      return;
   }

   g_failed++;

   PrintFormat(
      "SUBMISSION_PERMISSION_TEST_FAIL | case=%s",
      caseName
   );
}

void SetPermissionSnapshot(
   TradeSubmissionPermissionSnapshot &snapshot,
   const bool testerMode,
   const bool terminalConnected,
   const bool terminalTradeAllowed,
   const bool programTradeAllowed,
   const bool accountTradeAllowed,
   const bool accountExpertTradeAllowed
)
{
   ResetTradeSubmissionPermissionSnapshot(
      snapshot
   );

   snapshot.valid = true;

   snapshot.testerMode =
      testerMode;

   snapshot.terminalConnected =
      terminalConnected;

   snapshot.terminalTradeAllowed =
      terminalTradeAllowed;

   snapshot.programTradeAllowed =
      programTradeAllowed;

   snapshot.accountTradeAllowed =
      accountTradeAllowed;

   snapshot.accountExpertTradeAllowed =
      accountExpertTradeAllowed;
}

void OnStart()
{
   TradeSubmissionPermissionSnapshot snapshot;
   TradeSubmissionPermissionResult result;

   // ---------------------------------------------------------------
   // Case 1:
   // Reset state must be deterministic and fail-safe.
   // ---------------------------------------------------------------

   snapshot.valid = true;
   snapshot.testerMode = true;
   snapshot.terminalConnected = true;
   snapshot.terminalTradeAllowed = true;
   snapshot.programTradeAllowed = true;
   snapshot.accountTradeAllowed = true;
   snapshot.accountExpertTradeAllowed = true;

   ResetTradeSubmissionPermissionSnapshot(
      snapshot
   );

   RecordTestResult(
      "snapshot_reset_state",
      !snapshot.valid &&
      !snapshot.testerMode &&
      !snapshot.terminalConnected &&
      !snapshot.terminalTradeAllowed &&
      !snapshot.programTradeAllowed &&
      !snapshot.accountTradeAllowed &&
      !snapshot.accountExpertTradeAllowed
   );

   result.allowed = true;
   result.status =
      TRADE_SUBMISSION_PERMISSION_ALLOWED;

   ResetTradeSubmissionPermissionResult(
      result
   );

   RecordTestResult(
      "result_reset_state",
      !result.allowed &&
      result.status ==
         TRADE_SUBMISSION_PERMISSION_NOT_EVALUATED
   );

   // ---------------------------------------------------------------
   // Case 2:
   // Invalid snapshot must fail before permission evaluation.
   // ---------------------------------------------------------------

   ResetTradeSubmissionPermissionSnapshot(
      snapshot
   );

   bool evaluationSuccess =
      EvaluateTradeSubmissionPermissions(
         snapshot,
         result
      );

   RecordTestResult(
      "invalid_snapshot_rejected",
      !evaluationSuccess &&
      !result.allowed &&
      result.status ==
         TRADE_SUBMISSION_PERMISSION_INVALID_INPUT
   );

   // ---------------------------------------------------------------
   // Case 3:
   // Normal terminal without connection must be blocked.
   // ---------------------------------------------------------------

   SetPermissionSnapshot(
      snapshot,
      false,
      false,
      true,
      true,
      true,
      true
   );

   evaluationSuccess =
      EvaluateTradeSubmissionPermissions(
         snapshot,
         result
      );

   RecordTestResult(
      "live_terminal_disconnected",
      evaluationSuccess &&
      !result.allowed &&
      result.status ==
         TRADE_SUBMISSION_PERMISSION_TERMINAL_DISCONNECTED
   );

   // ---------------------------------------------------------------
   // Case 4:
   // Terminal-level Algo Trading disabled.
   // ---------------------------------------------------------------

   SetPermissionSnapshot(
      snapshot,
      false,
      true,
      false,
      true,
      true,
      true
   );

   evaluationSuccess =
      EvaluateTradeSubmissionPermissions(
         snapshot,
         result
      );

   RecordTestResult(
      "terminal_trading_disabled",
      evaluationSuccess &&
      !result.allowed &&
      result.status ==
         TRADE_SUBMISSION_PERMISSION_TERMINAL_TRADING_DISABLED
   );

   // ---------------------------------------------------------------
   // Case 5:
   // Trading disabled for this MQL program.
   // ---------------------------------------------------------------

   SetPermissionSnapshot(
      snapshot,
      false,
      true,
      true,
      false,
      true,
      true
   );

   evaluationSuccess =
      EvaluateTradeSubmissionPermissions(
         snapshot,
         result
      );

   RecordTestResult(
      "program_trading_disabled",
      evaluationSuccess &&
      !result.allowed &&
      result.status ==
         TRADE_SUBMISSION_PERMISSION_PROGRAM_TRADING_DISABLED
   );

   // ---------------------------------------------------------------
   // Case 6:
   // Account does not permit trading.
   // ---------------------------------------------------------------

   SetPermissionSnapshot(
      snapshot,
      false,
      true,
      true,
      true,
      false,
      true
   );

   evaluationSuccess =
      EvaluateTradeSubmissionPermissions(
         snapshot,
         result
      );

   RecordTestResult(
      "account_trading_disabled",
      evaluationSuccess &&
      !result.allowed &&
      result.status ==
         TRADE_SUBMISSION_PERMISSION_ACCOUNT_TRADING_DISABLED
   );

   // ---------------------------------------------------------------
   // Case 7:
   // Account does not permit Expert Advisor trading.
   // ---------------------------------------------------------------

   SetPermissionSnapshot(
      snapshot,
      false,
      true,
      true,
      true,
      true,
      false
   );

   evaluationSuccess =
      EvaluateTradeSubmissionPermissions(
         snapshot,
         result
      );

   RecordTestResult(
      "account_expert_trading_disabled",
      evaluationSuccess &&
      !result.allowed &&
      result.status ==
         TRADE_SUBMISSION_PERMISSION_ACCOUNT_EXPERT_TRADING_DISABLED
   );

   // ---------------------------------------------------------------
   // Case 8:
   // Fully allowed normal terminal environment.
   // ---------------------------------------------------------------

   SetPermissionSnapshot(
      snapshot,
      false,
      true,
      true,
      true,
      true,
      true
   );

   evaluationSuccess =
      EvaluateTradeSubmissionPermissions(
         snapshot,
         result
      );

   RecordTestResult(
      "live_environment_allowed",
      evaluationSuccess &&
      result.allowed &&
      result.status ==
         TRADE_SUBMISSION_PERMISSION_ALLOWED
   );

   // ---------------------------------------------------------------
   // Case 9:
   // Strategy Tester does not require a live terminal connection.
   // All actual trade permissions must still be allowed.
   // ---------------------------------------------------------------

   SetPermissionSnapshot(
      snapshot,
      true,
      false,
      true,
      true,
      true,
      true
   );

   evaluationSuccess =
      EvaluateTradeSubmissionPermissions(
         snapshot,
         result
      );

   RecordTestResult(
      "tester_mode_allows_disconnected_terminal",
      evaluationSuccess &&
      result.allowed &&
      result.status ==
         TRADE_SUBMISSION_PERMISSION_ALLOWED
   );

   // ---------------------------------------------------------------
   // Current environment observation.
   // No OrderCheck and no OrderSend.
   // ---------------------------------------------------------------

   TradeSubmissionPermissionSnapshot currentSnapshot;
   TradeSubmissionPermissionResult currentResult;

   const bool currentEvaluationSuccess =
      EvaluateCurrentTradeSubmissionPermissions(
         currentSnapshot,
         currentResult
      );

   PrintFormat(
      "SUBMISSION_PERMISSION_OBSERVATION | evaluation_success=%s | allowed=%s | status=%s | tester=%s | terminal_connected=%s | terminal_trade_allowed=%s | program_trade_allowed=%s | account_trade_allowed=%s | account_expert_trade_allowed=%s",
      currentEvaluationSuccess
         ? "true"
         : "false",
      currentResult.allowed
         ? "true"
         : "false",
      EnumToString(
         currentResult.status
      ),
      currentSnapshot.testerMode
         ? "true"
         : "false",
      currentSnapshot.terminalConnected
         ? "true"
         : "false",
      currentSnapshot.terminalTradeAllowed
         ? "true"
         : "false",
      currentSnapshot.programTradeAllowed
         ? "true"
         : "false",
      currentSnapshot.accountTradeAllowed
         ? "true"
         : "false",
      currentSnapshot.accountExpertTradeAllowed
         ? "true"
         : "false"
   );

   PrintFormat(
      "SUBMISSION_PERMISSION_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );
}
