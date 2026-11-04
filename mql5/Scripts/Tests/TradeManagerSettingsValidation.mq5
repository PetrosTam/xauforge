#property strict

#include <XAUForge/TradeManager.mqh>

int g_passed = 0;
int g_failed = 0;

void CheckResult(
   const string caseName,
   const bool actual,
   const bool expected
)
{
   if(actual == expected)
   {
      g_passed++;

      PrintFormat(
         "TRADE_SETTINGS_TEST_PASS | case=%s | actual=%s",
         caseName,
         actual ? "true" : "false"
      );

      return;
   }

   g_failed++;

   PrintFormat(
      "TRADE_SETTINGS_TEST_FAIL | case=%s | actual=%s | expected=%s",
      caseName,
      actual ? "true" : "false",
      expected ? "true" : "false"
   );
}

void OnStart()
{
   TradeExecutionSettings settings = {};

   settings.maxSpreadPoints = 1.0;

   // Valid test fixture; not a production quote-age default.
   settings.maxQuoteAgeSeconds = 30;

   CheckResult(
      "positive_finite",
      ValidateTradeExecutionSettings(settings),
      true
   );

   settings.maxSpreadPoints = 0.0;

   CheckResult(
      "zero",
      ValidateTradeExecutionSettings(settings),
      false
   );

   settings.maxSpreadPoints = -1.0;

   CheckResult(
      "negative",
      ValidateTradeExecutionSettings(settings),
      false
   );

   settings.maxSpreadPoints =
      MathArcsin(2.0);

   CheckResult(
      "nan",
      ValidateTradeExecutionSettings(settings),
      false
   );

   // Restore valid spread; exercise the freshness setting alone.
   settings.maxSpreadPoints = 1.0;
   settings.maxQuoteAgeSeconds = 0;

   CheckResult(
      "zero_quote_age_rejected",
      ValidateTradeExecutionSettings(settings),
      false
   );

   settings.maxQuoteAgeSeconds = -1;

   CheckResult(
      "negative_quote_age_rejected",
      ValidateTradeExecutionSettings(settings),
      false
   );

   PrintFormat(
      "TRADE_SETTINGS_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );
}
