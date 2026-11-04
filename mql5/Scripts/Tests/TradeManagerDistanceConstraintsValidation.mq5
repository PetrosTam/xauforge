#property strict

#include <XAUForge/TradeManager.mqh>

int g_passed = 0;
int g_failed = 0;

bool NearlyEqual(
   const double left,
   const double right
)
{
   return(
      MathAbs(left - right) <= 0.000000001
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
         "DISTANCE_CONSTRAINTS_TEST_PASS | case=%s",
         caseName
      );

      return;
   }

   g_failed++;

   PrintFormat(
      "DISTANCE_CONSTRAINTS_TEST_FAIL | case=%s",
      caseName
   );
}

void OnStart()
{
   TradeDistanceConstraints constraints = {};

   // Case 1:
   // Reset must restore a known safe state.
   constraints.point = 1.0;
   constraints.tickSize = 2.0;
   constraints.stopsLevelPoints = 10;
   constraints.freezeLevelPoints = 20;

   ResetTradeDistanceConstraints(
      constraints
   );

   RecordTestResult(
      "reset_state",
      constraints.point == 0.0 &&
      constraints.tickSize == 0.0 &&
      constraints.stopsLevelPoints == 0 &&
      constraints.freezeLevelPoints == 0
   );

   // Case 2:
   // Empty symbol must fail safe and leave reset output.
   constraints.point = 1.0;
   constraints.tickSize = 2.0;
   constraints.stopsLevelPoints = 10;
   constraints.freezeLevelPoints = 20;

   const bool emptySymbolLoaded =
      LoadCurrentTradeDistanceConstraints(
         "",
         constraints
      );

   RecordTestResult(
      "empty_symbol_rejected",
      !emptySymbolLoaded &&
      constraints.point == 0.0 &&
      constraints.tickSize == 0.0 &&
      constraints.stopsLevelPoints == 0 &&
      constraints.freezeLevelPoints == 0
   );

   // Case 3:
   // The attached broker symbol must load structurally valid values.
   const bool brokerLoaded =
      LoadCurrentTradeDistanceConstraints(
         _Symbol,
         constraints
      );

   const bool brokerValuesValid =
      brokerLoaded &&
      MathIsValidNumber(constraints.point) &&
      MathIsValidNumber(constraints.tickSize) &&
      constraints.point > 0.0 &&
      constraints.tickSize > 0.0 &&
      constraints.stopsLevelPoints >= 0 &&
      constraints.freezeLevelPoints >= 0;

   RecordTestResult(
      "broker_values_structurally_valid",
      brokerValuesValid
   );

   // Case 4:
   // Verify that the loader returned exactly the current symbol
   // properties exposed by the terminal.
   double rawPoint = 0.0;
   double rawTickSize = 0.0;
   long rawStopsLevel = 0;
   long rawFreezeLevel = 0;

   const bool rawValuesLoaded =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_POINT,
         rawPoint
      ) &&
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_TRADE_TICK_SIZE,
         rawTickSize
      ) &&
      SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_STOPS_LEVEL,
         rawStopsLevel
      ) &&
      SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_FREEZE_LEVEL,
         rawFreezeLevel
      );

   const bool valuesMatch =
      brokerLoaded &&
      rawValuesLoaded &&
      NearlyEqual(
         constraints.point,
         rawPoint
      ) &&
      NearlyEqual(
         constraints.tickSize,
         rawTickSize
      ) &&
      constraints.stopsLevelPoints ==
         (int)rawStopsLevel &&
      constraints.freezeLevelPoints ==
         (int)rawFreezeLevel;

   RecordTestResult(
      "broker_values_match_terminal",
      valuesMatch
   );

   PrintFormat(
      "DISTANCE_CONSTRAINTS_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );

   PrintFormat(
      "DISTANCE_CONSTRAINTS_OBSERVATION | symbol=%s | loaded=%s | point=%G | tick_size=%G | stops_level=%d | freeze_level=%d",
      _Symbol,
      brokerLoaded ? "true" : "false",
      constraints.point,
      constraints.tickSize,
      constraints.stopsLevelPoints,
      constraints.freezeLevelPoints
   );
}
