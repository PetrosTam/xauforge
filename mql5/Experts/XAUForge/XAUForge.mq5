#include <XAUForge/StrategyEngine.mqh>
#include <XAUForge/SymbolManager.mqh>
#include <XAUForge/RiskManager.mqh>

input ENUM_TIMEFRAMES SignalTimeframe = PERIOD_H1;

input group "Risk Management"
input double RiskPercent = 1.0;
input double MaxDailyLossPercent = 3.0;
input double RiskRewardRatio = 2.0;

datetime g_lastBarOpenTime = 0;
SymbolCapabilities g_symbolCapabilities;
AccountPositionMode g_accountPositionMode = ACCOUNT_POSITION_MODE_UNKNOWN;
RiskSettings g_riskSettings;
DailyLossState g_dailyLossState;

bool IsNewBar()
{
   const datetime currentBarOpenTime = iTime(_Symbol, SignalTimeframe, 0);

   if(currentBarOpenTime == 0)
      return(false);

   if(currentBarOpenTime == g_lastBarOpenTime)
      return(false);

   g_lastBarOpenTime = currentBarOpenTime;

   return(true);
}

DailyLossStateResolutionStatus ResolveCurrentDailyLossState(
   const double currentEquity
)
{
   const long accountLogin =
      AccountInfoInteger(ACCOUNT_LOGIN);

   const string accountServer =
      AccountInfoString(ACCOUNT_SERVER);

   return(InitializeOrRecoverDailyLossState(
      accountLogin,
      accountServer,
      currentEquity,
      g_dailyLossState
   ));
}

int OnInit()
{
   ResetLastError();

   g_riskSettings.riskPercent = RiskPercent;
   g_riskSettings.maxDailyLossPercent = MaxDailyLossPercent;
   g_riskSettings.riskRewardRatio = RiskRewardRatio;

   if(!ValidateRiskSettings(g_riskSettings))
      return(INIT_PARAMETERS_INCORRECT);

   ResetDailyLossState(g_dailyLossState);

   g_lastBarOpenTime = iTime(_Symbol, SignalTimeframe, 0);

   if(g_lastBarOpenTime == 0)
   {
      PrintFormat(
         "Failed to initialize current bar time. Error: %d",
         GetLastError()
      );

      return(INIT_FAILED);
   }

   if(!LoadSymbolCapabilities(_Symbol, g_symbolCapabilities))
   {
      PrintFormat(
         "Failed to load symbol capabilities for %s.",
         _Symbol
      );

      return(INIT_FAILED);
   }

   if(!ValidateSymbolCapabilities(g_symbolCapabilities))
   {
      PrintFormat(
         "Symbol capabilities are invalid for %s.",
         _Symbol
      );

      return(INIT_FAILED);
   }

   if(!DetectAccountPositionMode(g_accountPositionMode))
   {
      Print("Failed to classify account position mode.");
      return(INIT_FAILED);
   }

   const double initialEquity =
      AccountInfoDouble(ACCOUNT_EQUITY);

   const DailyLossStateResolutionStatus dailyLossStatus =
      ResolveCurrentDailyLossState(initialEquity);

   if(
      dailyLossStatus ==
      DAILY_LOSS_STATE_RESOLUTION_FAIL_SAFE
   )
   {
      Print(
         "Daily-loss state initialization/recovery failed safe."
      );

      return(INIT_FAILED);
   }

   PrintFormat(
      "Symbol capabilities | symbol=%s | digits=%d | point=%G | tick_size=%G | tick_value=%G | volume_min=%G | volume_max=%G | volume_step=%G | stops_level=%d | freeze_level=%d | trade_mode=%s | order_mode=%d | execution_mode=%s | filling_mode=%d | contract_size=%G | calculation_mode=%s",
      g_symbolCapabilities.symbol,
      g_symbolCapabilities.digits,
      g_symbolCapabilities.point,
      g_symbolCapabilities.tickSize,
      g_symbolCapabilities.tickValue,
      g_symbolCapabilities.volumeMin,
      g_symbolCapabilities.volumeMax,
      g_symbolCapabilities.volumeStep,
      g_symbolCapabilities.stopsLevel,
      g_symbolCapabilities.freezeLevel,
      EnumToString(g_symbolCapabilities.tradeMode),
      g_symbolCapabilities.orderMode,
      EnumToString(g_symbolCapabilities.executionMode),
      g_symbolCapabilities.fillingMode,
      g_symbolCapabilities.contractSize,
      EnumToString(g_symbolCapabilities.calculationMode)
   );

   PrintFormat(
      "Account position mode: %s",
      EnumToString(g_accountPositionMode)
   );

   PrintFormat(
      "Daily-loss state | resolution=%s | server_day=%d | day_start_equity=%G | baseline_cash_flow=%G",
      EnumToString(dailyLossStatus),
      g_dailyLossState.serverDayId,
      g_dailyLossState.dayStartEquity,
      g_dailyLossState.cashFlowTotalAtBaseline
   );

   if(!InitializeStrategyIndicators(_Symbol, SignalTimeframe))
      return(INIT_FAILED);

   return(INIT_SUCCEEDED);
}

void OnTick()
{
   if(!IsNewBar())
      return;

   const double stateEquity =
      AccountInfoDouble(ACCOUNT_EQUITY);

   const DailyLossStateResolutionStatus dailyLossStatus =
      ResolveCurrentDailyLossState(stateEquity);

   if(
      dailyLossStatus ==
      DAILY_LOSS_STATE_RESOLUTION_FAIL_SAFE
   )
   {
      Print(
         "Daily-loss state resolution failed safe on new bar. New entries are blocked."
      );

      return;
   }

   CompletedStrategyData data;

   if(!ReadCompletedStrategyData(_Symbol, SignalTimeframe, data))
      return;

   const SignalDirection signal = EvaluateSignal(data);

   PrintFormat(
      "Strategy evaluated at %s | Signal: %s | EMA20[2]: %.5f | EMA20[1]: %.5f | EMA50[2]: %.5f | EMA50[1]: %.5f | ATR14[1]: %.5f",
      TimeToString(g_lastBarOpenTime, TIME_DATE | TIME_MINUTES),
      EnumToString(signal),
      data.fastEmaShift2,
      data.fastEmaShift1,
      data.slowEmaShift2,
      data.slowEmaShift1,
      data.atrShift1
   );

   if(signal == SIGNAL_NONE)
      return;

   const double gateEquity =
      AccountInfoDouble(ACCOUNT_EQUITY);

   DailyLossEntryGateResult gateResult;

   if(!EvaluateCurrentDailyLossEntryGate(
      g_dailyLossState,
      gateEquity,
      g_riskSettings.maxDailyLossPercent,
      gateResult
   ))
   {
      Print(
         "Daily-loss entry gate evaluation failed. New entry is blocked."
      );

      return;
   }

   PrintFormat(
      "Daily-loss gate | entry_allowed=%s | status=%s | adjusted_baseline=%G | equity=%G | drawdown=%G | drawdown_percent=%G | limit_percent=%G",
      gateResult.entryAllowed ? "true" : "false",
      EnumToString(gateResult.status),
      gateResult.evaluation.adjustedBaseline,
      gateResult.evaluation.currentEquity,
      gateResult.evaluation.drawdownAmount,
      gateResult.evaluation.drawdownPercent,
      gateResult.evaluation.maxDailyLossPercent
   );

   if(!gateResult.entryAllowed)
      return;

   MqlTick tick;

   ResetLastError();

   if(!SymbolInfoTick(_Symbol, tick))
   {
      PrintFormat(
         "Failed to read current tick for risk planning. Error: %d",
         GetLastError()
      );

      return;
   }

   const double entryPrice =
      (signal == SIGNAL_BUY)
      ? tick.ask
      : tick.bid;

   RiskTradePlan riskPlan;

   if(!BuildBaselineRiskTradePlan(
      signal,
      entryPrice,
      data.atrShift1,
      g_riskSettings.riskRewardRatio,
      riskPlan
   ))
   {
      return;
   }

   PrintFormat(
      "Risk plan | signal=%s | entry=%G | ATR14[1]=%G | stop_distance=%G | SL=%G | TP=%G | RR=%G",
      EnumToString(riskPlan.direction),
      riskPlan.entryPrice,
      data.atrShift1,
      riskPlan.stopDistance,
      riskPlan.stopLossPrice,
      riskPlan.takeProfitPrice,
      g_riskSettings.riskRewardRatio
   );

   const double equity =
      AccountInfoDouble(ACCOUNT_EQUITY);

   RiskSizingResult sizingResult;

   if(!CalculateRawRiskVolume(
      _Symbol,
      signal,
      riskPlan.entryPrice,
      riskPlan.stopLossPrice,
      equity,
      g_riskSettings.riskPercent,
      g_symbolCapabilities.volumeMin,
      sizingResult
   ))
   {
      return;
   }

   double normalizedVolume = 0.0;

   if(!NormalizeRiskVolumeDown(
      sizingResult.rawVolume,
      g_symbolCapabilities.volumeMin,
      g_symbolCapabilities.volumeMax,
      g_symbolCapabilities.volumeStep,
      normalizedVolume
   ))
   {
      Print(
         "Risk volume normalization failed. New entry is rejected."
      );

      return;
   }

   PrintFormat(
      "Risk sizing | equity=%G | risk_percent=%G | planned_risk=%G | reference_volume=%G | reference_loss=%G | raw_volume=%G | normalized_volume=%G | volume_min=%G | volume_max=%G | volume_step=%G",
      sizingResult.equity,
      g_riskSettings.riskPercent,
      sizingResult.plannedRiskAmount,
      sizingResult.referenceVolume,
      sizingResult.lossForReferenceVolume,
      sizingResult.rawVolume,
      normalizedVolume,
      g_symbolCapabilities.volumeMin,
      g_symbolCapabilities.volumeMax,
      g_symbolCapabilities.volumeStep
   );
}

void OnDeinit(const int reason)
{
   ReleaseStrategyIndicators();

   PrintFormat("XAUForge deinitialized. Reason: %d", reason);
}
