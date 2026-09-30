#ifndef XAUFORGE_SYMBOL_MANAGER_MQH
#define XAUFORGE_SYMBOL_MANAGER_MQH

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
