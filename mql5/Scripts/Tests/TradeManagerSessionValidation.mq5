#property strict

#include <XAUForge/TradeManager.mqh>

int g_passed = 0;
int g_failed = 0;

void CheckSessionWindowCase(
   const string caseName,
   const long observationOffsetSeconds,
   const long sessionFromSeconds,
   const long sessionToSeconds,
   const bool expectedEvaluationSuccess,
   const bool expectedActive
)
{
   bool active = false;

   const bool evaluationSuccess =
      IsTradeSessionWindowActive(
         observationOffsetSeconds,
         (datetime)sessionFromSeconds,
         (datetime)sessionToSeconds,
         active
      );

   const bool passed =
      evaluationSuccess == expectedEvaluationSuccess &&
      active == expectedActive;

   if(passed)
   {
      g_passed++;

      PrintFormat(
         "SESSION_WINDOW_TEST_PASS | case=%s | evaluation_success=%s | active=%s | observation=%I64d | from=%I64d | to=%I64d",
         caseName,
         evaluationSuccess ? "true" : "false",
         active ? "true" : "false",
         observationOffsetSeconds,
         sessionFromSeconds,
         sessionToSeconds
      );

      return;
   }

   g_failed++;

   PrintFormat(
      "SESSION_WINDOW_TEST_FAIL | case=%s | evaluation_success=%s | active=%s | expected_success=%s | expected_active=%s | observation=%I64d | from=%I64d | to=%I64d",
      caseName,
      evaluationSuccess ? "true" : "false",
      active ? "true" : "false",
      expectedEvaluationSuccess ? "true" : "false",
      expectedActive ? "true" : "false",
      observationOffsetSeconds,
      sessionFromSeconds,
      sessionToSeconds
   );
}

void OnStart()
{
   const long hour = 3600;

   // Normal session: 09:00 -> 17:00.

   CheckSessionWindowCase(
      "before_start",
      9 * hour - 1,
      9 * hour,
      17 * hour,
      true,
      false
   );

   CheckSessionWindowCase(
      "exact_start",
      9 * hour,
      9 * hour,
      17 * hour,
      true,
      true
   );

   CheckSessionWindowCase(
      "inside_normal",
      12 * hour,
      9 * hour,
      17 * hour,
      true,
      true
   );

   CheckSessionWindowCase(
      "exact_end",
      17 * hour,
      9 * hour,
      17 * hour,
      true,
      false
   );

   // Full-day session: 00:00 -> 24:00.

   CheckSessionWindowCase(
      "full_day_last_second",
      TRADE_SESSION_SECONDS_PER_DAY - 1,
      0,
      TRADE_SESSION_SECONDS_PER_DAY,
      true,
      true
   );

   // Cross-midnight session:
   // 21:00 -> next day 08:00.
   // End = 24h + 8h = 32h.

   CheckSessionWindowCase(
      "cross_midnight_before_midnight",
      22 * hour,
      21 * hour,
      32 * hour,
      true,
      true
   );

   CheckSessionWindowCase(
      "cross_midnight_next_day",
      25 * hour,
      21 * hour,
      32 * hour,
      true,
      true
   );

   CheckSessionWindowCase(
      "cross_midnight_exact_end",
      32 * hour,
      21 * hour,
      32 * hour,
      true,
      false
   );

   // Invalid session: start == end.

   CheckSessionWindowCase(
      "invalid_equal_bounds",
      10 * hour,
      9 * hour,
      9 * hour,
      false,
      false
   );

   // Invalid observation offset.

   CheckSessionWindowCase(
      "invalid_observation",
      -1,
      9 * hour,
      17 * hour,
      false,
      false
   );

   PrintFormat(
      "SESSION_WINDOW_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );

   const datetime observedBrokerTime =
      TimeTradeServer();

   TradeSessionGateResult sessionResult;

   const bool evaluationSuccess =
      EvaluateTradeSessionGate(
         _Symbol,
         observedBrokerTime,
         sessionResult
      );

   PrintFormat(
      "TRADE_SESSION_OBSERVATION | symbol=%s | broker_time=%s | evaluation_success=%s | allowed=%s | status=%s | observation_day=%s | observation_seconds=%d | matched_day=%s | matched_index=%d | matched_from=%I64d | matched_to=%I64d",
      _Symbol,
      TimeToString(
         observedBrokerTime,
         TIME_DATE | TIME_SECONDS
      ),
      evaluationSuccess ? "true" : "false",
      sessionResult.allowed ? "true" : "false",
      EnumToString(sessionResult.status),
      EnumToString(sessionResult.observationDay),
      sessionResult.observationSeconds,
      EnumToString(sessionResult.matchedSessionDay),
      sessionResult.matchedSessionIndex,
      sessionResult.matchedSessionFromSeconds,
      sessionResult.matchedSessionToSeconds
   );
}
