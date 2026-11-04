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
         "SUBMISSION_RESULT_TEST_PASS | case=%s",
         caseName
      );

      return;
   }

   g_failed++;

   PrintFormat(
      "SUBMISSION_RESULT_TEST_FAIL | case=%s",
      caseName
   );
}

void CheckClassificationCase(
   const string caseName,
   const bool orderSendReturnedTrue,
   const int lastError,
   const uint retcode,
   const TradeSubmissionStatus expectedStatus
)
{
   MqlTradeResult tradeResult = {};

   tradeResult.retcode =
      retcode;

   TradeSubmissionResult result;

   ClassifyImmediateTradeSubmissionResult(
      orderSendReturnedTrue,
      lastError,
      tradeResult,
      result
   );

   RecordTestResult(
      caseName,
      result.orderSendReturnedTrue ==
         orderSendReturnedTrue &&
      result.status ==
         expectedStatus &&
      result.lastError ==
         lastError &&
      result.tradeResult.retcode ==
         retcode
   );
}

void OnStart()
{
   // ---------------------------------------------------------------
   // Case 1:
   // Reset state must be deterministic and fail-safe.
   // ---------------------------------------------------------------

   TradeSubmissionResult result;

   result.orderSendReturnedTrue = true;
   result.status =
      TRADE_SUBMISSION_SERVER_DONE;
   result.lastError = 123;

   result.tradeResult.retcode =
      TRADE_RETCODE_DONE;
   result.tradeResult.deal = 111;
   result.tradeResult.order = 222;
   result.tradeResult.comment =
      "non-reset";

   ResetTradeSubmissionResult(
      result
   );

   RecordTestResult(
      "reset_state",
      !result.orderSendReturnedTrue &&
      result.status ==
         TRADE_SUBMISSION_NOT_EVALUATED &&
      result.lastError == 0 &&
      result.tradeResult.retcode == 0 &&
      result.tradeResult.deal == 0 &&
      result.tradeResult.order == 0 &&
      StringLen(
         result.tradeResult.comment
      ) == 0
   );

   // ---------------------------------------------------------------
   // Case 2:
   // Native OrderSend false takes precedence over any retcode.
   // The native result must still be preserved for diagnostics.
   // ---------------------------------------------------------------

   CheckClassificationCase(
      "order_send_false_takes_precedence",
      false,
      4756,
      TRADE_RETCODE_DONE,
      TRADE_SUBMISSION_ORDER_SEND_CALL_FAILED
   );

   // ---------------------------------------------------------------
   // Positive immediate server outcomes.
   // ---------------------------------------------------------------

   CheckClassificationCase(
      "server_placed",
      true,
      0,
      TRADE_RETCODE_PLACED,
      TRADE_SUBMISSION_SERVER_PLACED
   );

   CheckClassificationCase(
      "server_done",
      true,
      0,
      TRADE_RETCODE_DONE,
      TRADE_SUBMISSION_SERVER_DONE
   );

   CheckClassificationCase(
      "server_done_partial",
      true,
      0,
      TRADE_RETCODE_DONE_PARTIAL,
      TRADE_SUBMISSION_SERVER_DONE_PARTIAL
   );

   // ---------------------------------------------------------------
   // Known non-success server outcomes.
   // ---------------------------------------------------------------

   CheckClassificationCase(
      "server_requote",
      true,
      0,
      TRADE_RETCODE_REQUOTE,
      TRADE_SUBMISSION_SERVER_NON_SUCCESS
   );

   CheckClassificationCase(
      "server_reject",
      true,
      0,
      TRADE_RETCODE_REJECT,
      TRADE_SUBMISSION_SERVER_NON_SUCCESS
   );

   CheckClassificationCase(
      "server_timeout",
      true,
      0,
      TRADE_RETCODE_TIMEOUT,
      TRADE_SUBMISSION_SERVER_NON_SUCCESS
   );

   CheckClassificationCase(
      "server_invalid_volume",
      true,
      0,
      TRADE_RETCODE_INVALID_VOLUME,
      TRADE_SUBMISSION_SERVER_NON_SUCCESS
   );

   CheckClassificationCase(
      "server_invalid_stops",
      true,
      0,
      TRADE_RETCODE_INVALID_STOPS,
      TRADE_SUBMISSION_SERVER_NON_SUCCESS
   );

   CheckClassificationCase(
      "server_no_money",
      true,
      0,
      TRADE_RETCODE_NO_MONEY,
      TRADE_SUBMISSION_SERVER_NON_SUCCESS
   );

   CheckClassificationCase(
      "server_price_changed",
      true,
      0,
      TRADE_RETCODE_PRICE_CHANGED,
      TRADE_SUBMISSION_SERVER_NON_SUCCESS
   );

   CheckClassificationCase(
      "server_price_off",
      true,
      0,
      TRADE_RETCODE_PRICE_OFF,
      TRADE_SUBMISSION_SERVER_NON_SUCCESS
   );

   // ---------------------------------------------------------------
   // Case 14:
   // Unknown future/unrecognized retcode must never be guessed.
   // ---------------------------------------------------------------

   CheckClassificationCase(
      "unknown_retcode",
      true,
      0,
      99999,
      TRADE_SUBMISSION_SERVER_UNKNOWN
   );

   // ---------------------------------------------------------------
   // Case 15:
   // Preserve the complete native MqlTradeResult and last error.
   // ---------------------------------------------------------------

   MqlTradeResult nativeResult = {};

   nativeResult.retcode =
      TRADE_RETCODE_DONE;

   nativeResult.deal =
      123456789;

   nativeResult.order =
      987654321;

   nativeResult.volume =
      1.23;

   nativeResult.price =
      4172.50;

   nativeResult.bid =
      4172.40;

   nativeResult.ask =
      4172.60;

   nativeResult.comment =
      "synthetic-result";

   nativeResult.request_id =
      42;

   nativeResult.retcode_external =
      7;

   TradeSubmissionResult preservedResult;

   ClassifyImmediateTradeSubmissionResult(
      true,
      321,
      nativeResult,
      preservedResult
   );

   RecordTestResult(
      "native_result_preserved",
      preservedResult.orderSendReturnedTrue &&
      preservedResult.status ==
         TRADE_SUBMISSION_SERVER_DONE &&
      preservedResult.lastError == 321 &&
      preservedResult.tradeResult.retcode ==
         nativeResult.retcode &&
      preservedResult.tradeResult.deal ==
         nativeResult.deal &&
      preservedResult.tradeResult.order ==
         nativeResult.order &&
      preservedResult.tradeResult.volume ==
         nativeResult.volume &&
      preservedResult.tradeResult.price ==
         nativeResult.price &&
      preservedResult.tradeResult.bid ==
         nativeResult.bid &&
      preservedResult.tradeResult.ask ==
         nativeResult.ask &&
      preservedResult.tradeResult.comment ==
         nativeResult.comment &&
      preservedResult.tradeResult.request_id ==
         nativeResult.request_id &&
      preservedResult.tradeResult.retcode_external ==
         nativeResult.retcode_external
   );

   PrintFormat(
      "SUBMISSION_RESULT_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );
}
