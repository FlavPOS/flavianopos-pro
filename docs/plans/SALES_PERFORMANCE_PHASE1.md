SALES PERFORMANCE MODULE - PHASE 1 EXECUTION PLAN
===================================================
Target: v1.0.60+136 through v1.0.62+145
Duration: 3 weeks
Approach: Fix foundation first, then build features

APPROACH RATIONALE:
- Full spec has 43 sections estimated at 3-6 months solo development
- Phase 1 scope: bug fixes + 4 core sub-modules + basic exports
- Deferred: alerts, commissions, promotions, cloud functions, webhooks,
  monthly performance, dedicated void/refund/exchange history screens
- Full spec preserved in SALES_PERFORMANCE_FULL_SPEC.md as north star

WEEK 1 - FOUNDATION (BUG FIXES)
===================================================

v1.0.60+136 - Fix Void/Refund Inventory Restore (Days 1-2)
- Debug why v133 _restoreStock not running
- Verify BranchInventoryService.incrementStock properly called
- Ensure Firebase sync completes
- Test end-to-end with real transactions
- Console logs [VOID-REFUND-STOCK] must appear

v1.0.60+137 - Fix Duplicate Transactions (Day 3)
- Investigate total=8 doubling to 16
- Add deduplication logic in _allTransactions
- Ensure Firebase sync does not create duplicates
- Sales History shows one row per unique transaction

v1.0.60+138 - Fix Exchange Item Screen (Days 4-5)
- Apply v133 pattern to exchange_screen.dart
- Return old items via BranchInventoryService.incrementStock
- Deduct new items via BranchInventoryService.decrementStock
- Test even, positive, negative exchange scenarios

v1.0.60+139 - Cleanup and Prep (Days 6-7)
- Remove verbose BRANCH-SCOPE-DEBUG logs
- Code review
- Prepare for Sales Performance rename
- Update audit documentation

WEEK 2 - CORE SCREENS
===================================================

v1.0.61+140 - Rename Module (Day 8)
- Sales History renamed to Sales Performance everywhere
- Route updates
- Navigation menu updates
- Icons and titles updates
- Keep backward compatible URL redirects

v1.0.61+141 - Current Sales Sub-module (Days 9-11)
- Summary cards: Gross Sales, Net Sales, Transactions, Avg Value
- Sales by payment method chart
- Top selling items today list
- Recent transactions feed
- Real-time refresh via Firebase listener
- Hourly sales breakdown chart

v1.0.61+142 - Transaction History Sub-module (Days 12-14)
- Enhanced from current Sales History
- Server-side or indexed pagination
- Advanced filters: date range, cashier, payment method, status
- Search by receipt number or transaction ID
- Detail panel with items breakdown
- Export CSV, PDF

WEEK 3 - ANALYTICS AND POLISH
===================================================

v1.0.62+143 - Daily Performance Sub-module (Days 15-17)
- Snapshot metrics for selected date
- Comparison with previous day
- Comparison with same weekday previous week
- Hourly trend chart
- Category breakdown
- Best sellers of the day
- Export report

v1.0.62+144 - Weekly Performance Sub-module (Days 18-19)
- Week aggregation
- Daily breakdown chart
- Best performing day
- Worst performing day
- Comparison with previous week
- Weekly trend visualization

v1.0.62+145 - Exports and Polish (Days 20-21)
- CSV export for all screens
- Excel export for all screens
- PDF export for all screens with report metadata
- Bug fixes from testing
- Documentation updates
- Final ship of stable Phase 1

DEFERRED TO PHASE 2 AND BEYOND
===================================================

Phase 2 candidates (3-6 months out):
- Monthly Performance sub-module
- Dedicated Void History screen
- Dedicated Refund History screen
- Dedicated Exchange History screen
- Basic alert triggers (void rate, refund rate)
- Enhanced audit trail
- Better real-time performance

Phase 3 candidates (6-12 months out):
- Full alert engine with risk scoring
- Commission ledger with clawbacks
- Promotion snapshot logic
- Cloud Functions for aggregations
- Webhook system
- Full accessibility WCAG 2.1 AA
- Multi-currency support

SUCCESS CRITERIA FOR PHASE 1
===================================================

Week 1 (Bugs Fixed):
- Void restores inventory correctly
- Refund restores inventory correctly
- Exchange handles old return plus new deduct correctly
- Sales History shows no duplicates

Week 2 (Core Screens):
- Sales Performance module renamed and accessible
- Current Sales displays live data with real-time refresh
- Transaction History fully functional with filters

Week 3 (Analytics):
- Daily Performance shows accurate snapshot
- Weekly Performance shows week aggregation
- All exports work (CSV, Excel, PDF)
- User can navigate between sub-modules

Overall:
- Strict branch isolation maintained
- Firebase sync working
- No production bugs
- Ready for user testing

DEVELOPMENT PRINCIPLES
===================================================

- Ship incrementally, one version at a time
- Test each ship before moving to next
- Keep debug logs during development, clean up before Phase 1 close
- Document decisions in commit messages
- Update this plan file as we progress
- Track daily progress
- Take breaks between rounds

RISK MITIGATION
===================================================

Risk: Bug fix reveals deeper problem
Mitigation: Time-box each fix to 1 day max, escalate if longer

Risk: Feature scope creep during Weeks 2-3
Mitigation: Stick to plan, defer additions to Phase 2

Risk: Fatigue over 3 weeks
Mitigation: Rest between rounds, one to two versions per day max

Risk: User requests during development
Mitigation: Note requests in this plan, address in Phase 2

TRACKING
===================================================

Progress will be tracked by:
- Version numbers shipped
- Bugs identified and fixed
- Sub-modules completed
- Tests passed
- User feedback collected

Update this file at end of each week with actual progress.

Start Date: 2026-07-15
Estimated Completion: 2026-08-05

Ready to start Week 1, Day 1: v1.0.60+136 (Fix Void/Refund Inventory)


PROGRESS LOG
===================================================

WEEK 1 - DAY 1 - 2026-07-15 - COMPLETE
---------------------------------------------------

v1.0.60+136 - Fix Refund Inventory Restore - SHIPPED

Root Cause Discovered:
Two refund paths existed in the codebase:
1. transaction_detail_screen.dart - had v133 fix (working)
2. sales_history_screen.dart - had inline old code (BROKEN)

The sales_history_screen path used:
- Product.updateProduct (global master stock) - WRONG
- Not per-branch via BranchInventoryService - WRONG
- Not async - no Firebase sync - WRONG
- No debug logs - hard to diagnose

Fix Applied:
- Added imports for BranchInventoryService and DeviceAssignmentService
- Rewrote inline stock restore to use BranchInventoryService.incrementStock
- Made onPressed async to properly await inventory restore
- Reads branchId from DeviceAssignmentService
- Added debug logs [REFUND-HIST-STOCK]
- Firebase auto-syncs via BranchInventoryService

Verification:
Console logs confirm success:
- [VOID-REFUND-STOCK] Restored 1 x Coca-Cola 1.5L to HO001
- [VOID-REFUND-STOCK] Summary: 1 items restored to HO001
- [BINV-SYNC] SUCCESS: companies/101/branchInventory/HO001
- Branch stock increased correctly after refund

Lessons Learned:
- Comprehensive grep across ALL files needed for feature audit
- Two paths for same action = double the bug surface
- Function names not enough - also search for inline logic
- Cache clear valuable to rule out client-side issues first


NEXT: WEEK 1 - DAY 2 - 2026-07-16
---------------------------------------------------

Objectives:
- Additional v136 testing (multi-item refunds, multi-branch)
- Prepare v137 diagnostic for duplicate transactions bug
- Optionally start v137 investigation

Duplicate Transactions Bug (v137 target):
- Console shows total=8 doubling to 16
- Same TXN-ID appearing twice in Sales History
- Possible causes to investigate:
  * Firebase sync adds duplicate to _allTransactions
  * initState calling loadFromDB multiple times
  * Multiple Sales History screens in navigation stack


REMAINING WEEK 1 SCHEDULE
---------------------------------------------------

- Day 2 (2026-07-16): Test v136 + prepare v137
- Day 3 (2026-07-17): v137 - Fix duplicate transactions
- Days 4-5 (2026-07-18 to 07-19): v138 - Fix Exchange screen
- Days 6-7 (2026-07-20 to 07-21): v139 - Cleanup + Week 1 wrap

Week 1 goal: Foundation solid, all inventory bugs fixed


VERSION TRACKING
---------------------------------------------------

Shipped so far in Phase 1:
- v1.0.60+136 (Day 1) - SUCCESS

Remaining Phase 1 ships:
- v1.0.60+137 - duplicate transactions
- v1.0.60+138 - exchange screen fix
- v1.0.60+139 - cleanup
- v1.0.61+140 - rename module to Sales Performance
- v1.0.61+141 - Current Sales sub-module
- v1.0.61+142 - Transaction History sub-module
- v1.0.62+143 - Daily Performance sub-module
- v1.0.62+144 - Weekly Performance sub-module
- v1.0.62+145 - Exports and Polish


PHASE 1 SUCCESS METRICS - CURRENT STATUS
---------------------------------------------------

Bugs Fixed:
- [x] Refund from Sales History LIST - inventory restore (v136)
- [ ] Void from Transaction Detail - inventory restore
- [ ] Duplicate transactions in list
- [ ] Exchange screen inventory API

Sub-modules Complete:
- [ ] Sales Performance module renamed
- [ ] Current Sales sub-module
- [ ] Transaction History sub-module
- [ ] Daily Performance sub-module
- [ ] Weekly Performance sub-module

Exports Working:
- [ ] CSV
- [ ] Excel
- [ ] PDF

Foundation Solid:
- [x] Branch isolation (v131-132)
- [x] Refund inventory (v136)
- [ ] Void inventory (v137)
- [ ] Exchange inventory (v138)
- [ ] No duplicates (v137)



WEEK 1 - DAY 2 - 2026-07-15 - COMPLETE
---------------------------------------------------

v1.0.60+137 - Fix Duplicate Transactions - SHIPPED

Root Cause Discovered:
Exchange screen (exchange_screen.dart) uses DatabaseHelper directly
to update SQLite (bypasses Transaction model). Sales History uses
Transaction.branchScopedTransactions from _allTransactions list.

When cache reloaded (via CacheReloadHelper or app operations),
loadFromDB was called multiple times. Original code did:
1. _allTransactions = []
2. Loop and add rows
But subsequent calls didn't have full deduplication guard.

Fix Applied:
1. loadFromDB now uses Set to track seen IDs during load
2. Uses temp list, then atomic replacement (no partial state)
3. addTransaction checks for existing ID before insert
4. Debug logs [TXN-LOAD] and [TXN-DEDUP] for verification
5. Defense in depth - fixes any current or future caller

Verification:
Console logs confirm success:
- [TXN-LOAD] Loaded 13 unique transactions (called 2x, still 13)
- Sales History count stays consistent: 4 own transactions
- No more 8-to-16 doubling behavior

Lessons Learned:
- Multiple screens/services call loadFromDB indirectly
- Defense in depth better than finding single root cause
- Set-based dedup is efficient and reliable
- Debug logs help verify fix works in production

PROGRESS FOR TODAY (2026-07-15):
- Ships: 2 (v136 refund + v137 duplicates)
- Bugs fixed: 2 of 4 Week 1 bugs
- Time invested: ~4 hours focused work
- Pace: AHEAD of schedule


REMAINING WEEK 1
---------------------------------------------------

- Day 3 (2026-07-16): v138 - Exchange screen inventory API
- Day 4 (2026-07-17): v138 testing + polish
- Day 5 (2026-07-18): v139 - Cleanup + Week 1 wrap

PHASE 1 SUCCESS METRICS - UPDATED
---------------------------------------------------

Bugs Fixed:
- [x] Refund from Sales History LIST - inventory restore (v136)
- [x] Duplicate transactions in list (v137)
- [ ] Void from Transaction Detail - inventory restore
- [ ] Exchange screen inventory API

Progress: 2 of 4 = 50% Week 1 bugs fixed
