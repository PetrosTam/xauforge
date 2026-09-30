#ifndef XAUFORGE_RISK_MANAGER_MQH
#define XAUFORGE_RISK_MANAGER_MQH

#include <XAUForge/StrategyEngine.mqh>

struct RiskSettings
{
   double riskPercent;
   double maxDailyLossPercent;
   double riskRewardRatio;
};

const double BASELINE_ATR_STOP_MULTIPLIER    = 2.0;
const double MAX_PERCENT_VALUE               = 100.0;
const double DAILY_LOSS_STATE_SCHEMA_VERSION = 1.0;
const int MAX_TERMINAL_GLOBAL_NAME_LENGTH    = 63;

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

enum DailyLossStateLoadStatus
{
   DAILY_LOSS_STATE_LOAD_NOT_FOUND,
   DAILY_LOSS_STATE_LOAD_SUCCESS,
   DAILY_LOSS_STATE_LOAD_INVALID
};

enum DailyLossInitializationLoadStatus
{
   DAILY_LOSS_INITIALIZATION_LOAD_NOT_FOUND,
   DAILY_LOSS_INITIALIZATION_LOAD_SUCCESS,
   DAILY_LOSS_INITIALIZATION_LOAD_INVALID
};

enum DailyLossStateResolutionStatus
{
   DAILY_LOSS_STATE_RESOLUTION_RECOVERED,
   DAILY_LOSS_STATE_RESOLUTION_INITIALIZED,
   DAILY_LOSS_STATE_RESOLUTION_FAIL_SAFE
};

struct DailyLossState
{
   int serverDayId;
   double dayStartEquity;
   bool valid;
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

bool ValidatePercentage(
   const string name,
   const double value
)
{
   if(!ValidatePositiveFiniteRiskValue(
      name,
      value
   ))
   {
      return(false);
   }

   if(value > MAX_PERCENT_VALUE)
   {
      PrintFormat(
         "Invalid %s: %G. Value must not exceed %G percent.",
         name,
         value,
         MAX_PERCENT_VALUE
      );

      return(false);
   }

   return(true);
}

bool ValidateRiskSettings(
   const RiskSettings &settings
)
{
   if(!ValidatePercentage(
      "RiskPercent",
      settings.riskPercent
   ))
   {
      return(false);
   }

   if(!ValidatePercentage(
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

void ResetDailyLossState(
   DailyLossState &state
)
{
   state.serverDayId = 0;
   state.dayStartEquity = 0.0;
   state.valid = false;
}

bool IsValidServerDayId(
   const int serverDayId
)
{
   const int year =
      serverDayId / 10000;

   const int month =
      (serverDayId / 100) % 100;

   const int day =
      serverDayId % 100;

   if(
      year < 1970 ||
      year > 3000 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31
   )
   {
      return(false);
   }

   MqlDateTime candidateDate = {};

   candidateDate.year = year;
   candidateDate.mon = month;
   candidateDate.day = day;

   const datetime candidateTime =
      StructToTime(candidateDate);

   MqlDateTime normalizedDate = {};

   ResetLastError();

   if(!TimeToStruct(
      candidateTime,
      normalizedDate
   ))
   {
      PrintFormat(
         "Failed to validate server day identifier %d. Error: %d",
         serverDayId,
         GetLastError()
      );

      return(false);
   }

   return(
      normalizedDate.year == year &&
      normalizedDate.mon == month &&
      normalizedDate.day == day
   );
}

bool GetCurrentBrokerServerDayId(
   int &serverDayId
)
{
   serverDayId = 0;

   MqlDateTime serverDate = {};

   ResetLastError();

   const datetime serverTime =
      TimeCurrent(serverDate);

   if(serverTime <= 0)
   {
      PrintFormat(
         "Failed to obtain broker-server time. Error: %d",
         GetLastError()
      );

      return(false);
   }

   serverDayId =
      serverDate.year * 10000 +
      serverDate.mon * 100 +
      serverDate.day;

   if(!IsValidServerDayId(serverDayId))
   {
      PrintFormat(
         "Invalid broker-server day identifier: %d.",
         serverDayId
      );

      serverDayId = 0;
      return(false);
   }

   return(true);
}

bool BuildDailyLossPersistenceKeys(
   const long accountLogin,
   const string accountServer,
   string &initializationKey,
   string &versionKey,
   string &dayKey,
   string &equityKey
)
{
   initializationKey = "";
   versionKey = "";
   dayKey = "";
   equityKey = "";

   if(accountLogin <= 0)
   {
      PrintFormat(
         "Invalid account login for daily-loss persistence: %I64d.",
         accountLogin
      );

      return(false);
   }

   if(StringLen(accountServer) == 0)
   {
      Print(
         "Account server is empty for daily-loss persistence."
      );

      return(false);
   }

   const string prefix =
      "XAUForge.DL." +
      IntegerToString(accountLogin) +
      "." +
      accountServer;

   initializationKey = prefix + ".I";
   versionKey = prefix + ".V";
   dayKey = prefix + ".D";
   equityKey = prefix + ".E";

   if(
      StringLen(initializationKey) >
         MAX_TERMINAL_GLOBAL_NAME_LENGTH ||
      StringLen(versionKey) >
         MAX_TERMINAL_GLOBAL_NAME_LENGTH ||
      StringLen(dayKey) >
         MAX_TERMINAL_GLOBAL_NAME_LENGTH ||
      StringLen(equityKey) >
         MAX_TERMINAL_GLOBAL_NAME_LENGTH
   )
   {
      PrintFormat(
         "Daily-loss persistence namespace exceeds %d characters.",
         MAX_TERMINAL_GLOBAL_NAME_LENGTH
      );

      initializationKey = "";
      versionKey = "";
      dayKey = "";
      equityKey = "";

      return(false);
   }

   return(true);
}

bool SaveDailyLossInitializationDay(
   const long accountLogin,
   const string accountServer,
   const int serverDayId
)
{
   if(!IsValidServerDayId(serverDayId))
   {
      PrintFormat(
         "Cannot persist invalid daily-loss initialization day: %d.",
         serverDayId
      );

      return(false);
   }

   string initializationKey = "";
   string versionKey = "";
   string dayKey = "";
   string equityKey = "";

   if(!BuildDailyLossPersistenceKeys(
      accountLogin,
      accountServer,
      initializationKey,
      versionKey,
      dayKey,
      equityKey
   ))
   {
      return(false);
   }

   ResetLastError();

   if(
      GlobalVariableSet(
         initializationKey,
         (double)serverDayId
      ) == 0
   )
   {
      PrintFormat(
         "Failed to persist daily-loss initialization day. Error: %d",
         GetLastError()
      );

      return(false);
   }

   GlobalVariablesFlush();

   return(true);
}

DailyLossInitializationLoadStatus LoadDailyLossInitializationDay(
   const long accountLogin,
   const string accountServer,
   int &serverDayId
)
{
   serverDayId = 0;

   string initializationKey = "";
   string versionKey = "";
   string dayKey = "";
   string equityKey = "";

   if(!BuildDailyLossPersistenceKeys(
      accountLogin,
      accountServer,
      initializationKey,
      versionKey,
      dayKey,
      equityKey
   ))
   {
      return(DAILY_LOSS_INITIALIZATION_LOAD_INVALID);
   }

   if(!GlobalVariableCheck(initializationKey))
      return(DAILY_LOSS_INITIALIZATION_LOAD_NOT_FOUND);

   double persistedValue = 0.0;

   ResetLastError();

   if(!GlobalVariableGet(
      initializationKey,
      persistedValue
   ))
   {
      PrintFormat(
         "Failed to load daily-loss initialization day. Error: %d",
         GetLastError()
      );

      return(DAILY_LOSS_INITIALIZATION_LOAD_INVALID);
   }

   if(
      !MathIsValidNumber(persistedValue) ||
      persistedValue != MathFloor(persistedValue) ||
      persistedValue < 19700101.0 ||
      persistedValue > 30001231.0
   )
   {
      PrintFormat(
         "Invalid persisted daily-loss initialization day: %G.",
         persistedValue
      );

      return(DAILY_LOSS_INITIALIZATION_LOAD_INVALID);
   }

   const int persistedDayId =
      (int)persistedValue;

   if(!IsValidServerDayId(persistedDayId))
   {
      PrintFormat(
         "Invalid persisted daily-loss initialization day: %d.",
         persistedDayId
      );

      return(DAILY_LOSS_INITIALIZATION_LOAD_INVALID);
   }

   serverDayId = persistedDayId;

   return(DAILY_LOSS_INITIALIZATION_LOAD_SUCCESS);
}

bool SaveDailyLossState(
   const long accountLogin,
   const string accountServer,
   const DailyLossState &state
)
{
   if(!state.valid)
   {
      Print(
         "Cannot persist an invalid daily-loss state."
      );

      return(false);
   }

   if(!IsValidServerDayId(state.serverDayId))
   {
      PrintFormat(
         "Cannot persist invalid server day identifier: %d.",
         state.serverDayId
      );

      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "DayStartEquity",
      state.dayStartEquity
   ))
   {
      return(false);
   }

   string initializationKey = "";
   string versionKey = "";
   string dayKey = "";
   string equityKey = "";

   if(!BuildDailyLossPersistenceKeys(
      accountLogin,
      accountServer,
      initializationKey,
      versionKey,
      dayKey,
      equityKey
   ))
   {
      return(false);
   }

   // Invalidate the commit marker first. If the process stops while
   // updating the payload, recovery must see an invalid state.
   ResetLastError();

   if(
      GlobalVariableSet(
         dayKey,
         0.0
      ) == 0
   )
   {
      PrintFormat(
         "Failed to invalidate daily-loss commit marker. Error: %d",
         GetLastError()
      );

      return(false);
   }

   GlobalVariablesFlush();

   ResetLastError();

   if(
      GlobalVariableSet(
         equityKey,
         state.dayStartEquity
      ) == 0
   )
   {
      PrintFormat(
         "Failed to persist daily-loss start equity. Error: %d",
         GetLastError()
      );

      return(false);
   }

   ResetLastError();

   if(
      GlobalVariableSet(
         versionKey,
         DAILY_LOSS_STATE_SCHEMA_VERSION
      ) == 0
   )
   {
      PrintFormat(
         "Failed to persist daily-loss state version. Error: %d",
         GetLastError()
      );

      return(false);
   }

   // Write the valid day marker last so only a complete payload can
   // be accepted as committed state.
   ResetLastError();

   if(
      GlobalVariableSet(
         dayKey,
         (double)state.serverDayId
      ) == 0
   )
   {
      PrintFormat(
         "Failed to persist daily-loss server day. Error: %d",
         GetLastError()
      );

      return(false);
   }

   GlobalVariablesFlush();

   return(true);
}

DailyLossStateLoadStatus LoadDailyLossState(
   const long accountLogin,
   const string accountServer,
   DailyLossState &state
)
{
   ResetDailyLossState(state);

   string initializationKey = "";
   string versionKey = "";
   string dayKey = "";
   string equityKey = "";

   if(!BuildDailyLossPersistenceKeys(
      accountLogin,
      accountServer,
      initializationKey,
      versionKey,
      dayKey,
      equityKey
   ))
   {
      return(DAILY_LOSS_STATE_LOAD_INVALID);
   }

   const bool hasVersion =
      GlobalVariableCheck(versionKey);

   const bool hasDay =
      GlobalVariableCheck(dayKey);

   const bool hasEquity =
      GlobalVariableCheck(equityKey);

   if(
      !hasVersion &&
      !hasDay &&
      !hasEquity
   )
   {
      return(DAILY_LOSS_STATE_LOAD_NOT_FOUND);
   }

   if(
      !hasVersion ||
      !hasDay ||
      !hasEquity
   )
   {
      Print(
         "Daily-loss persistence state is incomplete."
      );

      return(DAILY_LOSS_STATE_LOAD_INVALID);
   }

   double versionValue = 0.0;
   double dayValue = 0.0;
   double equityValue = 0.0;

   ResetLastError();

   if(!GlobalVariableGet(
      versionKey,
      versionValue
   ))
   {
      PrintFormat(
         "Failed to load daily-loss state version. Error: %d",
         GetLastError()
      );

      return(DAILY_LOSS_STATE_LOAD_INVALID);
   }

   ResetLastError();

   if(!GlobalVariableGet(
      dayKey,
      dayValue
   ))
   {
      PrintFormat(
         "Failed to load daily-loss server day. Error: %d",
         GetLastError()
      );

      return(DAILY_LOSS_STATE_LOAD_INVALID);
   }

   ResetLastError();

   if(!GlobalVariableGet(
      equityKey,
      equityValue
   ))
   {
      PrintFormat(
         "Failed to load daily-loss start equity. Error: %d",
         GetLastError()
      );

      return(DAILY_LOSS_STATE_LOAD_INVALID);
   }

   if(
      !MathIsValidNumber(versionValue) ||
      versionValue != DAILY_LOSS_STATE_SCHEMA_VERSION
   )
   {
      PrintFormat(
         "Unsupported or invalid daily-loss state version: %G.",
         versionValue
      );

      return(DAILY_LOSS_STATE_LOAD_INVALID);
   }

   if(
      !MathIsValidNumber(dayValue) ||
      dayValue != MathFloor(dayValue) ||
      dayValue < 19700101.0 ||
      dayValue > 30001231.0
   )
   {
      PrintFormat(
         "Invalid persisted daily-loss server day: %G.",
         dayValue
      );

      return(DAILY_LOSS_STATE_LOAD_INVALID);
   }

   const int persistedDayId =
      (int)dayValue;

   if(!IsValidServerDayId(persistedDayId))
   {
      PrintFormat(
         "Invalid persisted daily-loss server day: %d.",
         persistedDayId
      );

      return(DAILY_LOSS_STATE_LOAD_INVALID);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "PersistedDayStartEquity",
      equityValue
   ))
   {
      return(DAILY_LOSS_STATE_LOAD_INVALID);
   }

   state.serverDayId = persistedDayId;
   state.dayStartEquity = equityValue;
   state.valid = true;

   return(DAILY_LOSS_STATE_LOAD_SUCCESS);
}

bool InitializeDailyLossStateForDay(
   const long accountLogin,
   const string accountServer,
   const int serverDayId,
   const double currentEquity,
   DailyLossState &state
)
{
   ResetDailyLossState(state);

   if(!IsValidServerDayId(serverDayId))
   {
      PrintFormat(
         "Cannot initialize daily-loss state for invalid server day: %d.",
         serverDayId
      );

      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "CurrentEquity",
      currentEquity
   ))
   {
      return(false);
   }

   // Persist the initialization guard first. If baseline persistence
   // later fails, a restart on the same day must fail safe instead
   // of silently creating a fresh loss budget.
   if(!SaveDailyLossInitializationDay(
      accountLogin,
      accountServer,
      serverDayId
   ))
   {
      return(false);
   }

   state.serverDayId = serverDayId;
   state.dayStartEquity = currentEquity;
   state.valid = true;

   if(!SaveDailyLossState(
      accountLogin,
      accountServer,
      state
   ))
   {
      ResetDailyLossState(state);
      return(false);
   }

   return(true);
}

DailyLossStateResolutionStatus InitializeOrRecoverDailyLossState(
   const long accountLogin,
   const string accountServer,
   const double currentEquity,
   DailyLossState &state
)
{
   ResetDailyLossState(state);

   int currentServerDayId = 0;

   if(!GetCurrentBrokerServerDayId(currentServerDayId))
      return(DAILY_LOSS_STATE_RESOLUTION_FAIL_SAFE);

   int initializationDayId = 0;

   const DailyLossInitializationLoadStatus initializationStatus =
      LoadDailyLossInitializationDay(
         accountLogin,
         accountServer,
         initializationDayId
      );

   if(
      initializationStatus ==
         DAILY_LOSS_INITIALIZATION_LOAD_INVALID
   )
   {
      return(DAILY_LOSS_STATE_RESOLUTION_FAIL_SAFE);
   }

   DailyLossState persistedState;
   ResetDailyLossState(persistedState);

   const DailyLossStateLoadStatus stateStatus =
      LoadDailyLossState(
         accountLogin,
         accountServer,
         persistedState
      );

   if(
      stateStatus ==
         DAILY_LOSS_STATE_LOAD_SUCCESS
   )
   {
      if(persistedState.serverDayId > currentServerDayId)
      {
         Print(
            "Persisted daily-loss state is from a future server day."
         );

         return(DAILY_LOSS_STATE_RESOLUTION_FAIL_SAFE);
      }

      if(persistedState.serverDayId == currentServerDayId)
      {
         if(
            initializationStatus ==
               DAILY_LOSS_INITIALIZATION_LOAD_SUCCESS &&
            initializationDayId > currentServerDayId
         )
         {
            Print(
               "Daily-loss initialization guard is from a future server day."
            );

            return(DAILY_LOSS_STATE_RESOLUTION_FAIL_SAFE);
         }

         if(
            initializationStatus ==
               DAILY_LOSS_INITIALIZATION_LOAD_NOT_FOUND ||
            initializationDayId < currentServerDayId
         )
         {
            if(!SaveDailyLossInitializationDay(
               accountLogin,
               accountServer,
               currentServerDayId
            ))
            {
               return(DAILY_LOSS_STATE_RESOLUTION_FAIL_SAFE);
            }
         }

         state = persistedState;

         return(DAILY_LOSS_STATE_RESOLUTION_RECOVERED);
      }

      if(
         initializationStatus ==
            DAILY_LOSS_INITIALIZATION_LOAD_SUCCESS &&
         initializationDayId >= currentServerDayId
      )
      {
         Print(
            "Daily-loss initialization for the current or a future server day "
            "exists without a matching current-day baseline."
         );

         return(DAILY_LOSS_STATE_RESOLUTION_FAIL_SAFE);
      }

      if(!InitializeDailyLossStateForDay(
         accountLogin,
         accountServer,
         currentServerDayId,
         currentEquity,
         state
      ))
      {
         return(DAILY_LOSS_STATE_RESOLUTION_FAIL_SAFE);
      }

      return(DAILY_LOSS_STATE_RESOLUTION_INITIALIZED);
   }

   if(
      stateStatus ==
         DAILY_LOSS_STATE_LOAD_INVALID
   )
   {
      if(
         initializationStatus !=
            DAILY_LOSS_INITIALIZATION_LOAD_SUCCESS ||
         initializationDayId >= currentServerDayId
      )
      {
         Print(
            "Invalid daily-loss state cannot be replaced within the "
            "current server day."
         );

         return(DAILY_LOSS_STATE_RESOLUTION_FAIL_SAFE);
      }

      if(!InitializeDailyLossStateForDay(
         accountLogin,
         accountServer,
         currentServerDayId,
         currentEquity,
         state
      ))
      {
         return(DAILY_LOSS_STATE_RESOLUTION_FAIL_SAFE);
      }

      return(DAILY_LOSS_STATE_RESOLUTION_INITIALIZED);
   }

   // No persisted baseline exists.
   if(
      initializationStatus ==
         DAILY_LOSS_INITIALIZATION_LOAD_SUCCESS &&
      initializationDayId >= currentServerDayId
   )
   {
      Print(
         "Daily-loss baseline is missing after initialization began "
         "for the current or a future server day."
      );

      return(DAILY_LOSS_STATE_RESOLUTION_FAIL_SAFE);
   }

   if(!InitializeDailyLossStateForDay(
      accountLogin,
      accountServer,
      currentServerDayId,
      currentEquity,
      state
   ))
   {
      return(DAILY_LOSS_STATE_RESOLUTION_FAIL_SAFE);
   }

   return(DAILY_LOSS_STATE_RESOLUTION_INITIALIZED);
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

   if(!ValidatePercentage(
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

bool NormalizeRiskVolumeDown(
   const double rawVolume,
   const double volumeMin,
   const double volumeMax,
   const double volumeStep,
   double &normalizedVolume
)
{
   normalizedVolume = 0.0;

   if(!ValidatePositiveFiniteRiskValue(
      "RawVolume",
      rawVolume
   ))
   {
      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "VolumeMin",
      volumeMin
   ))
   {
      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "VolumeMax",
      volumeMax
   ))
   {
      return(false);
   }

   if(!ValidatePositiveFiniteRiskValue(
      "VolumeStep",
      volumeStep
   ))
   {
      return(false);
   }

   if(volumeMin > volumeMax)
   {
      PrintFormat(
         "Invalid volume bounds: min=%G exceeds max=%G.",
         volumeMin,
         volumeMax
      );

      return(false);
   }

   const double cappedVolume =
      MathMin(rawVolume, volumeMax);

   if(rawVolume > volumeMax)
   {
      PrintFormat(
         "Raw volume %G exceeds broker maximum %G. Capping downward.",
         rawVolume,
         volumeMax
      );
   }

   const double stepCount =
      cappedVolume / volumeStep;

   if(!MathIsValidNumber(stepCount))
   {
      PrintFormat(
         "Invalid volume step count for capped volume %G and step %G.",
         cappedVolume,
         volumeStep
      );

      return(false);
   }

   const double stepTolerance =
      DBL_EPSILON *
      MathMax(1.0, MathAbs(stepCount)) *
      8.0;

   normalizedVolume =
      MathFloor(stepCount + stepTolerance) *
      volumeStep;

   if(!MathIsValidNumber(normalizedVolume))
   {
      Print(
         "Volume normalization produced an invalid numeric result."
      );

      normalizedVolume = 0.0;
      return(false);
   }

   const double volumeTolerance =
      stepTolerance * volumeStep;

   if(
      normalizedVolume >
      cappedVolume + volumeTolerance
   )
   {
      PrintFormat(
         "Normalized volume %G exceeds capped risk volume %G.",
         normalizedVolume,
         cappedVolume
      );

      normalizedVolume = 0.0;
      return(false);
   }

   if(
      normalizedVolume + volumeTolerance <
      volumeMin
   )
   {
      PrintFormat(
         "Normalized volume %G is below broker minimum %G.",
         normalizedVolume,
         volumeMin
      );

      normalizedVolume = 0.0;
      return(false);
   }

   if(
      normalizedVolume >
      volumeMax + volumeTolerance
   )
   {
      PrintFormat(
         "Normalized volume %G exceeds broker maximum %G.",
         normalizedVolume,
         volumeMax
      );

      normalizedVolume = 0.0;
      return(false);
   }

   if(normalizedVolume < volumeMin)
      normalizedVolume = volumeMin;

   if(normalizedVolume > volumeMax)
      normalizedVolume = volumeMax;

   if(
      normalizedVolume >
      cappedVolume + volumeTolerance
   )
   {
      PrintFormat(
         "Final normalized volume %G exceeds capped risk volume %G.",
         normalizedVolume,
         cappedVolume
      );

      normalizedVolume = 0.0;
      return(false);
   }

   return(true);
}

#endif
