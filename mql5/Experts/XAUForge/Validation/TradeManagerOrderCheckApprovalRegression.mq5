#property strict

// Deterministic regression for the Phase 7 OrderCheck approval rule.
// No OrderCheck or OrderSend calls; only synthetic inputs.
#include <XAUForge/TradeManager.mqh>

int g_passed = 0;
int g_failed = 0;

void CheckApprovalCase(const string name, const bool condition)
{
   if(condition)
      g_passed++;
   else
      g_failed++;

   PrintFormat(
      "ORDER_CHECK_APPROVAL_TEST_%s | case=%s",
      condition ? "PASS" : "FAIL",
      name
   );
}

int OnInit()
{
   CheckApprovalCase(
      "true_zero_approved",
      IsOrderCheckApproved(true, 0)
   );

   CheckApprovalCase(
      "false_zero_rejected",
      !IsOrderCheckApproved(false, 0)
   );

   CheckApprovalCase(
      "false_no_money_rejected",
      !IsOrderCheckApproved(false, (uint)TRADE_RETCODE_NO_MONEY)
   );

   CheckApprovalCase(
      "true_nonzero_rejected",
      !IsOrderCheckApproved(true, (uint)TRADE_RETCODE_INVALID)
   );

   PrintFormat(
      "ORDER_CHECK_APPROVAL_TEST_RESULT | passed=%d | failed=%d | total=%d",
      g_passed,
      g_failed,
      g_passed + g_failed
   );

   return(g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED);
}

void OnTick()
{
}
