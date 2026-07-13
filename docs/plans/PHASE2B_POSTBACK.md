Phase 2B - Auto-Postback v1.0.58+112

STATUS
Design Locked
Est Time 60-90 min
Prerequisite Phase 2A verified v1.0.57+111 shipped and working
Ship Target Tomorrow morning

GOAL
When receiver confirms partial receive with reason RETURN
1 Return short qty to issuer inventory
2 Update issuer ProductBatch plus qty
3 Update postbackQty field on transfer_item_batches
4 Firebase sync both branches

REASON BEHAVIOR
RETURN - Postback YES HO001 gets plus qty back
DAMAGED - Postback NO local write-off
MISSING - Postback NO investigation flag
EXTRA_PACKED overage - No action
BONUS overage - No action
UNKNOWN overage - No action

FILES TO MODIFY
1 lib/screens/inventory_transfer/inbound_receive_screen.dart
   Add postback loop after batch save line 305
   Est 50 lines added

KEY LOGIC
For each batch if reason equals RETURN
   postbackAmount equals rb.short
   ProductBatch.findExistingBatch at issuerBranchId
   if found addQuantityToBatch plus postbackAmount
   else create new ProductBatch with source POSTBACK
   BranchInventoryService.incrementStock issuer product amount
   Insert stock_movements entry with type POSTBACK_IN

TESTING PLAN
Test 1 RETURN reason triggers postback expect postbackQty greater than 0
Test 2 MISSING reason does NOT postback postbackQty stays 0
Test 3 DAMAGED reason does NOT postback
Test 4 Overage reasons NEVER postback
Test 5 Mixed batches only RETURN ones postback
Test 6 Cross-branch sync HO001 sees updated inventory

SUCCESS CRITERIA
Firebase shows postbackQty for RETURN reasons
HO001 batches table has POSTBACK entries
HO001 stock_movements has POSTBACK_IN audit
HO001 SOH increased by postback amount
Multi-device incognito verified

TOMORROW SHIP SEQUENCE
1 Read this file cat docs/plans/PHASE2B_POSTBACK.md
2 Ask Copilot Phase 2B time
3 Copilot will regenerate the Python patch
4 Apply patch
5 Verify grep for v1.0.58 marker
6 flutter analyze
7 Version bump to 1.0.58+112
8 flutter build web release
9 firebase deploy only hosting
10 git commit and push
11 Run tests 1 through 6
12 Screenshot Firebase Console with postbackQty greater than 0

TODAY LEGACY 2026-07-13
11 versions shipped in ONE day
Phase 1 COMPLETE
Phase 2A COMPLETE and VERIFIED
Enterprise batch reconciliation LIVE
Multi-branch Firebase sync working with variance
Phase 2B tomorrow equals full ERP feature done
