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

struct CompletedStrategyData
{
   double fastEmaShift2;
   double fastEmaShift1;
   double slowEmaShift2;
   double slowEmaShift1;
   double atrShift1;
};

bool IsValidIndicatorValue(const double value)
{
   return(value != EMPTY_VALUE && MathIsValidNumber(value));
}

bool IsStrategyDataReady(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe
)
{
   if(
      g_fastEmaHandle == INVALID_HANDLE ||
      g_slowEmaHandle == INVALID_HANDLE ||
      g_atrHandle == INVALID_HANDLE
   )
   {
      return(false);
   }

   long synchronized = 0;

   ResetLastError();

   if(
      !SeriesInfoInteger(
         symbol,
         timeframe,
         SERIES_SYNCHRONIZED,
         synchronized
      )
   )
   {
      PrintFormat(
         "Failed to query strategy series synchronization. Error: %d",
         GetLastError()
      );

      return(false);
   }

   if(synchronized == 0)
   {
      PrintFormat(
         "Strategy data not ready: %s %s series is not synchronized.",
         symbol,
         EnumToString(timeframe)
      );

      return(false);
   }

   long barsCount = 0;

   ResetLastError();

   if(
      !SeriesInfoInteger(
         symbol,
         timeframe,
         SERIES_BARS_COUNT,
         barsCount
      )
   )
   {
      return(false);
   }

   const int requiredBars = SLOW_EMA_PERIOD + 2;

   if(barsCount < requiredBars)
      return(false);

   if(BarsCalculated(g_fastEmaHandle) < requiredBars)
      return(false);

   if(BarsCalculated(g_slowEmaHandle) < requiredBars)
      return(false);

   if(BarsCalculated(g_atrHandle) < requiredBars)
      return(false);

   return(true);
}

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

bool ReadCompletedStrategyData(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   CompletedStrategyData &data
)
{
   if(!IsStrategyDataReady(symbol, timeframe))
      return(false);

   double fastEmaValues[2];
   double slowEmaValues[2];
   double atrValues[1];

   ResetLastError();

   if(CopyBuffer(g_fastEmaHandle, 0, 1, 2, fastEmaValues) != 2)
   {
      PrintFormat(
         "Failed to copy EMA20 completed values. Error: %d",
         GetLastError()
      );

      return(false);
   }

   ResetLastError();

   if(CopyBuffer(g_slowEmaHandle, 0, 1, 2, slowEmaValues) != 2)
   {
      PrintFormat(
         "Failed to copy EMA50 completed values. Error: %d",
         GetLastError()
      );

      return(false);
   }

   ResetLastError();

   if(CopyBuffer(g_atrHandle, 0, 1, 1, atrValues) != 1)
   {
      PrintFormat(
         "Failed to copy ATR14 completed value. Error: %d",
         GetLastError()
      );

      return(false);
   }

   if(
      !IsValidIndicatorValue(fastEmaValues[0]) ||
      !IsValidIndicatorValue(fastEmaValues[1]) ||
      !IsValidIndicatorValue(slowEmaValues[0]) ||
      !IsValidIndicatorValue(slowEmaValues[1]) ||
      !IsValidIndicatorValue(atrValues[0])
   )
   {
      return(false);
   }

   // CopyBuffer places the oldest requested element first.
   data.fastEmaShift2 = fastEmaValues[0];
   data.fastEmaShift1 = fastEmaValues[1];
   data.slowEmaShift2 = slowEmaValues[0];
   data.slowEmaShift1 = slowEmaValues[1];
   data.atrShift1     = atrValues[0];

   return(true);
}

SignalDirection EvaluateSignal(
   const CompletedStrategyData &data
)
{
   if(
      data.fastEmaShift2 <= data.slowEmaShift2 &&
      data.fastEmaShift1 > data.slowEmaShift1
   )
   {
      return(SIGNAL_BUY);
   }

   if(
      data.fastEmaShift2 >= data.slowEmaShift2 &&
      data.fastEmaShift1 < data.slowEmaShift1
   )
   {
      return(SIGNAL_SELL);
   }

   return(SIGNAL_NONE);
}

#endif
