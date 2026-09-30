#include <XAUForge/StrategyEngine.mqh>
#include <XAUForge/SymbolManager.mqh>

input ENUM_TIMEFRAMES SignalTimeframe = PERIOD_H1;

datetime g_lastBarOpenTime = 0;

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
