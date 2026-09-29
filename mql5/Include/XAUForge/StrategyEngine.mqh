#ifndef XAUFORGE_STRATEGY_ENGINE_MQH
#define XAUFORGE_STRATEGY_ENGINE_MQH

enum SignalDirection
{
   SIGNAL_NONE,
   SIGNAL_BUY,
   SIGNAL_SELL
};

const int FAST_EMA_PERIOD = 20;
const int SLOW_EMA_PERIOD = 50;
const int ATR_PERIOD      = 14;

int g_fastEmaHandle = INVALID_HANDLE;
int g_slowEmaHandle = INVALID_HANDLE;
int g_atrHandle     = INVALID_HANDLE;

void ReleaseStrategyIndicators()
{
   if(g_fastEmaHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_fastEmaHandle);
      g_fastEmaHandle = INVALID_HANDLE;
   }

   if(g_slowEmaHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_slowEmaHandle);
      g_slowEmaHandle = INVALID_HANDLE;
   }

   if(g_atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
   }
}

bool InitializeStrategyIndicators(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe
)
{
   ResetLastError();

   g_fastEmaHandle = iMA(
      symbol,
      timeframe,
      FAST_EMA_PERIOD,
      0,
      MODE_EMA,
      PRICE_CLOSE
   );

   if(g_fastEmaHandle == INVALID_HANDLE)
   {
      PrintFormat(
         "Failed to create EMA20 handle. Error: %d",
         GetLastError()
      );

      return(false);
   }

   ResetLastError();

   g_slowEmaHandle = iMA(
      symbol,
      timeframe,
      SLOW_EMA_PERIOD,
      0,
      MODE_EMA,
      PRICE_CLOSE
   );

   if(g_slowEmaHandle == INVALID_HANDLE)
   {
      PrintFormat(
         "Failed to create EMA50 handle. Error: %d",
         GetLastError()
      );

      ReleaseStrategyIndicators();
      return(false);
   }

   ResetLastError();

   g_atrHandle = iATR(
      symbol,
      timeframe,
      ATR_PERIOD
   );

   if(g_atrHandle == INVALID_HANDLE)
   {
      PrintFormat(
         "Failed to create ATR14 handle. Error: %d",
         GetLastError()
      );

      ReleaseStrategyIndicators();
      return(false);
   }

   return(true);
}

#endif
