#ifndef XAUFORGE_TRADE_MANAGER_MQH
#define XAUFORGE_TRADE_MANAGER_MQH

#include <XAUForge/StrategyEngine.mqh>
#include <XAUForge/RiskManager.mqh>

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

struct TradeDistanceConstraints
{
   int digits;
   double point;
   double tickSize;
   int stopsLevelPoints;
   int freezeLevelPoints;
};

void ResetTradeDistanceConstraints(
   TradeDistanceConstraints &constraints
)
{
   constraints.digits = 0;
   constraints.point = 0.0;
   constraints.tickSize = 0.0;
   constraints.stopsLevelPoints = 0;
   constraints.freezeLevelPoints = 0;
}

bool LoadCurrentTradeDistanceConstraints(
   const string symbol,
   TradeDistanceConstraints &constraints
)
{
   ResetTradeDistanceConstraints(constraints);

   if(StringLen(symbol) == 0)
   {
      Print(
         "Cannot load trade-distance constraints for an empty symbol."
      );

      return(false);
   }

   long digits = 0;
   double point = 0.0;
   double tickSize = 0.0;
   long stopsLevel = 0;
   long freezeLevel = 0;

   ResetLastError();

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_DIGITS,
      digits
   ))
   {
      PrintFormat(
         "Failed to obtain SYMBOL_DIGITS for %s. Error: %d",
         symbol,
         GetLastError()
      );

      return(false);
   }

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

   ResetLastError();

   if(!SymbolInfoDouble(
      symbol,
      SYMBOL_TRADE_TICK_SIZE,
      tickSize
   ))
   {
      PrintFormat(
         "Failed to obtain SYMBOL_TRADE_TICK_SIZE for %s. Error: %d",
         symbol,
         GetLastError()
      );

      return(false);
   }

   ResetLastError();

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_TRADE_STOPS_LEVEL,
      stopsLevel
   ))
   {
      PrintFormat(
         "Failed to obtain SYMBOL_TRADE_STOPS_LEVEL for %s. Error: %d",
         symbol,
         GetLastError()
      );

      return(false);
   }

   ResetLastError();

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_TRADE_FREEZE_LEVEL,
      freezeLevel
   ))
   {
      PrintFormat(
         "Failed to obtain SYMBOL_TRADE_FREEZE_LEVEL for %s. Error: %d",
         symbol,
         GetLastError()
      );

      return(false);
   }

   if(
      digits < 0 ||
      digits > 8 ||
      !MathIsValidNumber(point) ||
      !MathIsValidNumber(tickSize) ||
      point <= 0.0 ||
      tickSize <= 0.0 ||
      stopsLevel < 0 ||
      stopsLevel > INT_MAX ||
      freezeLevel < 0 ||
      freezeLevel > INT_MAX
   )
   {
      PrintFormat(
         "Invalid trade-distance constraints | symbol=%s | digits=%I64d | point=%G | tick_size=%G | stops_level=%I64d | freeze_level=%I64d",
         symbol,
         digits,
         point,
         tickSize,
         stopsLevel,
         freezeLevel
      );

      return(false);
   }

   constraints.digits = (int)digits;
   constraints.point = point;
   constraints.tickSize = tickSize;
   constraints.stopsLevelPoints = (int)stopsLevel;
   constraints.freezeLevelPoints = (int)freezeLevel;

   return(true);
}

double CalculatePriceComparisonTolerance(
   const double firstPrice,
   const double secondPrice
)
{
   const double scale =
      MathMax(
         1.0,
         MathMax(
            MathAbs(firstPrice),
            MathAbs(secondPrice)
         )
      );

   return(
      DBL_EPSILON *
      64.0 *
      scale
   );
}

double SnapTickStepIfNearlyInteger(
   const double rawSteps
)
{
   const double nearestInteger =
      MathRound(rawSteps);

   const double tolerance =
      DBL_EPSILON *
      64.0 *
      MathMax(
         1.0,
         MathAbs(rawSteps)
      );

   if(
      MathAbs(
         rawSteps -
         nearestInteger
      ) <=
      tolerance
   )
   {
      return(nearestInteger);
   }

   return(rawSteps);
}

bool NormalizePriceDownToTick(
   const double price,
   const TradeDistanceConstraints &constraints,
   double &normalizedPrice
)
{
   normalizedPrice = 0.0;

   if(
      !MathIsValidNumber(price) ||
      price <= 0.0 ||
      constraints.digits < 0 ||
      constraints.digits > 8 ||
      !MathIsValidNumber(constraints.tickSize) ||
      constraints.tickSize <= 0.0
   )
   {
      return(false);
   }

   const double rawSteps =
      price / constraints.tickSize;

   if(!MathIsValidNumber(rawSteps))
      return(false);

   const double directionalSteps =
      SnapTickStepIfNearlyInteger(
         rawSteps
      );

   const double tickSteps =
      MathFloor(directionalSteps);

   const double candidatePrice =
      NormalizeDouble(
         tickSteps * constraints.tickSize,
         constraints.digits
      );

   if(
      !MathIsValidNumber(candidatePrice) ||
      candidatePrice <= 0.0
   )
   {
      return(false);
   }

   const double tolerance =
      CalculatePriceComparisonTolerance(
         candidatePrice,
         price
      );

   if(candidatePrice > price + tolerance)
      return(false);

   normalizedPrice = candidatePrice;

   return(true);
}

bool NormalizePriceUpToTick(
   const double price,
   const TradeDistanceConstraints &constraints,
   double &normalizedPrice
)
{
   normalizedPrice = 0.0;

   if(
      !MathIsValidNumber(price) ||
      price <= 0.0 ||
      constraints.digits < 0 ||
      constraints.digits > 8 ||
      !MathIsValidNumber(constraints.tickSize) ||
      constraints.tickSize <= 0.0
   )
   {
      return(false);
   }

   const double rawSteps =
      price / constraints.tickSize;

   if(!MathIsValidNumber(rawSteps))
      return(false);

   const double directionalSteps =
      SnapTickStepIfNearlyInteger(
         rawSteps
      );

   const double tickSteps =
      MathCeil(directionalSteps);

   const double candidatePrice =
      NormalizeDouble(
         tickSteps * constraints.tickSize,
         constraints.digits
      );

   if(
      !MathIsValidNumber(candidatePrice) ||
      candidatePrice <= 0.0
   )
   {
      return(false);
   }

   const double tolerance =
      CalculatePriceComparisonTolerance(
         candidatePrice,
         price
      );

   if(candidatePrice < price - tolerance)
      return(false);

   normalizedPrice = candidatePrice;

   return(true);
}

bool ValidateRiskTradePlanForExecutionGeometry(
   const RiskTradePlan &riskPlan,
   const double riskRewardRatio
)
{
   if(
      (riskPlan.direction != SIGNAL_BUY &&
       riskPlan.direction != SIGNAL_SELL) ||
      !MathIsValidNumber(riskPlan.entryPrice) ||
      !MathIsValidNumber(riskPlan.stopLossPrice) ||
      !MathIsValidNumber(riskPlan.takeProfitPrice) ||
      !MathIsValidNumber(riskPlan.stopDistance) ||
      !MathIsValidNumber(riskRewardRatio) ||
      riskPlan.entryPrice <= 0.0 ||
      riskPlan.stopLossPrice <= 0.0 ||
      riskPlan.takeProfitPrice <= 0.0 ||
      riskPlan.stopDistance <= 0.0 ||
      riskRewardRatio <= 0.0
   )
   {
      return(false);
   }

   if(
      riskPlan.direction == SIGNAL_BUY &&
      (
         riskPlan.stopLossPrice >= riskPlan.entryPrice ||
         riskPlan.takeProfitPrice <= riskPlan.entryPrice
      )
   )
   {
      return(false);
   }

   if(
      riskPlan.direction == SIGNAL_SELL &&
      (
         riskPlan.stopLossPrice <= riskPlan.entryPrice ||
         riskPlan.takeProfitPrice >= riskPlan.entryPrice
      )
   )
   {
      return(false);
   }

   const double plannedStopDistance =
      MathAbs(
         riskPlan.entryPrice -
         riskPlan.stopLossPrice
      );

   const double stopDistanceTolerance =
      CalculatePriceComparisonTolerance(
         plannedStopDistance,
         riskPlan.stopDistance
      );

   if(
      MathAbs(
         plannedStopDistance -
         riskPlan.stopDistance
      ) >
      stopDistanceTolerance
   )
   {
      return(false);
   }

   const double plannedTakeProfitDistance =
      MathAbs(
         riskPlan.takeProfitPrice -
         riskPlan.entryPrice
      );

   const double expectedTakeProfitDistance =
      riskPlan.stopDistance *
      riskRewardRatio;

   if(
      !MathIsValidNumber(expectedTakeProfitDistance) ||
      expectedTakeProfitDistance <= 0.0
   )
   {
      return(false);
   }

   const double takeProfitTolerance =
      CalculatePriceComparisonTolerance(
         plannedTakeProfitDistance,
         expectedTakeProfitDistance
      );

   return(
      MathAbs(
         plannedTakeProfitDistance -
         expectedTakeProfitDistance
      ) <=
      takeProfitTolerance
   );
}

enum TradeGeometryStatus
{
   TRADE_GEOMETRY_NOT_EVALUATED,
   TRADE_GEOMETRY_VALID,
   TRADE_GEOMETRY_INVALID_INPUT,
   TRADE_GEOMETRY_NORMALIZATION_FAILED,
   TRADE_GEOMETRY_STOPS_LEVEL_VIOLATION
};

struct FinalTradeGeometry
{
   bool valid;
   TradeGeometryStatus status;

   SignalDirection direction;

   double entryPrice;
   double stopLossPrice;
   double takeProfitPrice;

   double originalStopDistance;
   double finalStopDistance;

   bool stopDistanceChanged;
};

void ResetFinalTradeGeometry(
   FinalTradeGeometry &geometry
)
{
   geometry.valid = false;
   geometry.status = TRADE_GEOMETRY_NOT_EVALUATED;

   geometry.direction = SIGNAL_NONE;

   geometry.entryPrice = 0.0;
   geometry.stopLossPrice = 0.0;
   geometry.takeProfitPrice = 0.0;

   geometry.originalStopDistance = 0.0;
   geometry.finalStopDistance = 0.0;

   geometry.stopDistanceChanged = false;
}

bool BuildFinalTradeGeometry(
   const RiskTradePlan &riskPlan,
   const double riskRewardRatio,
   const PreTradeMarketSnapshot &snapshot,
   const TradeDistanceConstraints &constraints,
   FinalTradeGeometry &geometry
)
{
   ResetFinalTradeGeometry(geometry);

   if(
      !ValidateRiskTradePlanForExecutionGeometry(
         riskPlan,
         riskRewardRatio
      ) ||
      StringLen(snapshot.symbol) == 0 ||
      snapshot.timeMsc <= 0 ||
      !MathIsValidNumber(snapshot.bid) ||
      !MathIsValidNumber(snapshot.ask) ||
      !MathIsValidNumber(snapshot.point) ||
      snapshot.bid <= 0.0 ||
      snapshot.ask <= 0.0 ||
      snapshot.ask < snapshot.bid ||
      snapshot.point <= 0.0 ||
      constraints.digits < 0 ||
      constraints.digits > 8 ||
      !MathIsValidNumber(constraints.point) ||
      !MathIsValidNumber(constraints.tickSize) ||
      constraints.point <= 0.0 ||
      constraints.tickSize <= 0.0 ||
      constraints.stopsLevelPoints < 0 ||
      constraints.freezeLevelPoints < 0
   )
   {
      Print(
         "Cannot build final trade geometry from invalid input."
      );

      geometry.status =
         TRADE_GEOMETRY_INVALID_INPUT;

      return(false);
   }

   const double pointTolerance =
      CalculatePriceComparisonTolerance(
         snapshot.point,
         constraints.point
      );

   if(
      MathAbs(
         snapshot.point -
         constraints.point
      ) >
      pointTolerance
   )
   {
      PrintFormat(
         "Pre-trade point mismatch | snapshot_point=%G | constraint_point=%G",
         snapshot.point,
         constraints.point
      );

      geometry.status =
         TRADE_GEOMETRY_INVALID_INPUT;

      return(false);
   }

   const double minimumStopDistance =
      constraints.stopsLevelPoints *
      constraints.point;

   if(
      !MathIsValidNumber(minimumStopDistance) ||
      minimumStopDistance < 0.0
   )
   {
      geometry.status =
         TRADE_GEOMETRY_INVALID_INPUT;

      return(false);
   }

   geometry.direction =
      riskPlan.direction;

   geometry.entryPrice =
      (riskPlan.direction == SIGNAL_BUY)
      ? snapshot.ask
      : snapshot.bid;

   geometry.originalStopDistance =
      riskPlan.stopDistance;

   double rawStopLoss = 0.0;
   double stopLossBound = 0.0;
   double stopLossCandidate = 0.0;
   double normalizedStopLoss = 0.0;

   if(riskPlan.direction == SIGNAL_BUY)
   {
      rawStopLoss =
         geometry.entryPrice -
         riskPlan.stopDistance;

      stopLossBound =
         snapshot.bid -
         minimumStopDistance;

      stopLossCandidate =
         MathMin(
            rawStopLoss,
            stopLossBound
         );

      if(!NormalizePriceDownToTick(
         stopLossCandidate,
         constraints,
         normalizedStopLoss
      ))
      {
         geometry.status =
            TRADE_GEOMETRY_NORMALIZATION_FAILED;

         return(false);
      }
   }
   else
   {
      rawStopLoss =
         geometry.entryPrice +
         riskPlan.stopDistance;

      stopLossBound =
         snapshot.ask +
         minimumStopDistance;

      stopLossCandidate =
         MathMax(
            rawStopLoss,
            stopLossBound
         );

      if(!NormalizePriceUpToTick(
         stopLossCandidate,
         constraints,
         normalizedStopLoss
      ))
      {
         geometry.status =
            TRADE_GEOMETRY_NORMALIZATION_FAILED;

         return(false);
      }
   }

   geometry.stopLossPrice =
      normalizedStopLoss;

   geometry.finalStopDistance =
      MathAbs(
         geometry.entryPrice -
         geometry.stopLossPrice
      );

   if(
      !MathIsValidNumber(geometry.finalStopDistance) ||
      geometry.finalStopDistance <= 0.0
   )
   {
      geometry.status =
         TRADE_GEOMETRY_INVALID_INPUT;

      return(false);
   }

   const double stopDistanceTolerance =
      CalculatePriceComparisonTolerance(
         geometry.finalStopDistance,
         geometry.originalStopDistance
      );

   geometry.stopDistanceChanged =
      MathAbs(
         geometry.finalStopDistance -
         geometry.originalStopDistance
      ) >
      stopDistanceTolerance;

   const double targetTakeProfitDistance =
      geometry.finalStopDistance *
      riskRewardRatio;

   if(
      !MathIsValidNumber(targetTakeProfitDistance) ||
      targetTakeProfitDistance <= 0.0
   )
   {
      geometry.status =
         TRADE_GEOMETRY_INVALID_INPUT;

      return(false);
   }

   double rawTakeProfit = 0.0;
   double normalizedTakeProfit = 0.0;

   if(riskPlan.direction == SIGNAL_BUY)
   {
      rawTakeProfit =
         geometry.entryPrice +
         targetTakeProfitDistance;

      if(!NormalizePriceUpToTick(
         rawTakeProfit,
         constraints,
         normalizedTakeProfit
      ))
      {
         geometry.status =
            TRADE_GEOMETRY_NORMALIZATION_FAILED;

         return(false);
      }
   }
   else
   {
      rawTakeProfit =
         geometry.entryPrice -
         targetTakeProfitDistance;

      if(!NormalizePriceDownToTick(
         rawTakeProfit,
         constraints,
         normalizedTakeProfit
      ))
      {
         geometry.status =
            TRADE_GEOMETRY_NORMALIZATION_FAILED;

         return(false);
      }
   }

   geometry.takeProfitPrice =
      normalizedTakeProfit;

   const double stopLossTolerance =
      CalculatePriceComparisonTolerance(
         geometry.stopLossPrice,
         (
            riskPlan.direction == SIGNAL_BUY
            ? snapshot.bid
            : snapshot.ask
         )
      );

   const double takeProfitTolerance =
      CalculatePriceComparisonTolerance(
         geometry.takeProfitPrice,
         (
            riskPlan.direction == SIGNAL_BUY
            ? snapshot.bid
            : snapshot.ask
         )
      );

   if(riskPlan.direction == SIGNAL_BUY)
   {
      const double stopLossDistanceFromBid =
         snapshot.bid -
         geometry.stopLossPrice;

      const double takeProfitDistanceFromBid =
         geometry.takeProfitPrice -
         snapshot.bid;

      if(
         geometry.stopLossPrice >= snapshot.bid ||
         geometry.takeProfitPrice <= snapshot.bid ||
         stopLossDistanceFromBid +
            stopLossTolerance <
            minimumStopDistance ||
         takeProfitDistanceFromBid +
            takeProfitTolerance <
            minimumStopDistance
      )
      {
         Print(
            "Final BUY geometry violates current stop-distance constraints."
         );

         geometry.status =
            TRADE_GEOMETRY_STOPS_LEVEL_VIOLATION;

         return(false);
      }
   }
   else
   {
      const double stopLossDistanceFromAsk =
         geometry.stopLossPrice -
         snapshot.ask;

      const double takeProfitDistanceFromAsk =
         snapshot.ask -
         geometry.takeProfitPrice;

      if(
         geometry.stopLossPrice <= snapshot.ask ||
         geometry.takeProfitPrice >= snapshot.ask ||
         stopLossDistanceFromAsk +
            stopLossTolerance <
            minimumStopDistance ||
         takeProfitDistanceFromAsk +
            takeProfitTolerance <
            minimumStopDistance
      )
      {
         Print(
            "Final SELL geometry violates current stop-distance constraints."
         );

         geometry.status =
            TRADE_GEOMETRY_STOPS_LEVEL_VIOLATION;

         return(false);
      }
   }

   geometry.valid = true;
   geometry.status = TRADE_GEOMETRY_VALID;

   return(true);
}

enum FinalRiskSizingStatus
{
   FINAL_RISK_SIZING_NOT_EVALUATED,
   FINAL_RISK_SIZING_VALID,
   FINAL_RISK_SIZING_INVALID_INPUT,
   FINAL_RISK_SIZING_RAW_CALCULATION_FAILED,
   FINAL_RISK_SIZING_NORMALIZATION_FAILED
};

struct FinalRiskSizingResult
{
   bool valid;
   FinalRiskSizingStatus status;

   RiskSizingResult sizing;
   double normalizedVolume;
};

void ResetFinalRiskSizingResult(
   FinalRiskSizingResult &result
)
{
   result.valid = false;
   result.status =
      FINAL_RISK_SIZING_NOT_EVALUATED;

   result.sizing.equity = 0.0;
   result.sizing.plannedRiskAmount = 0.0;
   result.sizing.referenceVolume = 0.0;
   result.sizing.lossForReferenceVolume = 0.0;
   result.sizing.rawVolume = 0.0;

   result.normalizedVolume = 0.0;
}

bool ValidateFinalTradeGeometryForRiskSizing(
   const FinalTradeGeometry &geometry
)
{
   if(
      !geometry.valid ||
      geometry.status != TRADE_GEOMETRY_VALID ||
      (
         geometry.direction != SIGNAL_BUY &&
         geometry.direction != SIGNAL_SELL
      ) ||
      !MathIsValidNumber(geometry.entryPrice) ||
      !MathIsValidNumber(geometry.stopLossPrice) ||
      !MathIsValidNumber(geometry.takeProfitPrice) ||
      !MathIsValidNumber(geometry.finalStopDistance) ||
      geometry.entryPrice <= 0.0 ||
      geometry.stopLossPrice <= 0.0 ||
      geometry.takeProfitPrice <= 0.0 ||
      geometry.finalStopDistance <= 0.0
   )
   {
      return(false);
   }

   if(
      geometry.direction == SIGNAL_BUY &&
      (
         geometry.stopLossPrice >=
            geometry.entryPrice ||
         geometry.takeProfitPrice <=
            geometry.entryPrice
      )
   )
   {
      return(false);
   }

   if(
      geometry.direction == SIGNAL_SELL &&
      (
         geometry.stopLossPrice <=
            geometry.entryPrice ||
         geometry.takeProfitPrice >=
            geometry.entryPrice
      )
   )
   {
      return(false);
   }

   const double observedStopDistance =
      MathAbs(
         geometry.entryPrice -
         geometry.stopLossPrice
      );

   if(
      !MathIsValidNumber(observedStopDistance) ||
      observedStopDistance <= 0.0
   )
   {
      return(false);
   }

   const double stopDistanceTolerance =
      CalculatePriceComparisonTolerance(
         observedStopDistance,
         geometry.finalStopDistance
      );

   if(
      MathAbs(
         observedStopDistance -
         geometry.finalStopDistance
      ) >
      stopDistanceTolerance
   )
   {
      return(false);
   }

   return(true);
}

bool CalculateFinalRiskSizing(
   const string symbol,
   const FinalTradeGeometry &geometry,
   const double equity,
   const double riskPercent,
   const double volumeMin,
   const double volumeMax,
   const double volumeStep,
   FinalRiskSizingResult &result
)
{
   ResetFinalRiskSizingResult(result);

   if(
      StringLen(symbol) == 0 ||
      !ValidateFinalTradeGeometryForRiskSizing(
         geometry
      )
   )
   {
      Print(
         "Cannot calculate final risk sizing from invalid input."
      );

      result.status =
         FINAL_RISK_SIZING_INVALID_INPUT;

      return(false);
   }

   RiskSizingResult sizingResult;

   if(!CalculateRawRiskVolume(
      symbol,
      geometry.direction,
      geometry.entryPrice,
      geometry.stopLossPrice,
      equity,
      riskPercent,
      volumeMin,
      sizingResult
   ))
   {
      Print(
         "Final raw risk-volume calculation failed."
      );

      result.status =
         FINAL_RISK_SIZING_RAW_CALCULATION_FAILED;

      return(false);
   }

   double normalizedVolume = 0.0;

   if(!NormalizeRiskVolumeDown(
      sizingResult.rawVolume,
      volumeMin,
      volumeMax,
      volumeStep,
      normalizedVolume
   ))
   {
      Print(
         "Final risk-volume normalization failed."
      );

      result.status =
         FINAL_RISK_SIZING_NORMALIZATION_FAILED;

      return(false);
   }

   result.sizing =
      sizingResult;

   result.normalizedVolume =
      normalizedVolume;

   result.valid = true;
   result.status =
      FINAL_RISK_SIZING_VALID;

   return(true);
}

enum MarginValidationStatus
{
   MARGIN_VALIDATION_NOT_EVALUATED,
   MARGIN_VALIDATION_ALLOWED,
   MARGIN_VALIDATION_INSUFFICIENT_FREE_MARGIN,
   MARGIN_VALIDATION_INVALID_INPUT,
   MARGIN_VALIDATION_CALCULATION_FAILED,
   MARGIN_VALIDATION_ACCOUNT_STATE_FAILED
};

struct MarginValidationResult
{
   bool allowed;
   MarginValidationStatus status;

   double requiredMargin;
   double freeMargin;
   double remainingFreeMargin;
};

void ResetMarginValidationResult(
   MarginValidationResult &result
)
{
   result.allowed = false;
   result.status =
      MARGIN_VALIDATION_NOT_EVALUATED;

   result.requiredMargin = 0.0;
   result.freeMargin = 0.0;
   result.remainingFreeMargin = 0.0;
}

bool ValidateFinalRiskSizingForMargin(
   const FinalRiskSizingResult &riskSizing
)
{
   if(
      !riskSizing.valid ||
      riskSizing.status !=
         FINAL_RISK_SIZING_VALID ||
      !MathIsValidNumber(
         riskSizing.normalizedVolume
      ) ||
      !MathIsValidNumber(
         riskSizing.sizing.rawVolume
      ) ||
      riskSizing.normalizedVolume <= 0.0 ||
      riskSizing.sizing.rawVolume <= 0.0
   )
   {
      return(false);
   }

   const double volumeTolerance =
      DBL_EPSILON *
      MathMax(
         1.0,
         MathAbs(
            riskSizing.sizing.rawVolume
         )
      ) *
      16.0;

   if(
      riskSizing.normalizedVolume >
      riskSizing.sizing.rawVolume +
      volumeTolerance
   )
   {
      return(false);
   }

   return(true);
}

bool CalculateRequiredMargin(
   const string symbol,
   const FinalTradeGeometry &geometry,
   const FinalRiskSizingResult &riskSizing,
   double &requiredMargin
)
{
   requiredMargin = 0.0;

   if(
      StringLen(symbol) == 0 ||
      !ValidateFinalTradeGeometryForRiskSizing(
         geometry
      ) ||
      !ValidateFinalRiskSizingForMargin(
         riskSizing
      )
   )
   {
      Print(
         "Cannot calculate required margin from invalid input."
      );

      return(false);
   }

   const ENUM_ORDER_TYPE orderType =
      (geometry.direction == SIGNAL_BUY)
      ? ORDER_TYPE_BUY
      : ORDER_TYPE_SELL;

   ResetLastError();

   if(!OrderCalcMargin(
      orderType,
      symbol,
      riskSizing.normalizedVolume,
      geometry.entryPrice,
      requiredMargin
   ))
   {
      PrintFormat(
         "OrderCalcMargin failed. Error: %d",
         GetLastError()
      );

      requiredMargin = 0.0;

      return(false);
   }

   if(
      !MathIsValidNumber(requiredMargin) ||
      requiredMargin < 0.0
   )
   {
      PrintFormat(
         "OrderCalcMargin produced an invalid margin value: %G",
         requiredMargin
      );

      requiredMargin = 0.0;

      return(false);
   }

   return(true);
}

bool LoadCurrentFreeMargin(
   double &freeMargin
)
{
   freeMargin =
      AccountInfoDouble(
         ACCOUNT_MARGIN_FREE
      );

   if(!MathIsValidNumber(freeMargin))
   {
      PrintFormat(
         "Current account free margin is invalid: %G",
         freeMargin
      );

      freeMargin = 0.0;

      return(false);
   }

   return(true);
}

bool EvaluateMarginCapacity(
   const double requiredMargin,
   const double freeMargin,
   MarginValidationResult &result
)
{
   ResetMarginValidationResult(result);

   if(
      !MathIsValidNumber(requiredMargin) ||
      !MathIsValidNumber(freeMargin) ||
      requiredMargin < 0.0
   )
   {
      Print(
         "Cannot evaluate margin capacity from invalid input."
      );

      result.status =
         MARGIN_VALIDATION_INVALID_INPUT;

      return(false);
   }

   result.requiredMargin =
      requiredMargin;

   result.freeMargin =
      freeMargin;

   result.remainingFreeMargin =
      freeMargin -
      requiredMargin;

   if(requiredMargin > freeMargin)
   {
      result.allowed = false;
      result.status =
         MARGIN_VALIDATION_INSUFFICIENT_FREE_MARGIN;

      return(true);
   }

   result.allowed = true;
   result.status =
      MARGIN_VALIDATION_ALLOWED;

   return(true);
}

bool EvaluateCurrentMarginCapacity(
   const string symbol,
   const FinalTradeGeometry &geometry,
   const FinalRiskSizingResult &riskSizing,
   MarginValidationResult &result
)
{
   ResetMarginValidationResult(result);

   if(
      StringLen(symbol) == 0 ||
      !ValidateFinalTradeGeometryForRiskSizing(
         geometry
      ) ||
      !ValidateFinalRiskSizingForMargin(
         riskSizing
      )
   )
   {
      Print(
         "Cannot evaluate current margin capacity from invalid input."
      );

      result.status =
         MARGIN_VALIDATION_INVALID_INPUT;

      return(false);
   }

   double requiredMargin = 0.0;

   if(!CalculateRequiredMargin(
      symbol,
      geometry,
      riskSizing,
      requiredMargin
   ))
   {
      result.status =
         MARGIN_VALIDATION_CALCULATION_FAILED;

      return(false);
   }

   double freeMargin = 0.0;

   if(!LoadCurrentFreeMargin(
      freeMargin
   ))
   {
      result.status =
         MARGIN_VALIDATION_ACCOUNT_STATE_FAILED;

      return(false);
   }

   return(
      EvaluateMarginCapacity(
         requiredMargin,
         freeMargin,
         result
      )
   );
}

struct TradeRequestCapabilities
{
   bool valid;
   string symbol;

   ENUM_SYMBOL_TRADE_EXECUTION executionMode;

   long orderMode;
   long fillingMode;
};

void ResetTradeRequestCapabilities(
   TradeRequestCapabilities &capabilities
)
{
   capabilities.valid = false;
   capabilities.symbol = "";

   capabilities.executionMode =
      SYMBOL_TRADE_EXECUTION_REQUEST;

   capabilities.orderMode = 0;
   capabilities.fillingMode = 0;
}

bool HasCapabilityFlag(
   const long flags,
   const long capabilityFlag
)
{
   return(
      (flags & capabilityFlag) ==
      capabilityFlag
   );
}

bool LoadCurrentTradeRequestCapabilities(
   const string symbol,
   TradeRequestCapabilities &capabilities
)
{
   ResetTradeRequestCapabilities(
      capabilities
   );

   if(StringLen(symbol) == 0)
   {
      Print(
         "Cannot load trade-request capabilities for an empty symbol."
      );

      return(false);
   }

   long executionModeValue = 0;
   long orderMode = 0;
   long fillingMode = 0;

   ResetLastError();

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_TRADE_EXEMODE,
      executionModeValue
   ))
   {
      PrintFormat(
         "Failed to obtain SYMBOL_TRADE_EXEMODE for %s. Error: %d",
         symbol,
         GetLastError()
      );

      return(false);
   }

   const ENUM_SYMBOL_TRADE_EXECUTION executionMode =
      (ENUM_SYMBOL_TRADE_EXECUTION)
      executionModeValue;

   switch(executionMode)
   {
      case SYMBOL_TRADE_EXECUTION_REQUEST:
      case SYMBOL_TRADE_EXECUTION_INSTANT:
      case SYMBOL_TRADE_EXECUTION_MARKET:
      case SYMBOL_TRADE_EXECUTION_EXCHANGE:
         break;

      default:
         PrintFormat(
            "Unsupported trade execution mode for %s: %d",
            symbol,
            (int)executionModeValue
         );

         return(false);
   }

   ResetLastError();

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_ORDER_MODE,
      orderMode
   ))
   {
      PrintFormat(
         "Failed to obtain SYMBOL_ORDER_MODE for %s. Error: %d",
         symbol,
         GetLastError()
      );

      return(false);
   }

   ResetLastError();

   if(!SymbolInfoInteger(
      symbol,
      SYMBOL_FILLING_MODE,
      fillingMode
   ))
   {
      PrintFormat(
         "Failed to obtain SYMBOL_FILLING_MODE for %s. Error: %d",
         symbol,
         GetLastError()
      );

      return(false);
   }

   if(
      orderMode < 0 ||
      fillingMode < 0
   )
   {
      PrintFormat(
         "Invalid trade-request capabilities | symbol=%s | execution_mode=%s | order_mode=%I64d | filling_mode=%I64d",
         symbol,
         EnumToString(executionMode),
         orderMode,
         fillingMode
      );

      return(false);
   }

   capabilities.valid = true;
   capabilities.symbol = symbol;
   capabilities.executionMode =
      executionMode;
   capabilities.orderMode =
      orderMode;
   capabilities.fillingMode =
      fillingMode;

   return(true);
}

enum FillingPolicySelectionStatus
{
   FILLING_POLICY_NOT_EVALUATED,
   FILLING_POLICY_SELECTED_FOK,
   FILLING_POLICY_SELECTED_IOC,
   FILLING_POLICY_SELECTED_RETURN,
   FILLING_POLICY_NO_SUPPORTED_MODE,
   FILLING_POLICY_INVALID_INPUT
};

struct FillingPolicySelectionResult
{
   bool selected;
   FillingPolicySelectionStatus status;

   ENUM_ORDER_TYPE_FILLING fillingPolicy;
};

void ResetFillingPolicySelectionResult(
   FillingPolicySelectionResult &result
)
{
   result.selected = false;
   result.status =
      FILLING_POLICY_NOT_EVALUATED;

   result.fillingPolicy =
      ORDER_FILLING_FOK;
}

bool SelectSupportedMarketFillingPolicy(
   const TradeRequestCapabilities &capabilities,
   FillingPolicySelectionResult &result
)
{
   ResetFillingPolicySelectionResult(
      result
   );

   if(
      !capabilities.valid ||
      StringLen(capabilities.symbol) == 0 ||
      capabilities.orderMode < 0 ||
      capabilities.fillingMode < 0
   )
   {
      result.status =
         FILLING_POLICY_INVALID_INPUT;

      return(false);
   }

   switch(capabilities.executionMode)
   {
      case SYMBOL_TRADE_EXECUTION_REQUEST:
      case SYMBOL_TRADE_EXECUTION_INSTANT:
      {
         result.selected = true;
         result.status =
            FILLING_POLICY_SELECTED_FOK;
         result.fillingPolicy =
            ORDER_FILLING_FOK;

         return(true);
      }

      case SYMBOL_TRADE_EXECUTION_MARKET:
      {
         if(HasCapabilityFlag(
            capabilities.fillingMode,
            (long)SYMBOL_FILLING_FOK
         ))
         {
            result.selected = true;
            result.status =
               FILLING_POLICY_SELECTED_FOK;
            result.fillingPolicy =
               ORDER_FILLING_FOK;

            return(true);
         }

         if(HasCapabilityFlag(
            capabilities.fillingMode,
            (long)SYMBOL_FILLING_IOC
         ))
         {
            result.selected = true;
            result.status =
               FILLING_POLICY_SELECTED_IOC;
            result.fillingPolicy =
               ORDER_FILLING_IOC;

            return(true);
         }

         result.status =
            FILLING_POLICY_NO_SUPPORTED_MODE;

         return(false);
      }

      case SYMBOL_TRADE_EXECUTION_EXCHANGE:
      {
         if(HasCapabilityFlag(
            capabilities.fillingMode,
            (long)SYMBOL_FILLING_FOK
         ))
         {
            result.selected = true;
            result.status =
               FILLING_POLICY_SELECTED_FOK;
            result.fillingPolicy =
               ORDER_FILLING_FOK;

            return(true);
         }

         if(HasCapabilityFlag(
            capabilities.fillingMode,
            (long)SYMBOL_FILLING_IOC
         ))
         {
            result.selected = true;
            result.status =
               FILLING_POLICY_SELECTED_IOC;
            result.fillingPolicy =
               ORDER_FILLING_IOC;

            return(true);
         }

         result.selected = true;
         result.status =
            FILLING_POLICY_SELECTED_RETURN;
         result.fillingPolicy =
            ORDER_FILLING_RETURN;

         return(true);
      }

      default:
         result.status =
            FILLING_POLICY_INVALID_INPUT;

         return(false);
   }
}

enum MarketTradeRequestBuildStatus
{
   MARKET_REQUEST_BUILD_NOT_EVALUATED,
   MARKET_REQUEST_BUILD_VALID,
   MARKET_REQUEST_BUILD_INVALID_INPUT,
   MARKET_REQUEST_BUILD_MARKET_ORDER_UNSUPPORTED,
   MARKET_REQUEST_BUILD_STOP_LOSS_UNSUPPORTED,
   MARKET_REQUEST_BUILD_TAKE_PROFIT_UNSUPPORTED,
   MARKET_REQUEST_BUILD_FILLING_UNSUPPORTED
};

struct MarketTradeRequestBuildResult
{
   bool valid;
   MarketTradeRequestBuildStatus status;

   ENUM_ORDER_TYPE_FILLING fillingPolicy;

   MqlTradeRequest request;
};

void ResetMarketTradeRequestBuildResult(
   MarketTradeRequestBuildResult &result
)
{
   result.valid = false;
   result.status =
      MARKET_REQUEST_BUILD_NOT_EVALUATED;

   result.fillingPolicy =
      ORDER_FILLING_FOK;

   ZeroMemory(
      result.request
   );
}

bool BuildMarketTradeRequest(
   const string symbol,
   const FinalTradeGeometry &geometry,
   const FinalRiskSizingResult &riskSizing,
   const TradeRequestCapabilities &capabilities,
   const ulong magicNumber,
   const ulong deviationPoints,
   MarketTradeRequestBuildResult &result
)
{
   ResetMarketTradeRequestBuildResult(
      result
   );

   if(
      StringLen(symbol) == 0 ||
      !ValidateFinalTradeGeometryForRiskSizing(
         geometry
      ) ||
      !ValidateFinalRiskSizingForMargin(
         riskSizing
      ) ||
      !capabilities.valid ||
      capabilities.symbol != symbol
   )
   {
      Print(
         "Cannot build market trade request from invalid input."
      );

      result.status =
         MARKET_REQUEST_BUILD_INVALID_INPUT;

      return(false);
   }

   if(!HasCapabilityFlag(
      capabilities.orderMode,
      (long)SYMBOL_ORDER_MARKET
   ))
   {
      PrintFormat(
         "Market orders are not supported for %s.",
         symbol
      );

      result.status =
         MARKET_REQUEST_BUILD_MARKET_ORDER_UNSUPPORTED;

      return(false);
   }

   if(!HasCapabilityFlag(
      capabilities.orderMode,
      (long)SYMBOL_ORDER_SL
   ))
   {
      PrintFormat(
         "Stop Loss is not supported for %s.",
         symbol
      );

      result.status =
         MARKET_REQUEST_BUILD_STOP_LOSS_UNSUPPORTED;

      return(false);
   }

   if(!HasCapabilityFlag(
      capabilities.orderMode,
      (long)SYMBOL_ORDER_TP
   ))
   {
      PrintFormat(
         "Take Profit is not supported for %s.",
         symbol
      );

      result.status =
         MARKET_REQUEST_BUILD_TAKE_PROFIT_UNSUPPORTED;

      return(false);
   }

   FillingPolicySelectionResult fillingResult;

   if(!SelectSupportedMarketFillingPolicy(
      capabilities,
      fillingResult
   ))
   {
      PrintFormat(
         "No supported market filling policy for %s | execution_mode=%s | filling_mode=%I64d",
         symbol,
         EnumToString(
            capabilities.executionMode
         ),
         capabilities.fillingMode
      );

      result.status =
         MARKET_REQUEST_BUILD_FILLING_UNSUPPORTED;

      return(false);
   }

   MqlTradeRequest request = {};

   request.action =
      TRADE_ACTION_DEAL;

   request.magic =
      magicNumber;

   request.symbol =
      symbol;

   request.volume =
      riskSizing.normalizedVolume;

   request.sl =
      geometry.stopLossPrice;

   request.tp =
      geometry.takeProfitPrice;

   request.type =
      (geometry.direction == SIGNAL_BUY)
      ? ORDER_TYPE_BUY
      : ORDER_TYPE_SELL;

   request.type_filling =
      fillingResult.fillingPolicy;

   switch(capabilities.executionMode)
   {
      case SYMBOL_TRADE_EXECUTION_REQUEST:
      case SYMBOL_TRADE_EXECUTION_INSTANT:
         request.price =
            geometry.entryPrice;

         request.deviation =
            deviationPoints;

         break;

      case SYMBOL_TRADE_EXECUTION_MARKET:
      case SYMBOL_TRADE_EXECUTION_EXCHANGE:
         request.price = 0.0;
         request.deviation = 0;

         break;

      default:
         result.status =
            MARKET_REQUEST_BUILD_INVALID_INPUT;

         return(false);
   }

   result.request =
      request;

   result.fillingPolicy =
      fillingResult.fillingPolicy;

   result.valid = true;
   result.status =
      MARKET_REQUEST_BUILD_VALID;

   return(true);
}

enum TradeRequestCheckStatus
{
   TRADE_REQUEST_CHECK_NOT_EVALUATED,
   TRADE_REQUEST_CHECK_PASSED,
   TRADE_REQUEST_CHECK_REJECTED,
   TRADE_REQUEST_CHECK_INVALID_INPUT
};

struct TradeRequestCheckResult
{
   bool allowed;
   TradeRequestCheckStatus status;

   int lastError;

   MqlTradeCheckResult checkResult;
};

void ResetTradeRequestCheckResult(
   TradeRequestCheckResult &result
)
{
   result.allowed = false;
   result.status =
      TRADE_REQUEST_CHECK_NOT_EVALUATED;

   result.lastError = 0;

   ZeroMemory(
      result.checkResult
   );
}

bool EvaluateTradeRequestCheck(
   const MarketTradeRequestBuildResult &requestBuild,
   TradeRequestCheckResult &result
)
{
   ResetTradeRequestCheckResult(
      result
   );

   if(
      !requestBuild.valid ||
      requestBuild.status !=
         MARKET_REQUEST_BUILD_VALID
   )
   {
      Print(
         "Cannot evaluate OrderCheck from an invalid market trade request."
      );

      result.status =
         TRADE_REQUEST_CHECK_INVALID_INPUT;

      return(false);
   }

   MqlTradeRequest request =
      requestBuild.request;

   MqlTradeCheckResult checkResult = {};

   ResetLastError();

   const bool checkPassed =
      OrderCheck(
         request,
         checkResult
      );

   result.lastError =
      GetLastError();

   result.checkResult =
      checkResult;

   if(!checkPassed)
   {
      result.allowed = false;
      result.status =
         TRADE_REQUEST_CHECK_REJECTED;

      PrintFormat(
         "OrderCheck rejected request | last_error=%d | retcode=%u | comment=%s",
         result.lastError,
         result.checkResult.retcode,
         result.checkResult.comment
      );

      return(true);
   }

   result.allowed = true;
   result.status =
      TRADE_REQUEST_CHECK_PASSED;

   return(true);
}

struct TradeSubmissionPermissionSnapshot
{
   bool valid;

   bool testerMode;

   bool terminalConnected;
   bool terminalTradeAllowed;
   bool programTradeAllowed;

   bool accountTradeAllowed;
   bool accountExpertTradeAllowed;
};

enum TradeSubmissionPermissionStatus
{
   TRADE_SUBMISSION_PERMISSION_NOT_EVALUATED,
   TRADE_SUBMISSION_PERMISSION_ALLOWED,
   TRADE_SUBMISSION_PERMISSION_TERMINAL_DISCONNECTED,
   TRADE_SUBMISSION_PERMISSION_TERMINAL_TRADING_DISABLED,
   TRADE_SUBMISSION_PERMISSION_PROGRAM_TRADING_DISABLED,
   TRADE_SUBMISSION_PERMISSION_ACCOUNT_TRADING_DISABLED,
   TRADE_SUBMISSION_PERMISSION_ACCOUNT_EXPERT_TRADING_DISABLED,
   TRADE_SUBMISSION_PERMISSION_INVALID_INPUT
};

struct TradeSubmissionPermissionResult
{
   bool allowed;
   TradeSubmissionPermissionStatus status;
};

void ResetTradeSubmissionPermissionSnapshot(
   TradeSubmissionPermissionSnapshot &snapshot
)
{
   snapshot.valid = false;

   snapshot.testerMode = false;

   snapshot.terminalConnected = false;
   snapshot.terminalTradeAllowed = false;
   snapshot.programTradeAllowed = false;

   snapshot.accountTradeAllowed = false;
   snapshot.accountExpertTradeAllowed = false;
}

void ResetTradeSubmissionPermissionResult(
   TradeSubmissionPermissionResult &result
)
{
   result.allowed = false;
   result.status =
      TRADE_SUBMISSION_PERMISSION_NOT_EVALUATED;
}

bool LoadCurrentTradeSubmissionPermissions(
   TradeSubmissionPermissionSnapshot &snapshot
)
{
   ResetTradeSubmissionPermissionSnapshot(
      snapshot
   );

   snapshot.testerMode =
      (bool)MQLInfoInteger(
         MQL_TESTER
      );

   snapshot.terminalConnected =
      (bool)TerminalInfoInteger(
         TERMINAL_CONNECTED
      );

   snapshot.terminalTradeAllowed =
      (bool)TerminalInfoInteger(
         TERMINAL_TRADE_ALLOWED
      );

   snapshot.programTradeAllowed =
      (bool)MQLInfoInteger(
         MQL_TRADE_ALLOWED
      );

   snapshot.accountTradeAllowed =
      (bool)AccountInfoInteger(
         ACCOUNT_TRADE_ALLOWED
      );

   snapshot.accountExpertTradeAllowed =
      (bool)AccountInfoInteger(
         ACCOUNT_TRADE_EXPERT
      );

   snapshot.valid = true;

   return(true);
}

bool EvaluateTradeSubmissionPermissions(
   const TradeSubmissionPermissionSnapshot &snapshot,
   TradeSubmissionPermissionResult &result
)
{
   ResetTradeSubmissionPermissionResult(
      result
   );

   if(!snapshot.valid)
   {
      Print(
         "Cannot evaluate trade-submission permissions from an invalid snapshot."
      );

      result.status =
         TRADE_SUBMISSION_PERMISSION_INVALID_INPUT;

      return(false);
   }

   if(
      !snapshot.testerMode &&
      !snapshot.terminalConnected
   )
   {
      result.allowed = false;
      result.status =
         TRADE_SUBMISSION_PERMISSION_TERMINAL_DISCONNECTED;

      return(true);
   }

   if(!snapshot.terminalTradeAllowed)
   {
      result.allowed = false;
      result.status =
         TRADE_SUBMISSION_PERMISSION_TERMINAL_TRADING_DISABLED;

      return(true);
   }

   if(!snapshot.programTradeAllowed)
   {
      result.allowed = false;
      result.status =
         TRADE_SUBMISSION_PERMISSION_PROGRAM_TRADING_DISABLED;

      return(true);
   }

   if(!snapshot.accountTradeAllowed)
   {
      result.allowed = false;
      result.status =
         TRADE_SUBMISSION_PERMISSION_ACCOUNT_TRADING_DISABLED;

      return(true);
   }

   if(!snapshot.accountExpertTradeAllowed)
   {
      result.allowed = false;
      result.status =
         TRADE_SUBMISSION_PERMISSION_ACCOUNT_EXPERT_TRADING_DISABLED;

      return(true);
   }

   result.allowed = true;
   result.status =
      TRADE_SUBMISSION_PERMISSION_ALLOWED;

   return(true);
}

bool EvaluateCurrentTradeSubmissionPermissions(
   TradeSubmissionPermissionSnapshot &snapshot,
   TradeSubmissionPermissionResult &result
)
{
   ResetTradeSubmissionPermissionSnapshot(
      snapshot
   );

   ResetTradeSubmissionPermissionResult(
      result
   );

   if(!LoadCurrentTradeSubmissionPermissions(
      snapshot
   ))
   {
      return(false);
   }

   return(
      EvaluateTradeSubmissionPermissions(
         snapshot,
         result
      )
   );
}

#endif
