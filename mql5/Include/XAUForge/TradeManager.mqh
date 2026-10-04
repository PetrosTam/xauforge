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

#endif
