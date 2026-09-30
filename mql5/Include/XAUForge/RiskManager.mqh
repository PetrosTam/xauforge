#ifndef XAUFORGE_RISK_MANAGER_MQH
#define XAUFORGE_RISK_MANAGER_MQH

struct RiskSettings
{
   double riskPercent;
   double maxDailyLossPercent;
   double riskRewardRatio;
};

bool ValidatePositiveFiniteRiskValue(
   const string name,
   const double value
)
{
   if(MathIsValidNumber(value) && value > 0.0)
      return(true);

   PrintFormat(
      "Invalid %s: %G. Value must be finite and greater than zero.",
      name,
      value
   );

   return(false);
}

bool ValidateRiskSettings(
   const RiskSettings &settings
)
{
   if(!ValidatePositiveFiniteRiskValue(
      "RiskPercent",
      settings.riskPercent
   ))
   {
      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "MaxDailyLossPercent",
      settings.maxDailyLossPercent
   ))
   {
      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "RiskRewardRatio",
      settings.riskRewardRatio
   ))
   {
      return(false);
   }

   return(true);
}

#endif
