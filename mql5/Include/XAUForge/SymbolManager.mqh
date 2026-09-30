#ifndef XAUFORGE_SYMBOL_MANAGER_MQH
#define XAUFORGE_SYMBOL_MANAGER_MQH

enum AccountPositionMode
{
   ACCOUNT_POSITION_MODE_UNKNOWN,
   ACCOUNT_POSITION_MODE_NETTING,
   ACCOUNT_POSITION_MODE_HEDGING
};

struct SymbolCapabilities
{
   string symbol;

   int digits;
   double point;
   double tickSize;
   double tickValue;

   double volumeMin;
   double volumeMax;
   double volumeStep;

   int stopsLevel;
   int freezeLevel;

   ENUM_SYMBOL_TRADE_MODE tradeMode;
   int orderMode;

   ENUM_SYMBOL_TRADE_EXECUTION executionMode;
   int fillingMode;

   double contractSize;
   ENUM_SYMBOL_CALC_MODE calculationMode;
};

bool ReadSymbolIntegerProperty(
   const string symbol,
   const ENUM_SYMBOL_INFO_INTEGER property,
   const string propertyName,
   long &value
)
{
   ResetLastError();

   if(SymbolInfoInteger(symbol, property, value))
      return(true);

   PrintFormat(
      "Failed to read %s for %s. Error: %d",
      propertyName,
      symbol,
      GetLastError()
   );

   return(false);
}

bool ReadSymbolDoubleProperty(
   const string symbol,
   const ENUM_SYMBOL_INFO_DOUBLE property,
   const string propertyName,
   double &value
)
{
   ResetLastError();

   if(SymbolInfoDouble(symbol, property, value))
      return(true);

   PrintFormat(
      "Failed to read %s for %s. Error: %d",
      propertyName,
      symbol,
      GetLastError()
   );

   return(false);
}

bool IsPositiveFiniteSymbolValue(const double value)
{
   return(MathIsValidNumber(value) && value > 0.0);
}

bool ValidateSymbolCapabilities(
   const SymbolCapabilities &capabilities
)
{
   if(capabilities.symbol == "")
   {
      Print("Invalid symbol capabilities: symbol name is empty.");
      return(false);
   }

   if(capabilities.digits < 0)
   {
      PrintFormat(
         "Invalid SYMBOL_DIGITS for %s: %d",
         capabilities.symbol,
         capabilities.digits
      );

      return(false);
   }

   if(!IsPositiveFiniteSymbolValue(capabilities.point))
   {
      PrintFormat(
         "Invalid SYMBOL_POINT for %s: %G",
         capabilities.symbol,
         capabilities.point
      );

      return(false);
   }

   if(!IsPositiveFiniteSymbolValue(capabilities.tickSize))
   {
      PrintFormat(
         "Invalid SYMBOL_TRADE_TICK_SIZE for %s: %G",
         capabilities.symbol,
         capabilities.tickSize
      );

      return(false);
   }

   if(
      !MathIsValidNumber(capabilities.tickValue) ||
      capabilities.tickValue < 0.0
   )
   {
      PrintFormat(
         "Invalid SYMBOL_TRADE_TICK_VALUE for %s: %G",
         capabilities.symbol,
         capabilities.tickValue
      );

      return(false);
   }

   if(!IsPositiveFiniteSymbolValue(capabilities.volumeMin))
   {
      PrintFormat(
         "Invalid SYMBOL_VOLUME_MIN for %s: %G",
         capabilities.symbol,
         capabilities.volumeMin
      );

      return(false);
   }

   if(!IsPositiveFiniteSymbolValue(capabilities.volumeMax))
   {
      PrintFormat(
         "Invalid SYMBOL_VOLUME_MAX for %s: %G",
         capabilities.symbol,
         capabilities.volumeMax
      );

      return(false);
   }

   if(capabilities.volumeMax < capabilities.volumeMin)
   {
      PrintFormat(
         "Invalid volume range for %s: min=%G max=%G",
         capabilities.symbol,
         capabilities.volumeMin,
         capabilities.volumeMax
      );

      return(false);
   }

   if(!IsPositiveFiniteSymbolValue(capabilities.volumeStep))
   {
      PrintFormat(
         "Invalid SYMBOL_VOLUME_STEP for %s: %G",
         capabilities.symbol,
         capabilities.volumeStep
      );

      return(false);
   }

   if(capabilities.stopsLevel < 0)
   {
      PrintFormat(
         "Invalid SYMBOL_TRADE_STOPS_LEVEL for %s: %d",
         capabilities.symbol,
         capabilities.stopsLevel
      );

      return(false);
   }

   if(capabilities.freezeLevel < 0)
   {
      PrintFormat(
         "Invalid SYMBOL_TRADE_FREEZE_LEVEL for %s: %d",
         capabilities.symbol,
         capabilities.freezeLevel
      );

      return(false);
   }

   if(!IsPositiveFiniteSymbolValue(capabilities.contractSize))
   {
      PrintFormat(
         "Invalid SYMBOL_TRADE_CONTRACT_SIZE for %s: %G",
         capabilities.symbol,
         capabilities.contractSize
      );

      return(false);
   }

   return(true);
}

bool DetectAccountPositionMode(
   AccountPositionMode &positionMode
)
{
   positionMode = ACCOUNT_POSITION_MODE_UNKNOWN;

   const ENUM_ACCOUNT_MARGIN_MODE marginMode =
      (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);

   switch(marginMode)
   {
      case ACCOUNT_MARGIN_MODE_RETAIL_NETTING:
      case ACCOUNT_MARGIN_MODE_EXCHANGE:
         positionMode = ACCOUNT_POSITION_MODE_NETTING;
         return(true);

      case ACCOUNT_MARGIN_MODE_RETAIL_HEDGING:
         positionMode = ACCOUNT_POSITION_MODE_HEDGING;
         return(true);
   }

   PrintFormat(
      "Unsupported ACCOUNT_MARGIN_MODE: %d",
      (int)marginMode
   );

   return(false);
}

bool LoadSymbolCapabilities(
   const string symbol,
   SymbolCapabilities &capabilities
)
{
   long integerValue = 0;

   capabilities.symbol = symbol;

   if(!ReadSymbolIntegerProperty(
      symbol,
      SYMBOL_DIGITS,
      "SYMBOL_DIGITS",
      integerValue
   ))
   {
      return(false);
   }

   capabilities.digits = (int)integerValue;

   if(!ReadSymbolDoubleProperty(
      symbol,
      SYMBOL_POINT,
      "SYMBOL_POINT",
      capabilities.point
   ))
   {
      return(false);
   }

   if(!ReadSymbolDoubleProperty(
      symbol,
      SYMBOL_TRADE_TICK_SIZE,
      "SYMBOL_TRADE_TICK_SIZE",
      capabilities.tickSize
   ))
   {
      return(false);
   }

   if(!ReadSymbolDoubleProperty(
      symbol,
      SYMBOL_TRADE_TICK_VALUE,
      "SYMBOL_TRADE_TICK_VALUE",
      capabilities.tickValue
   ))
   {
      return(false);
   }

   if(!ReadSymbolDoubleProperty(
      symbol,
      SYMBOL_VOLUME_MIN,
      "SYMBOL_VOLUME_MIN",
      capabilities.volumeMin
   ))
   {
      return(false);
   }

   if(!ReadSymbolDoubleProperty(
      symbol,
      SYMBOL_VOLUME_MAX,
      "SYMBOL_VOLUME_MAX",
      capabilities.volumeMax
   ))
   {
      return(false);
   }

   if(!ReadSymbolDoubleProperty(
      symbol,
      SYMBOL_VOLUME_STEP,
      "SYMBOL_VOLUME_STEP",
      capabilities.volumeStep
   ))
   {
      return(false);
   }

   if(!ReadSymbolIntegerProperty(
      symbol,
      SYMBOL_TRADE_STOPS_LEVEL,
      "SYMBOL_TRADE_STOPS_LEVEL",
      integerValue
   ))
   {
      return(false);
   }

   capabilities.stopsLevel = (int)integerValue;

   if(!ReadSymbolIntegerProperty(
      symbol,
      SYMBOL_TRADE_FREEZE_LEVEL,
      "SYMBOL_TRADE_FREEZE_LEVEL",
      integerValue
   ))
   {
      return(false);
   }

   capabilities.freezeLevel = (int)integerValue;

   if(!ReadSymbolIntegerProperty(
      symbol,
      SYMBOL_TRADE_MODE,
      "SYMBOL_TRADE_MODE",
      integerValue
   ))
   {
      return(false);
   }

   capabilities.tradeMode = (ENUM_SYMBOL_TRADE_MODE)integerValue;

   if(!ReadSymbolIntegerProperty(
      symbol,
      SYMBOL_ORDER_MODE,
      "SYMBOL_ORDER_MODE",
      integerValue
   ))
   {
      return(false);
   }

   capabilities.orderMode = (int)integerValue;

   if(!ReadSymbolIntegerProperty(
      symbol,
      SYMBOL_TRADE_EXEMODE,
      "SYMBOL_TRADE_EXEMODE",
      integerValue
   ))
   {
      return(false);
   }

   capabilities.executionMode =
      (ENUM_SYMBOL_TRADE_EXECUTION)integerValue;

   if(!ReadSymbolIntegerProperty(
      symbol,
      SYMBOL_FILLING_MODE,
      "SYMBOL_FILLING_MODE",
      integerValue
   ))
   {
      return(false);
   }

   capabilities.fillingMode = (int)integerValue;

   if(!ReadSymbolDoubleProperty(
      symbol,
      SYMBOL_TRADE_CONTRACT_SIZE,
      "SYMBOL_TRADE_CONTRACT_SIZE",
      capabilities.contractSize
   ))
   {
      return(false);
   }

   if(!ReadSymbolIntegerProperty(
      symbol,
      SYMBOL_TRADE_CALC_MODE,
      "SYMBOL_TRADE_CALC_MODE",
      integerValue
   ))
   {
      return(false);
   }

   capabilities.calculationMode =
      (ENUM_SYMBOL_CALC_MODE)integerValue;

   return(true);
}

#endif
