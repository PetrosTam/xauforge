#property strict

#include <XAUForge/TradeManager.mqh>

// Deterministic test fixture; these are NOT live market observations.
const datetime TEST_BROKER_TIME = (datetime)1700000100;

int g_passed = 0;
int g_failed = 0;

void RecordQuoteTest(const string name, const bool passed)
{
   if(passed)
      g_passed++;
   else
      g_failed++;

   PrintFormat(
      "QUOTE_FRESHNESS_TEST_%s | case=%s",
      passed ? "PASS" : "FAIL",
      name
   );
}

int OnInit()
{
   PreTradeMarketSnapshot snapshot;
   ResetPreTradeMarketSnapshot(snapshot);
   snapshot.symbol = "XAUUSD";
   snapshot.bid = 2000.00;
   snapshot.ask = 2000.20;
   snapshot.point = 0.01;

   QuoteFreshnessResult result;
   bool evaluated = false;

   // Same-second timestamps are allowed, including subsecond ticks.
   snapshot.timeMsc = (long)TEST_BROKER_TIME * 1000;
   evaluated = EvaluateQuoteFreshness(snapshot, TEST_BROKER_TIME, 5, result);
   RecordQuoteTest(
      "current_quote_allowed",
      evaluated && result.allowed &&
      result.status == QUOTE_FRESHNESS_ALLOWED &&
      result.observedAgeSeconds == 0
   );

   snapshot.timeMsc = (long)TEST_BROKER_TIME * 1000 + 750;
   evaluated = EvaluateQuoteFreshness(snapshot, TEST_BROKER_TIME, 5, result);
   RecordQuoteTest(
      "fractional_same_second_allowed",
      evaluated && result.allowed &&
      result.status == QUOTE_FRESHNESS_ALLOWED
   );

   snapshot.timeMsc = ((long)TEST_BROKER_TIME - 5) * 1000;
   evaluated = EvaluateQuoteFreshness(snapshot, TEST_BROKER_TIME, 5, result);
   RecordQuoteTest(
      "exact_age_limit_allowed",
      evaluated && result.allowed &&
      result.observedAgeSeconds == 5
   );

   snapshot.timeMsc = ((long)TEST_BROKER_TIME - 6) * 1000;
   evaluated = EvaluateQuoteFreshness(snapshot, TEST_BROKER_TIME, 5, result);
   RecordQuoteTest(
      "one_second_over_limit_blocked",
      evaluated && !result.allowed &&
      result.status == QUOTE_FRESHNESS_STALE &&
      result.observedAgeSeconds == 6
   );

   snapshot.timeMsc = ((long)TEST_BROKER_TIME + 1) * 1000;
   evaluated = EvaluateQuoteFreshness(snapshot, TEST_BROKER_TIME, 5, result);
   RecordQuoteTest(
      "future_quote_blocked",
      evaluated && !result.allowed &&
      result.status == QUOTE_FRESHNESS_FUTURE_TIMESTAMP
   );

   snapshot.timeMsc = 0;
   evaluated = EvaluateQuoteFreshness(snapshot, TEST_BROKER_TIME, 5, result);
   RecordQuoteTest(
      "missing_tick_time_rejected",
      !evaluated && !result.allowed &&
      result.status == QUOTE_FRESHNESS_INVALID_INPUT
   );

   snapshot.timeMsc = (long)TEST_BROKER_TIME * 1000;
   evaluated = EvaluateQuoteFreshness(snapshot, (datetime)0, 5, result);
   RecordQuoteTest(
      "missing_broker_time_rejected",
      !evaluated && !result.allowed &&
      result.status == QUOTE_FRESHNESS_INVALID_INPUT
   );

   evaluated = EvaluateQuoteFreshness(snapshot, TEST_BROKER_TIME, 0, result);
   RecordQuoteTest(
      "missing_age_policy_rejected",
      !evaluated && !result.allowed &&
      result.status == QUOTE_FRESHNESS_INVALID_INPUT
   );

   snapshot.symbol = "";
   evaluated = EvaluateQuoteFreshness(snapshot, TEST_BROKER_TIME, 5, result);
   RecordQuoteTest(
      "missing_symbol_rejected",
      !evaluated && !result.allowed &&
      result.status == QUOTE_FRESHNESS_INVALID_INPUT
   );

   TradeExecutionSettings settings;
   settings.maxSpreadPoints = 30.0;
   settings.maxQuoteAgeSeconds = 5;
   RecordQuoteTest(
      "explicit_age_policy_valid",
      ValidateTradeExecutionSettings(settings)
   );

   settings.maxQuoteAgeSeconds = 0;
   RecordQuoteTest(
      "missing_age_policy_fails_safe",
      !ValidateTradeExecutionSettings(settings)
   );

   PrintFormat(
      "QUOTE_FRESHNESS_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );

   return(g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED);
}

void OnTick()
{
   // This regression never submits trading orders.
}
