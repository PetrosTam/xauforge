#property strict

#include <XAUForge/TradeManager.mqh>

int g_passed = 0;
int g_failed = 0;

void SeedSnapshot(PreTradeMarketSnapshot &snapshot)
{
   snapshot.symbol = "PREVIOUS";
   snapshot.timeMsc = 1234567;
   snapshot.bid = 100.0;
   snapshot.ask = 101.0;
   snapshot.point = 0.01;
}

bool IsSnapshotReset(const PreTradeMarketSnapshot &snapshot)
{
   return(
      snapshot.symbol == "" &&
      snapshot.timeMsc == 0 &&
      snapshot.bid == 0.0 &&
      snapshot.ask == 0.0 &&
      snapshot.point == 0.0
   );
}

void RecordSnapshotTest(const string name, const bool passed)
{
   if(passed)
      g_passed++;
   else
      g_failed++;

   PrintFormat(
      "MARKET_SNAPSHOT_TEST_%s | case=%s",
      passed ? "PASS" : "FAIL",
      name
   );
}

void OnStart()
{
   PreTradeMarketSnapshot snapshot;

   // Case 1: Empty symbol must fail and clear prior data.
   SeedSnapshot(snapshot);

   const bool emptyLoaded =
      LoadPreTradeMarketSnapshot("", snapshot);

   RecordSnapshotTest(
      "empty_symbol_rejected_and_reset",
      !emptyLoaded && IsSnapshotReset(snapshot)
   );

   // Case 2: An unavailable symbol must fail tick lookup.
   const string missingSymbol = "XAUFNOTREAL";
   bool isCustom = false;

   if(SymbolExist(missingSymbol, isCustom))
   {
      Print(
         "MARKET_SNAPSHOT_TEST_ABORT | missing symbol name exists."
      );

      RecordSnapshotTest(
         "unavailable_symbol_rejected_and_reset",
         false
      );
   }
   else
   {
      SeedSnapshot(snapshot);

      const bool missingLoaded =
         LoadPreTradeMarketSnapshot(missingSymbol, snapshot);

      RecordSnapshotTest(
         "unavailable_symbol_rejected_and_reset",
         !missingLoaded && IsSnapshotReset(snapshot)
      );
   }

   PrintFormat(
      "MARKET_SNAPSHOT_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );
}
