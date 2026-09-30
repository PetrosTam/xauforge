#include <XAUForge/StrategyEngine.mqh>
#include <XAUForge/SymbolManager.mqh>

input ENUM_TIMEFRAMES SignalTimeframe = PERIOD_H1;

datetime g_lastBarOpenTime = 0;
SymbolCapabilities g_symbolCapabilities;
AccountPositionMode g_accountPositionMode = ACCOUNT_POSITION_MODE_UNKNOWN;

bool IsNewBar()
{
   const datetime currentBarOpenTime = iTime(_Symbol, SignalTimeframe, 0);

   if(currentBarOpenTime == 0)
      return(false);

   if(currentBarOpenTime == g_lastBarOpenTime)
      return(false);

   g_lastBarOpenTime = currentBarOpenTime;

   return(true);
}

int OnInit()
{
   ResetLastError();

   g_lastBarOpenTime = iTime(_Symbol, SignalTimeframe, 0);

   if(g_lastBarOpenTime == 0)
   {
      PrintFormat(
         "Failed to initialize current bar time. Error: %d",
         GetLastError()
      );

      return(INIT_FAILED);
   }

   if(!LoadSymbolCapabilities(_Symbol, g_symbolCapabilities))
   {
      PrintFormat(
         "Failed to load symbol capabilities for %s.",
         _Symbol
      );

      return(INIT_FAILED);
   }

   if(!ValidateSymbolCapabilities(g_symbolCapabilities))
   {
      PrintFormat(
         "Symbol capabilities are invalid for %s.",
         _Symbol
      );

      return(INIT_FAILED);
   }

   if(!DetectAccountPositionMode(g_accountPositionMode))
   {
      Print("Failed to classify account position mode.");
      return(INIT_FAILED);
   }

   PrintFormat(
      "Symbol capabilities | symbol=%s | digits=%d | point=%G | tick_size=%G | tick_value=%G | volume_min=%G | volume_max=%G | volume_step=%G | stops_level=%d | freeze_level=%d | trade_mode=%s | order_mode=%d | execution_mode=%s | filling_mode=%d | contract_size=%G | calculation_mode=%s",
      g_symbolCapabilities.symbol,
      g_symbolCapabilities.digits,
      g_symbolCapabilities.point,
      g_symbolCapabilities.tickSize,
      g_symbolCapabilities.tickValue,
      g_symbolCapabilities.volumeMin,
      g_symbolCapabilities.volumeMax,
      g_symbolCapabilities.volumeStep,
      g_symbolCapabilities.stopsLevel,
      g_symbolCapabilities.freezeLevel,
      EnumToString(g_symbolCapabilities.tradeMode),
      g_symbolCapabilities.orderMode,
      EnumToString(g_symbolCapabilities.executionMode),
      g_symbolCapabilities.fillingMode,
      g_symbolCapabilities.contractSize,
      EnumToString(g_symbolCapabilities.calculationMode)
   );

   PrintFormat(
      "Account position mode: %s",
      EnumToString(g_accountPositionMode)
   );

   if(!InitializeStrategyIndicators(_Symbol, SignalTimeframe))
      return(INIT_FAILED);

   return(INIT_SUCCEEDED);
}

void OnTick()
{
   if(!IsNewBar())
      return;

   CompletedStrategyData data;

   if(!ReadCompletedStrategyData(_Symbol, SignalTimeframe, data))
      return;

   const SignalDirection signal = EvaluateSignal(data);

   PrintFormat(
      "Strategy evaluated at %s | Signal: %s | EMA20[2]: %.5f | EMA20[1]: %.5f | EMA50[2]: %.5f | EMA50[1]: %.5f | ATR14[1]: %.5f",
      TimeToString(g_lastBarOpenTime, TIME_DATE | TIME_MINUTES),
      EnumToString(signal),
      data.fastEmaShift2,
      data.fastEmaShift1,
      data.slowEmaShift2,
      data.slowEmaShift1,
      data.atrShift1
   );
}

void OnDeinit(const int reason)
{
   ReleaseStrategyIndicators();

   PrintFormat("XAUForge deinitialized. Reason: %d", reason);
}
