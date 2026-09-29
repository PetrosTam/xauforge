datetime g_lastBarOpenTime = 0;

bool IsNewBar()
{
   const datetime currentBarOpenTime = iTime(_Symbol, _Period, 0);

   if(currentBarOpenTime == 0)
      return(false);

   if(currentBarOpenTime == g_lastBarOpenTime)
      return(false);

   g_lastBarOpenTime = currentBarOpenTime;

   return(true);
}

int OnInit()
{
   ResetLastError();

   g_lastBarOpenTime = iTime(_Symbol, _Period, 0);

   if(g_lastBarOpenTime == 0)
   {
      PrintFormat(
         "Failed to initialize current bar time. Error: %d",
         GetLastError()
      );

      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

void OnTick()
{
   if(!IsNewBar())
      return;

   PrintFormat(
      "New bar detected at %s",
      TimeToString(g_lastBarOpenTime, TIME_DATE | TIME_MINUTES)
   );
}

void OnDeinit(const int reason)
{
   PrintFormat("XAUForge deinitialized. Reason: %d", reason);
}
