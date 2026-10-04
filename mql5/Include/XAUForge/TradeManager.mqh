#ifndef XAUFORGE_TRADE_MANAGER_MQH
#define XAUFORGE_TRADE_MANAGER_MQH

#include <XAUForge/StrategyEngine.mqh>

struct TradeExecutionSettings
{
   double maxSpreadPoints;
};

bool ValidateTradeExecutionSettings(
   const TradeExecutionSettings &settings
)
{
   if(
      MathIsValidNumber(settings.maxSpreadPoints) &&
      settings.maxSpreadPoints > 0.0
   )
   {
      return(true);
   }

   PrintFormat(
      "Invalid MaxSpreadPoints: %G. Value must be finite and greater than zero.",
      settings.maxSpreadPoints
   );

   return(false);
}

struct PreTradeMarketSnapshot
{
   string symbol;
   long timeMsc;
   double bid;
   double ask;
   double point;
};

enum SpreadGateStatus
{
   SPREAD_GATE_NOT_EVALUATED,
   SPREAD_GATE_ALLOWED,
   SPREAD_GATE_TOO_WIDE,
   SPREAD_GATE_INVALID_INPUT
};

struct SpreadGateResult
{
   bool allowed;
   SpreadGateStatus status;
   double observedSpreadPoints;
   double maxSpreadPoints;
};

void ResetPreTradeMarketSnapshot(
   PreTradeMarketSnapshot &snapshot
)
{
   snapshot.symbol = "";
   snapshot.timeMsc = 0;
   snapshot.bid = 0.0;
   snapshot.ask = 0.0;
   snapshot.point = 0.0;
}

void ResetSpreadGateResult(
   SpreadGateResult &result
)
{
   result.allowed = false;
   result.status = SPREAD_GATE_NOT_EVALUATED;
   result.observedSpreadPoints = 0.0;
   result.maxSpreadPoints = 0.0;
}

bool LoadPreTradeMarketSnapshot(
   const string symbol,
   PreTradeMarketSnapshot &snapshot
)
{
   ResetPreTradeMarketSnapshot(snapshot);

   if(StringLen(symbol) == 0)
   {
      Print(
         "Cannot load pre-trade market snapshot for an empty symbol."
      );

      return(false);
   }

   MqlTick tick = {};

   ResetLastError();

   if(!SymbolInfoTick(
      symbol,
      tick
   ))
   {
      PrintFormat(
         "Failed to obtain current tick for %s. Error: %d",
         symbol,
         GetLastError()
      );

      return(false);
   }

   double point = 0.0;

   ResetLastError();

   if(!SymbolInfoDouble(
      symbol,
      SYMBOL_POINT,
      point
   ))
   {
      PrintFormat(
         "Failed to obtain SYMBOL_POINT for %s. Error: %d",
         symbol,
         GetLastError()
      );

      return(false);
   }

   if(
      tick.time_msc <= 0 ||
      !MathIsValidNumber(tick.bid) ||
      !MathIsValidNumber(tick.ask) ||
      !MathIsValidNumber(point) ||
      tick.bid <= 0.0 ||
      tick.ask <= 0.0 ||
      tick.ask < tick.bid ||
      point <= 0.0
   )
   {
      PrintFormat(
         "Invalid pre-trade market data for %s | time_msc=%I64d | bid=%G | ask=%G | point=%G",
         symbol,
         tick.time_msc,
         tick.bid,
         tick.ask,
         point
      );

      return(false);
   }

   snapshot.symbol = symbol;
   snapshot.timeMsc = tick.time_msc;
   snapshot.bid = tick.bid;
   snapshot.ask = tick.ask;
   snapshot.point = point;

   return(true);
}

bool EvaluateSpreadGate(
   const TradeExecutionSettings &settings,
   const PreTradeMarketSnapshot &snapshot,
   SpreadGateResult &result
)
{
   ResetSpreadGateResult(result);

   if(!ValidateTradeExecutionSettings(settings))
   {
      result.status = SPREAD_GATE_INVALID_INPUT;
      return(false);
   }

   if(
      StringLen(snapshot.symbol) == 0 ||
      snapshot.timeMsc <= 0 ||
      !MathIsValidNumber(snapshot.bid) ||
      !MathIsValidNumber(snapshot.ask) ||
      !MathIsValidNumber(snapshot.point) ||
      snapshot.bid <= 0.0 ||
      snapshot.ask <= 0.0 ||
      snapshot.ask < snapshot.bid ||
      snapshot.point <= 0.0
   )
   {
      Print(
         "Cannot evaluate spread gate from an invalid market snapshot."
      );

      result.status = SPREAD_GATE_INVALID_INPUT;
      return(false);
   }

   const double spreadPoints =
      (snapshot.ask - snapshot.bid) /
      snapshot.point;

   if(
      !MathIsValidNumber(spreadPoints) ||
      spreadPoints < 0.0
   )
   {
      PrintFormat(
         "Spread gate produced an invalid spread: %G points.",
         spreadPoints
      );

      result.status = SPREAD_GATE_INVALID_INPUT;
      return(false);
   }

   result.observedSpreadPoints =
      spreadPoints;

   result.maxSpreadPoints =
      settings.maxSpreadPoints;

   if(
      spreadPoints >
      settings.maxSpreadPoints
   )
   {
      result.allowed = false;
      result.status = SPREAD_GATE_TOO_WIDE;

      return(true);
   }

   result.allowed = true;
   result.status = SPREAD_GATE_ALLOWED;

   return(true);
}

enum TradeModeGateStatus
{
   TRADE_MODE_GATE_NOT_EVALUATED,
   TRADE_MODE_GATE_ALLOWED,
   TRADE_MODE_GATE_TRADING_DISABLED,
   TRADE_MODE_GATE_CLOSE_ONLY,
   TRADE_MODE_GATE_DIRECTION_NOT_ALLOWED,
   TRADE_MODE_GATE_INVALID_INPUT
};

struct TradeModeGateResult
{
   bool allowed;
   TradeModeGateStatus status;
   SignalDirection direction;
   ENUM_SYMBOL_TRADE_MODE tradeMode;
};

void ResetTradeModeGateResult(
   TradeModeGateResult &result
)
{
   result.allowed = false;
   result.status = TRADE_MODE_GATE_NOT_EVALUATED;
   result.direction = SIGNAL_NONE;
   result.tradeMode = SYMBOL_TRADE_MODE_DISABLED;
}

bool LoadCurrentTradeMode(
   const string symbol,
   ENUM_SYMBOL_TRADE_MODE &tradeMode
)
{
   tradeMode = SYMBOL_TRADE_MODE_DISABLED;

   if(StringLen(symbol) == 0)
   {
      Print(
         "Cannot load current trade mode for an empty symbol."
      );

      return(false);
   }

   long tradeModeValue = 0;

   ResetLastError();

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_TRADE_MODE,
      tradeModeValue
   ))
   {
      PrintFormat(
         "Failed to obtain SYMBOL_TRADE_MODE for %s. Error: %d",
         symbol,
         GetLastError()
      );

      return(false);
   }

   const ENUM_SYMBOL_TRADE_MODE observedTradeMode =
      (ENUM_SYMBOL_TRADE_MODE)tradeModeValue;

   switch(observedTradeMode)
   {
      case SYMBOL_TRADE_MODE_DISABLED:
      case SYMBOL_TRADE_MODE_LONGONLY:
      case SYMBOL_TRADE_MODE_SHORTONLY:
      case SYMBOL_TRADE_MODE_CLOSEONLY:
      case SYMBOL_TRADE_MODE_FULL:
         tradeMode = observedTradeMode;
         return(true);

      default:
         PrintFormat(
            "Unsupported SYMBOL_TRADE_MODE value for %s: %d",
            symbol,
            (int)tradeModeValue
         );

         return(false);
   }
}

bool EvaluateTradeModeGate(
   const SignalDirection direction,
   const ENUM_SYMBOL_TRADE_MODE tradeMode,
   TradeModeGateResult &result
)
{
   ResetTradeModeGateResult(result);

   result.direction = direction;
   result.tradeMode = tradeMode;

   if(
      direction != SIGNAL_BUY &&
      direction != SIGNAL_SELL
   )
   {
      PrintFormat(
         "Cannot evaluate trade-mode gate for invalid signal direction: %s",
         EnumToString(direction)
      );

      result.status =
         TRADE_MODE_GATE_INVALID_INPUT;

      return(false);
   }

   switch(tradeMode)
   {
      case SYMBOL_TRADE_MODE_FULL:
         result.allowed = true;
         result.status = TRADE_MODE_GATE_ALLOWED;
         return(true);

      case SYMBOL_TRADE_MODE_LONGONLY:
         if(direction == SIGNAL_BUY)
         {
            result.allowed = true;
            result.status = TRADE_MODE_GATE_ALLOWED;
         }
         else
         {
            result.allowed = false;
            result.status =
               TRADE_MODE_GATE_DIRECTION_NOT_ALLOWED;
         }

         return(true);

      case SYMBOL_TRADE_MODE_SHORTONLY:
         if(direction == SIGNAL_SELL)
         {
            result.allowed = true;
            result.status = TRADE_MODE_GATE_ALLOWED;
         }
         else
         {
            result.allowed = false;
            result.status =
               TRADE_MODE_GATE_DIRECTION_NOT_ALLOWED;
         }

         return(true);

      case SYMBOL_TRADE_MODE_CLOSEONLY:
         result.allowed = false;
         result.status = TRADE_MODE_GATE_CLOSE_ONLY;
         return(true);

      case SYMBOL_TRADE_MODE_DISABLED:
         result.allowed = false;
         result.status =
            TRADE_MODE_GATE_TRADING_DISABLED;
         return(true);

      default:
         PrintFormat(
            "Cannot evaluate unsupported SYMBOL_TRADE_MODE value: %d",
            (int)tradeMode
         );

         result.status =
            TRADE_MODE_GATE_INVALID_INPUT;

         return(false);
   }
}

const long TRADE_SESSION_SECONDS_PER_DAY = 86400;
const long TRADE_SESSION_MAX_SECONDS     = 172800;

enum TradeSessionGateStatus
{
   TRADE_SESSION_GATE_NOT_EVALUATED,
   TRADE_SESSION_GATE_ALLOWED,
   TRADE_SESSION_GATE_OUTSIDE_SESSION,
   TRADE_SESSION_GATE_LOOKUP_FAILED,
   TRADE_SESSION_GATE_INVALID_SESSION_DATA,
   TRADE_SESSION_GATE_INVALID_INPUT
};

struct TradeSessionGateResult
{
   bool allowed;
   TradeSessionGateStatus status;

   ENUM_DAY_OF_WEEK observationDay;
   int observationSeconds;

   ENUM_DAY_OF_WEEK matchedSessionDay;
   int matchedSessionIndex;

   long matchedSessionFromSeconds;
   long matchedSessionToSeconds;
};

void ResetTradeSessionGateResult(
   TradeSessionGateResult &result
)
{
   result.allowed = false;
   result.status = TRADE_SESSION_GATE_NOT_EVALUATED;

   result.observationDay = SUNDAY;
   result.observationSeconds = 0;

   result.matchedSessionDay = SUNDAY;
   result.matchedSessionIndex = -1;

   result.matchedSessionFromSeconds = 0;
   result.matchedSessionToSeconds = 0;
}

bool IsTradeSessionWindowActive(
   const long observationOffsetSeconds,
   const datetime sessionFrom,
   const datetime sessionTo,
   bool &active
)
{
   active = false;

   const long fromSeconds =
      (long)sessionFrom;

   const long toSeconds =
      (long)sessionTo;

   if(
      observationOffsetSeconds < 0 ||
      observationOffsetSeconds >= TRADE_SESSION_MAX_SECONDS ||
      fromSeconds < 0 ||
      fromSeconds >= TRADE_SESSION_MAX_SECONDS ||
      toSeconds <= fromSeconds ||
      toSeconds > TRADE_SESSION_MAX_SECONDS
   )
   {
      return(false);
   }

   active =
      observationOffsetSeconds >= fromSeconds &&
      observationOffsetSeconds < toSeconds;

   return(true);
}

bool FindMatchingTradeSessionForDay(
   const string symbol,
   const ENUM_DAY_OF_WEEK sessionDay,
   const long observationOffsetSeconds,
   bool &matched,
   int &matchedSessionIndex,
   long &matchedFromSeconds,
   long &matchedToSeconds,
   TradeSessionGateStatus &failureStatus
)
{
   matched = false;
   matchedSessionIndex = -1;
   matchedFromSeconds = 0;
   matchedToSeconds = 0;
   failureStatus = TRADE_SESSION_GATE_NOT_EVALUATED;

   for(uint sessionIndex = 0; ; sessionIndex++)
   {
      datetime sessionFrom = 0;
      datetime sessionTo = 0;

      ResetLastError();

      if(!SymbolInfoSessionTrade(
         symbol,
         sessionDay,
         sessionIndex,
         sessionFrom,
         sessionTo
      ))
      {
         const int errorCode =
            GetLastError();

         if(
            errorCode == ERR_SUCCESS ||
            errorCode == ERR_MARKET_SESSION_INDEX
         )
         {
            return(true);
         }

         PrintFormat(
            "Failed to read trading session | symbol=%s | day=%s | session_index=%u | error=%d",
            symbol,
            EnumToString(sessionDay),
            sessionIndex,
            errorCode
         );

         failureStatus =
            TRADE_SESSION_GATE_LOOKUP_FAILED;

         return(false);
      }

      if(
         sessionFrom == 0 &&
         sessionTo == 0
      )
      {
         return(true);
      }

      bool active = false;

      if(!IsTradeSessionWindowActive(
         observationOffsetSeconds,
         sessionFrom,
         sessionTo,
         active
      ))
      {
         PrintFormat(
            "Invalid trading session data | symbol=%s | day=%s | session_index=%u | from=%I64d | to=%I64d",
            symbol,
            EnumToString(sessionDay),
            sessionIndex,
            (long)sessionFrom,
            (long)sessionTo
         );

         failureStatus =
            TRADE_SESSION_GATE_INVALID_SESSION_DATA;

         return(false);
      }

      if(!active)
         continue;

      matched = true;
      matchedSessionIndex = (int)sessionIndex;
      matchedFromSeconds = (long)sessionFrom;
      matchedToSeconds = (long)sessionTo;

      return(true);
   }

   Print(
      "Trading-session lookup exited unexpectedly."
   );

   failureStatus =
      TRADE_SESSION_GATE_LOOKUP_FAILED;

   return(false);
}

bool EvaluateTradeSessionGate(
   const string symbol,
   const datetime brokerTime,
   TradeSessionGateResult &result
)
{
   ResetTradeSessionGateResult(result);

   if(
      StringLen(symbol) == 0 ||
      brokerTime <= 0
   )
   {
      Print(
         "Cannot evaluate trading-session gate from invalid input."
      );

      result.status =
         TRADE_SESSION_GATE_INVALID_INPUT;

      return(false);
   }

   MqlDateTime brokerDateTime = {};

   ResetLastError();

   if(!TimeToStruct(
      brokerTime,
      brokerDateTime
   ))
   {
      PrintFormat(
         "Failed to convert broker time for trading-session evaluation. Error: %d",
         GetLastError()
      );

      result.status =
         TRADE_SESSION_GATE_INVALID_INPUT;

      return(false);
   }

   if(
      brokerDateTime.day_of_week < SUNDAY ||
      brokerDateTime.day_of_week > SATURDAY
   )
   {
      PrintFormat(
         "Invalid broker day-of-week for trading-session evaluation: %d",
         brokerDateTime.day_of_week
      );

      result.status =
         TRADE_SESSION_GATE_INVALID_INPUT;

      return(false);
   }

   const ENUM_DAY_OF_WEEK currentDay =
      (ENUM_DAY_OF_WEEK)brokerDateTime.day_of_week;

   const int observationSeconds =
      brokerDateTime.hour * 3600 +
      brokerDateTime.min * 60 +
      brokerDateTime.sec;

   result.observationDay =
      currentDay;

   result.observationSeconds =
      observationSeconds;

   bool matched = false;
   int matchedSessionIndex = -1;
   long matchedFromSeconds = 0;
   long matchedToSeconds = 0;

   TradeSessionGateStatus failureStatus =
      TRADE_SESSION_GATE_NOT_EVALUATED;

   if(!FindMatchingTradeSessionForDay(
      symbol,
      currentDay,
      observationSeconds,
      matched,
      matchedSessionIndex,
      matchedFromSeconds,
      matchedToSeconds,
      failureStatus
   ))
   {
      result.status =
         failureStatus;

      return(false);
   }

   if(matched)
   {
      result.allowed = true;
      result.status =
         TRADE_SESSION_GATE_ALLOWED;

      result.matchedSessionDay =
         currentDay;

      result.matchedSessionIndex =
         matchedSessionIndex;

      result.matchedSessionFromSeconds =
         matchedFromSeconds;

      result.matchedSessionToSeconds =
         matchedToSeconds;

      return(true);
   }

   const ENUM_DAY_OF_WEEK previousDay =
      (ENUM_DAY_OF_WEEK)(
         (brokerDateTime.day_of_week + 6) % 7
      );

   const long previousDayObservationSeconds =
      TRADE_SESSION_SECONDS_PER_DAY +
      observationSeconds;

   if(!FindMatchingTradeSessionForDay(
      symbol,
      previousDay,
      previousDayObservationSeconds,
      matched,
      matchedSessionIndex,
      matchedFromSeconds,
      matchedToSeconds,
      failureStatus
   ))
   {
      result.status =
         failureStatus;

      return(false);
   }

   if(matched)
   {
      result.allowed = true;
      result.status =
         TRADE_SESSION_GATE_ALLOWED;

      result.matchedSessionDay =
         previousDay;

      result.matchedSessionIndex =
         matchedSessionIndex;

      result.matchedSessionFromSeconds =
         matchedFromSeconds;

      result.matchedSessionToSeconds =
         matchedToSeconds;

      return(true);
   }

   result.allowed = false;
   result.status =
      TRADE_SESSION_GATE_OUTSIDE_SESSION;

   return(true);
}

#endif
