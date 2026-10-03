#ifndef XAUFORGE_TRADE_MANAGER_MQH
#define XAUFORGE_TRADE_MANAGER_MQH

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

#endif
