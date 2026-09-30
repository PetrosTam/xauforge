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

#endif
