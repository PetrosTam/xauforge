#ifndef XAUFORGE_RISK_MANAGER_MQH
#define XAUFORGE_RISK_MANAGER_MQH

#include <XAUForge/StrategyEngine.mqh>

struct RiskSettings
{
   double riskPercent;
   double maxDailyLossPercent;
   double riskRewardRatio;
};

const double BASELINE_ATR_STOP_MULTIPLIER = 2.0;

struct RiskTradePlan
{
   SignalDirection direction;
   double entryPrice;
   double stopLossPrice;
   double takeProfitPrice;
   double stopDistance;
};

struct RiskSizingResult
{
   double equity;
   double plannedRiskAmount;
   double referenceVolume;
   double lossForReferenceVolume;
   double rawVolume;
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

bool BuildBaselineRiskTradePlan(
   const SignalDirection direction,
   const double entryPrice,
   const double atrValue,
   const double riskRewardRatio,
   RiskTradePlan &plan
)
{
   plan.direction = SIGNAL_NONE;
   plan.entryPrice = 0.0;
   plan.stopLossPrice = 0.0;
   plan.takeProfitPrice = 0.0;
   plan.stopDistance = 0.0;

   if(
      direction != SIGNAL_BUY &&
      direction != SIGNAL_SELL
   )
   {
      PrintFormat(
         "Cannot build risk trade plan for signal: %s",
         EnumToString(direction)
      );

      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "EntryPrice",
      entryPrice
   ))
   {
      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "ATR",
      atrValue
   ))
   {
      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "RiskRewardRatio",
      riskRewardRatio
   ))
   {
      return(false);
   }

   const double stopDistance =
      atrValue * BASELINE_ATR_STOP_MULTIPLIER;

   if(!ValidatePositiveFiniteRiskValue(
      "StopDistance",
      stopDistance
   ))
   {
      return(false);
   }

   plan.direction = direction;
   plan.entryPrice = entryPrice;
   plan.stopDistance = stopDistance;

   if(direction == SIGNAL_BUY)
   {
      plan.stopLossPrice =
         entryPrice - stopDistance;

      plan.takeProfitPrice =
         entryPrice + stopDistance * riskRewardRatio;
   }
   else
   {
      plan.stopLossPrice =
         entryPrice + stopDistance;

      plan.takeProfitPrice =
         entryPrice - stopDistance * riskRewardRatio;
   }

   if(!ValidatePositiveFiniteRiskValue(
      "StopLossPrice",
      plan.stopLossPrice
   ))
   {
      plan.direction = SIGNAL_NONE;
      plan.entryPrice = 0.0;
      plan.stopLossPrice = 0.0;
      plan.takeProfitPrice = 0.0;
      plan.stopDistance = 0.0;

      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "TakeProfitPrice",
      plan.takeProfitPrice
   ))
   {
      plan.direction = SIGNAL_NONE;
      plan.entryPrice = 0.0;
      plan.stopLossPrice = 0.0;
      plan.takeProfitPrice = 0.0;
      plan.stopDistance = 0.0;

      return(false);
   }

   return(true);
}

bool CalculateRawRiskVolume(
   const string symbol,
   const SignalDirection direction,
   const double entryPrice,
   const double stopLossPrice,
   const double equity,
   const double riskPercent,
   const double referenceVolume,
   RiskSizingResult &result
)
{
   result.equity = 0.0;
   result.plannedRiskAmount = 0.0;
   result.referenceVolume = 0.0;
   result.lossForReferenceVolume = 0.0;
   result.rawVolume = 0.0;

   if(
      direction != SIGNAL_BUY &&
      direction != SIGNAL_SELL
   )
   {
      PrintFormat(
         "Cannot calculate risk volume for signal: %s",
         EnumToString(direction)
      );

      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "EntryPrice",
      entryPrice
   ))
   {
      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "StopLossPrice",
      stopLossPrice
   ))
   {
      return(false);
   }

   if(
      direction == SIGNAL_BUY &&
      stopLossPrice >= entryPrice
   )
   {
      Print(
         "Invalid BUY stop-loss: stop must be below entry price."
      );

      return(false);
   }

   if(
      direction == SIGNAL_SELL &&
      stopLossPrice <= entryPrice
   )
   {
      Print(
         "Invalid SELL stop-loss: stop must be above entry price."
      );

      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "Equity",
      equity
   ))
   {
      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "RiskPercent",
      riskPercent
   ))
   {
      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "ReferenceVolume",
      referenceVolume
   ))
   {
      return(false);
   }

   const double plannedRiskAmount =
      equity * (riskPercent / 100.0);

   if(!ValidatePositiveFiniteRiskValue(
      "PlannedRiskAmount",
      plannedRiskAmount
   ))
   {
      return(false);
   }

   const ENUM_ORDER_TYPE orderType =
      (direction == SIGNAL_BUY)
      ? ORDER_TYPE_BUY
      : ORDER_TYPE_SELL;

   double referenceProfit = 0.0;

   ResetLastError();

   if(!OrderCalcProfit(
      orderType,
      symbol,
      referenceVolume,
      entryPrice,
      stopLossPrice,
      referenceProfit
   ))
   {
      PrintFormat(
         "OrderCalcProfit failed for risk sizing. Error: %d",
         GetLastError()
      );

      return(false);
   }

   const double lossForReferenceVolume =
      MathAbs(referenceProfit);

   if(!ValidatePositiveFiniteRiskValue(
      "LossForReferenceVolume",
      lossForReferenceVolume
   ))
   {
      return(false);
   }

   const double rawVolume =
      plannedRiskAmount /
      lossForReferenceVolume *
      referenceVolume;

   if(!ValidatePositiveFiniteRiskValue(
      "RawVolume",
      rawVolume
   ))
   {
      return(false);
   }

   result.equity = equity;
   result.plannedRiskAmount = plannedRiskAmount;
   result.referenceVolume = referenceVolume;
   result.lossForReferenceVolume =
      lossForReferenceVolume;
   result.rawVolume = rawVolume;

   return(true);
}

#endif
