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
