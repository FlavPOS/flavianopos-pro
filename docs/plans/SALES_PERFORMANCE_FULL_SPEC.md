Build a Production-Ready "Sales Performance" Module

ROLE

Act as a senior retail ERP architect, POS domain expert, database engineer, and full-stack developer.

Design and implement a complete, production-ready Sales Performance module for a multi-branch Point-of-Sale and Retail Inventory system.

The module must be suitable for real-world retail operations, financial reporting, loss prevention, management approval workflows, and audit compliance.

Do not create a mock-up-only solution. The delivered module must include:

- Production-ready data models
- Database schema and relationships
- Business/service layer
- API or repository functions
- Complete frontend screens and components
- Role-based permissions
- Immutable audit logging
- Real-time updates
- Pagination, filtering, searching, sorting, and exports
- Loading, empty, offline, and error states
- Automated tests
- Clear integration instructions

Do not omit any existing code or replace working project logic unnecessarily. Use minimal, non-destructive changes when integrating into an existing project.

If an existing project is provided:

1. Inspect its architecture, models, services, database paths, naming conventions, state management, authentication, and UI theme.
2. Reuse existing transaction, product, branch, staff, shift, inventory, payment, refund, void, and exchange models where appropriate.
3. Do not create conflicting duplicate services or sources of truth.
4. Preserve backward compatibility.
5. Return complete copy-paste-ready files, not incomplete snippets or pseudocode.
6. Clearly list all created and modified files.

==================================================
TECHNOLOGY STACK — SPECIFIED FOR THIS PROJECT
(overrides any generic default stack)
==================================================

This project's persistence model is fixed and must be used as-is —
do NOT substitute PostgreSQL/Prisma or any other server-only
relational database:

- Local device database: SQLite (per terminal/device, offline-first;
  every branch device reads and writes locally first)
- Cloud database: Firebase (Firestore recommended as the default —
  state this assumption clearly and confirm Firestore vs. Realtime
  Database before implementation if not already decided)
- Synchronization: A custom bidirectional sync engine between SQLite
  and Firebase supporting multiple devices per branch and multiple
  branches per company. Full architecture, schema, conflict
  resolution, security rules, and required confirmations are
  specified in Section 43 — read Section 43 before designing any
  data-access layer.
- Authentication: Firebase Authentication with custom claims (or a
  rules-validated permissions document) encoding role and branch
  scope.
- Frontend: state and confirm the platform/framework (e.g.,
  Flutter/Dart is common for this SQLite+Firebase multi-device POS
  pattern) if not already fixed by an existing project provided.
- Charts, Excel export, PDF export, CSV export: use
  platform-appropriate libraries for the confirmed frontend stack;
  CSV must remain standards-compliant UTF-8 regardless of platform.

Before implementation, state all architectural assumptions. Ask
questions only when a missing detail would make implementation
unsafe or incompatible — otherwise proceed using clearly documented
assumptions. At minimum, explicitly confirm or assume the items
listed in Section 43.13 (Firestore vs. Realtime Database, whether
Firestore's own offline cache is used alongside the custom SQLite
layer or not at all, frontend platform, and expected branch/device/
transaction volume) before writing implementation code.

If an existing project is provided, use its existing SQLite schema,
Firebase project structure, authentication setup, and existing PIN/
approval workflow rather than introducing a second, conflicting
persistence pattern.

==================================================
1. PRIMARY OBJECTIVE
==================================================

Build one cohesive Sales Performance module containing eight dedicated sub-modules:

1. Current Sales
2. Transaction History
3. Daily Performance
4. Weekly Performance
5. Monthly Performance
6. Void History
7. Refund History
8. Exchange Item History

All eight sub-modules must use the same canonical transaction data source and shared business rules.

Each sub-module must still have:

- Its own screen or route
- Dedicated filters
- Dedicated summary cards
- Dedicated table or detail view
- Dedicated chart or analysis, where applicable
- Dedicated export function
- Permission-aware actions
- Responsive mobile and desktop layouts

Do not calculate financial figures independently in multiple UI components. Centralize all sales, void, refund, exchange, tax, discount, and net-sales calculations in a shared reporting or domain service.

==================================================
2. REQUIRED FINANCIAL DEFINITIONS
==================================================

Apply consistent financial definitions throughout the module.

Gross Sales:
Sum of item selling prices multiplied by quantities before transaction-level discounts, refunds, and voids. Clearly document whether item-level discounts are included or excluded.

Discounts:
Sum of authorized item-level and transaction-level discounts.

Net Completed Sales Before Returns:
Gross Sales minus discounts, excluding fully voided transactions.

Void Amount:
Value removed from a transaction through a full or partial void.

Refund Amount:
Actual value returned to the customer through cash, original payment method, e-wallet, card reversal, or store credit.

Exchange Difference:
Value of replacement items minus value of returned items.

- Positive value: customer pays an additional amount.
- Negative value: customer receives a refund or store credit.
- Zero: even exchange.

Net Sales Performance:
Completed Sales
- Void Amount
- Refund Amount
+ Positive Exchange Collections
- Negative Exchange Refunds

Tax:
Use the project's existing tax-inclusive or tax-exclusive rules. Never double-deduct tax during refunds, voids, or exchanges.

Average Transaction Value:
Net completed sales divided by the number of valid completed transactions.

Total Items Sold:
Net quantity of completed items after subtracting refunded, voided, and returned quantities according to the selected reporting policy.

Void Rate:
Number of voided transactions divided by the number of eligible transactions, multiplied by 100.

Refund Rate:
Refund amount divided by completed sales amount, multiplied by 100.

Sales vs. Loss Ratio:
Completed sales compared with the combined value of voids and refunds.

All reports must state which transaction statuses and adjustment records are included in each metric.

==================================================
3. SHARED DATA AND SOURCE-OF-TRUTH RULES
==================================================

Use one canonical transaction record and separate immutable adjustment records for:

- Voids
- Refunds
- Exchanges

Do not overwrite or delete the original completed transaction when a refund, exchange, or post-payment void is performed.

Each adjustment must reference:

- Company ID
- Branch ID or branch code
- Original transaction ID
- Original receipt number
- Original line-item ID, where applicable
- Shift ID
- Business date
- Effective date and time
- Staff ID
- Approver ID, when required
- Reason code
- Reason description
- Monetary impact
- Inventory impact
- Before and after status
- Source device or terminal
- Created timestamp
- Sync status, if offline support exists

Use stable IDs and idempotency keys to prevent duplicate void, refund, exchange, inventory, or payment records when operations are retried.

Branch data must be strictly isolated. A branch user must not view or modify another branch's records unless granted Head Office, Regional, or Administrator access.

Use the business date and shift date for store reporting. Do not rely only on the device's calendar date because a shift may cross midnight.

Store timestamps in UTC and convert them to the configured branch timezone in the UI and reports.

==================================================
4. SUB-MODULE 1 — CURRENT SALES
==================================================

Purpose:
Display sales occurring today or during the active business day and shift in near real time.

Required summary cards:

- Gross sales
- Net sales
- Total completed transactions
- Total items sold
- Average transaction value
- Total discounts
- Total refunds
- Total voids
- Exchange difference
- Cash expected
- Sales target progress, if a target is configured

Required data views:

- Sales by payment method
- Sales by cashier or staff
- Top-selling items
- Top-selling categories
- Hourly sales trend
- Recent transactions
- Active shift information
- Active terminal information, when applicable

Active shift information must include:

- Shift ID
- Branch
- Terminal
- Opened by
- Opening time
- Opening cash
- Business date
- Current expected cash
- Shift status

Required functions:

- getCurrentSalesSummary(context)
- getSalesByPaymentMethod(dateOrBusinessDate, filters)
- getSalesByCashier(dateOrBusinessDate, filters)
- getTopSellingItemsToday(limit, filters)
- getTopSellingCategoriesToday(limit, filters)
- getHourlySalesBreakdown(dateOrBusinessDate, filters)
- getRecentTransactions(limit, filters)
- refreshCurrentSales()
- subscribeToCurrentSales()
- unsubscribeFromCurrentSales()
- getActiveShiftInfo(branchId, terminalId)
- getExpectedCashForActiveShift(shiftId)

Real-time behavior:

- Prefer WebSocket, Firebase listener, or Server-Sent Events.
- If unavailable, use configurable polling, defaulting to 15–30 seconds.
- Prevent duplicate subscriptions and memory leaks.
- Show the last successful refresh time.
- Show an offline/stale-data indicator if updates fail.
- Refresh current-sales metrics immediately after a sale, void, refund, or exchange.

==================================================
5. SUB-MODULE 2 — TRANSACTION HISTORY
==================================================

Purpose:
Provide a complete searchable and auditable log of transactions.

Required transaction fields:

- Transaction ID
- Receipt number
- Company
- Branch
- Terminal
- Shift ID
- Business date
- Transaction date and time
- Cashier or staff
- Customer, if applicable
- Items purchased
- Quantity
- Unit price
- Gross subtotal
- Item discount
- Transaction discount
- Tax
- Net total
- Tender details
- Payment method
- Change amount
- Status
- Related void, refund, or exchange references
- Sync status
- Created and updated timestamps

Supported statuses:

- Pending
- Held
- Completed
- Partially Voided
- Voided
- Partially Refunded
- Refunded
- Partially Exchanged
- Exchanged
- Cancelled

Required functions:

- getTransactionHistory(filters, pagination, sorting)
- getTransactionById(transactionId)
- searchTransactions(query, filters)
- getTransactionItemsDetail(transactionId)
- getTransactionAdjustments(transactionId)
- exportTransactionHistory(filters, format)
- printReceiptCopy(transactionId)
- sortTransactions(field, order)
- paginateTransactions(page, pageSize)
- reprintReceipt(transactionId, authorizedStaffId)
- getTransactionAuditTrail(transactionId)

Required filters:

- Date range
- Business date
- Branch
- Terminal
- Shift
- Cashier
- Customer
- Payment method
- Transaction status
- Minimum amount
- Maximum amount
- Product or SKU
- Receipt number
- Adjustment type
- Sync status

Required table behavior:

- Server-side pagination
- Server-side filtering
- Server-side sorting
- Configurable page size
- Sticky header
- Responsive columns
- Expandable item details
- Clear filter button
- Saved filter state during navigation
- Accurate total record count

==================================================
6. SUB-MODULE 3 — DAILY PERFORMANCE
==================================================

Purpose:
Show a performance snapshot for one selected business date.

Required metrics and views:

- Gross sales
- Net sales
- Total discounts
- Total voids
- Total refunds
- Net exchange difference
- Total transactions
- Total items sold
- Average transaction value
- Sales by hour
- Sales by category
- Sales by product
- Sales by payment method
- Best-selling items
- Lowest-selling items
- Comparison with previous business day
- Comparison with the same weekday in the previous week
- Target versus actual, if configured

Required functions:

- getDailyPerformance(date, filters)
- compareDailyPerformance(date1, date2, filters)
- getDailySalesByCategory(date, filters)
- getDailySalesByProduct(date, filters)
- getDailyBestSellers(date, limit, filters)
- getDailyPerformanceTrend(startDate, endDate, filters)
- exportDailyReport(date, format, filters)

Comparison outputs must include:

- Current value
- Comparison value
- Absolute difference
- Percentage difference
- Direction: increase, decrease, or unchanged
- Safe handling when the comparison value is zero

==================================================
7. SUB-MODULE 4 — WEEKLY PERFORMANCE
==================================================

Purpose:
Aggregate performance for a selected week.

Week configuration must support:

- Monday-to-Sunday
- Sunday-to-Saturday
- Configurable first day of week
- Branch-local timezone
- Partial current week

Required metrics and views:

- Gross sales
- Net sales
- Total transactions
- Total items sold
- Total discounts
- Total voids
- Total refunds
- Net exchange difference
- Daily breakdown
- Best-performing day
- Worst-performing day
- Average daily sales
- Comparison with previous week
- Sales by category
- Sales by product
- Sales by payment method
- Staff performance
- Weekly target attainment

Required functions:

- getWeeklyPerformance(weekStartDate, filters)
- compareWeeklyPerformance(week1, week2, filters)
- getWeeklyDailyBreakdown(weekStartDate, filters)
- getBestWorstDayOfWeek(weekStartDate, filters)
- getWeeklyTrend(numberOfWeeks, filters)
- exportWeeklyReport(weekStartDate, format, filters)

Do not incorrectly compare a partial current week with a full previous week. Provide an option to compare equal elapsed days.

==================================================
8. SUB-MODULE 5 — MONTHLY PERFORMANCE
==================================================

Purpose:
Aggregate performance for a selected calendar or fiscal month.

Required metrics and views:

- Gross sales
- Net sales
- Total transactions
- Total items sold
- Total discounts
- Total voids
- Total refunds
- Net exchange difference
- Weekly breakdown
- Daily calendar heatmap
- Best-performing week
- Worst-performing week
- Best-performing day
- Worst-performing day
- Average daily sales
- Comparison with previous month
- Comparison with the same month in the previous year
- Sales by category
- Sales by product
- Top 10 products
- Staff performance
- Monthly target attainment

Required functions:

- getMonthlyPerformance(month, year, filters)
- compareMonthlyPerformance(monthYear1, monthYear2, filters)
- getMonthlyWeeklyBreakdown(month, year, filters)
- getMonthlyCalendarHeatmap(month, year, filters)
- getMonthlyTopProducts(month, year, limit, filters)
- getMonthlyTrend(numberOfMonths, filters)
- exportMonthlyReport(month, year, format, filters)

The calendar heatmap must:

- Use the correct number of days in the month.
- Respect leap years.
- Distinguish zero-sales days from missing or unavailable data.
- Show sales totals and transaction counts in the tooltip.
- Use accessible colors and labels.

==================================================
9. SUB-MODULE 6 — VOID HISTORY
==================================================

Purpose:
Track full and partial voids for accountability and loss prevention.

Required fields:

- Void ID
- Company
- Branch
- Terminal
- Shift
- Business date
- Original transaction ID
- Original receipt number
- Void date and time
- Void type: full or line-item
- Voided items
- Voided quantity
- Amount before void
- Amount voided
- Tax impact
- Discount impact
- Inventory impact
- Voided by
- Approved by
- Reason code
- Reason description
- Status before void
- Status after void
- Approval status
- Idempotency key
- Audit timestamp

Required functions:

- getVoidHistory(filters, pagination, sorting)
- getVoidById(voidId)
- voidTransaction(transactionId, reason, approverId)
- voidLineItem(transactionId, itemId, quantity, reason, approverId)
- getVoidSummaryByStaff(dateRange, filters)
- getVoidSummaryByReason(dateRange, filters)
- getVoidRate(dateRange, filters)
- exportVoidHistory(format, filters)
- getVoidAuditTrail(voidId)

Void rules:

- Prevent voiding more than the remaining eligible quantity or value.
- Prevent duplicate voids.
- Distinguish pre-payment cancellation from post-payment void.
- Recalculate tax and discounts proportionally and consistently.
- Restore inventory exactly once when the void should return stock.
- Restore the correct SKU, branch, batch, lot, and expiry allocation.
- Record whether the item is returnable to saleable inventory.
- Require an approver when configured thresholds are exceeded.
- Never physically delete the transaction.

==================================================
10. SUB-MODULE 7 — REFUND HISTORY
==================================================

Purpose:
Track all customer refunds and their financial and inventory effects.

Required fields:

- Refund ID
- Company
- Branch
- Terminal
- Shift
- Business date
- Original transaction ID
- Original receipt number
- Refund date and time
- Refunded items
- Quantity
- Original unit price
- Discount allocation
- Tax allocation
- Refund amount
- Refund method
- Payment reference
- Processed by
- Approved by
- Reason code
- Reason description
- Customer information
- Inventory disposition
- Approval status
- Idempotency key
- Audit timestamp

Supported refund methods:

- Cash
- Original payment method
- Card reversal
- E-wallet reversal
- Store credit
- Gift card
- Other configured method

Required functions:

- getRefundHistory(filters, pagination, sorting)
- getRefundById(refundId)
- processRefund(transactionId, items, amount, method, reason, approverId)
- getRefundSummaryByReason(dateRange, filters)
- getRefundSummaryByProduct(dateRange, filters)
- getRefundRate(dateRange, filters)
- getTotalRefundAmount(dateRange, filters)
- exportRefundHistory(format, filters)
- getRefundAuditTrail(refundId)

Refund rules:

- Do not allow cumulative refunded quantity to exceed purchased quantity minus previous voids, refunds, and exchanges.
- Do not allow the refundable value to exceed the remaining paid value.
- Allocate item and transaction discounts correctly.
- Allocate tax according to the original transaction.
- Validate refund method against the original tender and business policy.
- Restore inventory only when the returned item is marked saleable.
- Send damaged or defective returns to the appropriate non-saleable stock location or adjustment reason.
- Update the transaction status to partially refunded or refunded.
- Keep refund records immutable. Corrections must use reversal or compensating records.

==================================================
11. SUB-MODULE 8 — EXCHANGE ITEM HISTORY
==================================================

Purpose:
Track item-for-item exchanges with no, positive, or negative cash movement.

Required fields:

- Exchange ID
- Company
- Branch
- Terminal
- Shift
- Business date
- Original transaction ID
- Original receipt number
- Exchange date and time
- Returned items
- Returned quantities
- Returned value
- Return inventory disposition
- Replacement items
- Replacement quantities
- Replacement value
- Price difference
- Difference settlement method
- Processed by
- Approved by
- Reason code
- Reason description
- Customer information
- Approval status
- Idempotency key
- Audit timestamp

Required functions:

- getExchangeHistory(filters, pagination, sorting)
- getExchangeById(exchangeId)
- processExchange(
    transactionId,
    returnedItems,
    newItems,
    staffId,
    reason,
    approverId,
    settlementMethod
  )
- calculatePriceDifference(returnedItems, newItems)
- getExchangeSummaryByReason(dateRange, filters)
- getMostExchangedItems(dateRange, limit, filters)
- exportExchangeHistory(format, filters)
- getExchangeAuditTrail(exchangeId)

Exchange rules:

- Calculate the remaining exchangeable quantity from the original purchase.
- Use the original net paid value of the returned item unless policy explicitly permits current pricing.
- Positive difference: create an additional payment transaction.
- Negative difference: create a refund, store-credit, or approved balance record.
- Zero difference: record an even exchange.
- Returned inventory and replacement inventory must update atomically.
- Returned defective items must not automatically become saleable stock.
- Replacement items must use the correct batch or lot based on the project's inventory policy, such as FEFO.
- Update transaction and item statuses without deleting the original transaction.
- Prevent repeated processing caused by double-clicks or network retries.

==================================================
12. CROSS-MODULE FUNCTIONS
==================================================

Implement these shared functions:

- getModuleDashboardSummary(filters)
- getNetSalesPerformance(dateRange, filters)
- getStaffPerformanceComparison(dateRange, filters)
- getSalesVsLossRatio(dateRange, filters)
- applyGlobalFilters(dateRange, branch, staff, paymentMethod)
- exportFullSalesPerformanceReport(dateRange, format, filters)
- getPerformanceTargets(dateRange, filters)
- getAdjustmentRiskIndicators(dateRange, filters)
- getReportMetadata(filters)
- validateReportTotals(dateRange, filters)

The top-level dashboard must combine:

- Current sales
- Net sales
- Transaction count
- Average transaction value
- Items sold
- Void amount and rate
- Refund amount and rate
- Exchange activity
- Sales versus loss ratio
- Best-performing staff
- Best-selling products
- Recent high-risk adjustments
- Daily, weekly, and monthly trends

Provide drill-down behavior from every summary card and chart into the relevant filtered sub-module.

==================================================
13. GLOBAL FILTERS
==================================================

Create one shared filter bar that can be applied across applicable screens.

Required global filters:

- Company
- Region
- Branch
- Terminal
- Business date
- Date range
- Shift
- Staff or cashier
- Payment method
- Transaction status
- Product
- SKU
- Category
- Customer
- Adjustment reason
- Minimum amount
- Maximum amount

Requirements:

- Role-aware branch options
- Clear-all function
- Apply function
- Active-filter count
- Filter chips
- Persist filters while navigating among sub-modules
- Optional saved filter presets
- URL/query-string synchronization for web implementations
- No accidental querying across unauthorized branches

==================================================
14. AUTHENTICATION, AUTHORIZATION, AND APPROVALS
==================================================

Implement role-based access control.

Example roles:

- Cashier
- Supervisor
- Manager
- Branch Administrator
- Regional Manager
- Head Office
- System Administrator
- Auditor

Example permissions:

- salesPerformance.view
- salesPerformance.export
- transactions.view
- transactions.reprint
- void.create
- void.approve
- void.view
- refund.create
- refund.approve
- refund.view
- exchange.create
- exchange.approve
- exchange.view
- audit.view
- crossBranch.view

Approval rules must support:

- Amount thresholds
- Quantity thresholds
- Specific reason codes
- High-risk products
- Cross-shift operations
- Refunds without receipts
- Transactions older than a configured number of days
- Self-approval restrictions

Do not allow the initiating staff member to approve their own action when separation of duties is enabled.

Approval credentials must be validated securely. Never store or log raw PINs or passwords.

==================================================
15. IMMUTABLE AUDIT TRAIL
==================================================

Every sensitive action must produce an immutable audit event.

Audit events must include:

- Event ID
- Event type
- Entity type
- Entity ID
- Company
- Branch
- Terminal
- Shift
- Acting user
- Approving user
- Action
- Reason
- Before state or relevant snapshot
- After state or relevant snapshot
- Timestamp
- Device ID
- Application version
- Correlation ID
- Idempotency key
- IP address, where applicable
- Sync status
- Optional cryptographic hash or chain reference

Audit records must not be editable through the normal application.

If a correction is required, create a new compensating event instead of modifying the original audit event.

==================================================
16. INVENTORY INTEGRATION
==================================================

Voids, refunds, and exchanges must update inventory in real time and exactly once.

Required behavior:

- Full void: restore all eligible quantities.
- Partial void: restore only the voided quantity.
- Refund: restore stock only if the return disposition is saleable.
- Exchange return: increase appropriate return inventory.
- Exchange replacement: decrease saleable inventory.
- Defective return: move to damaged, quarantine, or non-saleable stock.
- Batch-tracked products: update the exact original or selected batch.
- FEFO products: replacement items should follow FEFO allocation.
- Multi-branch operations: stock changes must affect only the authorized branch.
- Inventory movement and adjustment record must share a correlation ID.
- The UI must refresh after stock changes.
- Retries must not duplicate inventory movement.

Where transactions, inventory, payment, and audit records cannot share one database transaction, implement a reliable consistency mechanism such as an outbox pattern, idempotent event processing, or compensating transaction workflow.

==================================================
17. DATABASE SCHEMA
==================================================

Provide a complete database schema or equivalent Firebase collection/path design.

At minimum, account for:

- companies
- regions
- branches
- terminals
- users
- roles
- permissions
- user_roles
- shifts
- customers
- products
- categories
- product_batches
- transactions
- transaction_items
- transaction_discounts
- transaction_tenders
- voids
- void_items
- refunds
- refund_items
- exchanges
- exchange_return_items
- exchange_replacement_items
- inventory_movements
- approval_requests
- audit_events
- performance_targets
- report_exports
- reason_codes

For a relational or local SQLite database, provide:

- Primary keys
- Foreign keys
- Nullability
- Unique constraints
- Check constraints
- Decimal precision for monetary fields
- Indexes
- Composite indexes
- Soft-delete or active-state policy
- Created and updated timestamps
- Version or optimistic-lock column where necessary

Use decimal or integer-minor-unit storage for currency. Do not use binary floating-point types for financial values.

Recommended important indexes include:

- branch_id + business_date
- branch_id + transaction_timestamp
- receipt_number
- transaction_status
- staff_id + business_date
- payment_method + business_date
- original_transaction_id
- reason_code + business_date
- product_id + business_date
- shift_id
- idempotency_key
- correlation_id

Explain each table's purpose and relationships. See Section 43 for how this schema maps across SQLite (local) and Firebase (cloud).

==================================================
18. API OR SERVICE CONTRACTS
==================================================

Provide a complete REST, GraphQL, repository, or service endpoint map for all required functions.

For REST, include routes such as:

- GET /sales-performance/dashboard
- GET /sales-performance/current
- GET /sales-performance/current/hourly
- GET /sales-performance/current/payment-methods
- GET /sales-performance/current/cashiers
- GET /transactions
- GET /transactions/:id
- GET /transactions/:id/items
- GET /transactions/:id/audit-trail
- POST /transactions/:id/reprint
- GET /performance/daily
- GET /performance/weekly
- GET /performance/monthly
- GET /voids
- GET /voids/:id
- POST /transactions/:id/void
- POST /transactions/:id/items/:itemId/void
- GET /refunds
- GET /refunds/:id
- POST /transactions/:id/refunds
- GET /exchanges
- GET /exchanges/:id
- POST /transactions/:id/exchanges
- GET /reports/sales-performance/export

For each endpoint or service function, specify:

- Permission required
- Path parameters
- Query parameters
- Request body
- Response model
- Pagination format
- Sorting format
- Validation
- Possible error codes
- Idempotency behavior
- Audit behavior

Use consistent error responses, for example:

- code
- message
- fieldErrors
- correlationId
- timestamp

==================================================
19. FRONTEND COMPONENT STRUCTURE
==================================================

Create a responsive Sales Performance module with:

SalesPerformanceModule
├── SalesPerformanceShell
├── SalesPerformanceSidebar
├── SalesPerformanceHeader
├── GlobalPerformanceFilterBar
├── PerformanceDashboard
├── CurrentSalesView
├── TransactionHistoryView
├── DailyPerformanceView
├── WeeklyPerformanceView
├── MonthlyPerformanceView
├── VoidHistoryView
├── RefundHistoryView
├── ExchangeHistoryView
├── TransactionDetailPanel
├── AdjustmentDetailPanel
├── ApprovalDialog
├── ExportDialog
├── ReceiptPreview
├── AuditTrailPanel
└── SharedPerformanceComponents

SharedPerformanceComponents must include:

- MetricCard
- ComparisonMetricCard
- PerformanceChart
- CalendarSalesHeatmap
- PaginatedDataTable
- ResponsiveDetailPanel
- FilterChipBar
- EmptyState
- LoadingState
- ErrorState
- PermissionDeniedState
- OfflineState
- RefreshIndicator
- ExportProgressDialog
- ApprovalStatusBadge
- TransactionStatusBadge
- CurrencyText
- DateTimeText

Navigation must preserve active filters when switching between sub-modules.

==================================================
20. UI AND UX REQUIREMENTS
==================================================

Use a professional enterprise POS/ERP design.

Desktop layout:

- Persistent left navigation for the eight sub-modules
- Top header with page title, branch, business date, refresh status, and export action
- Global filter bar below the header
- Summary cards in a responsive grid
- Charts below the cards
- Paginated tables or analytics sections
- Detail panels or dialogs for records

Mobile layout:

- Collapsible navigation drawer
- Horizontally scrollable or stacked metrics
- Bottom-sheet filters
- Priority columns only in tables
- Tap-to-open detail cards
- Touch-friendly controls
- No horizontal overflow

Dashboard wireframe:

[Sales Performance] [Branch] [Business Date] [Last Updated] [Export]

[Global Filters: Date | Branch | Shift | Staff | Payment | Apply | Clear]

[Gross Sales] [Net Sales] [Transactions] [Average Transaction]
[Voids] [Refunds] [Exchange Difference] [Sales vs. Loss]

[Hourly/Daily Sales Trend Chart]
[Sales by Payment Method] [Top Products]

[Staff Performance]
[Recent Transactions]
[Recent High-Risk Voids, Refunds, and Exchanges]

History table wireframe:

[Page Title] [Search] [Filters] [Export]

[Active Filter Chips]

| Date/Time | Reference | Original Receipt | Staff |
| Type | Reason | Amount | Approver | Status | Actions |

[Expandable Items and Audit Details]

[Rows per Page] [Record Count] [Previous] [Page] [Next]

Avoid overcrowding. Use drill-down panels for secondary details.

==================================================
21. EXPORT REQUIREMENTS
==================================================

Support:

- CSV
- Excel
- PDF

CSV requirements:

- UTF-8 encoding
- Proper escaping
- Locale-safe dates
- Machine-readable headers

Excel requirements:

- Summary sheet
- Detail sheet
- Items sheet
- Adjustment sheets where applicable
- Filters
- Frozen header row
- Currency formatting
- Date/time formatting
- Totals
- Report metadata

PDF requirements:

- Company and branch header
- Report title
- Selected date range
- Applied filters
- Generation timestamp
- Generated by
- Summary section
- Detail section
- Page number
- Confidentiality or audit footer where appropriate
- Landscape orientation for wide tables
- Correct pagination without clipped columns

Exports must use the same backend or service calculations as the UI. Do not recalculate totals differently during export.

Large exports should run asynchronously and provide progress or a downloadable report record.

==================================================
22. PERFORMANCE AND RELIABILITY
==================================================

Requirements:

- Server-side (or local-index-backed) pagination for large history datasets
- Indexed queries
- Avoid loading all transactions into memory
- Debounced searching
- Cancel stale requests
- Cache summary queries safely
- Invalidate caches after mutations
- Prevent duplicate form submissions
- Optimistic UI only where financial correctness is not at risk
- Use database transactions for financial and inventory operations where possible
- Provide retry behavior for transient network failures
- Provide offline-aware behavior since this POS supports offline transactions by design (see Section 43)
- Reconcile local and server updates without duplicate records

Define expected pagination defaults and maximum page sizes.

Suggested defaults:

- Default page size: 25
- Available sizes: 10, 25, 50, 100
- Maximum API page size: 100
- Current-sales refresh interval: 15 seconds when push updates are unavailable

==================================================
23. CURRENCY, LOCALE, AND TIMEZONE
==================================================

Default configuration:

- Currency: Philippine Peso
- Currency symbol: ₱
- Currency code: PHP
- Locale: en-PH
- Timezone: Asia/Manila
- Standard date format: MM/dd/yyyy
- Standard time format: hh:mm a
- Combined display: MM/dd/yyyy hh:mm a

Keep currency and locale configurable per company or branch.

Store money using decimal values or integer centavos.

Never derive financial calculations from formatted currency strings.

==================================================
24. EDGE CASES
==================================================

Explicitly handle and test:

- Shift crossing midnight
- No active shift
- Multiple terminals in one branch
- Partial void
- Partial refund
- Partial exchange
- Multiple refunds against one transaction
- Multiple exchanges against one transaction
- Mixed payment methods
- Refund to more than one method
- Discounted products
- Transaction-level discounts
- Tax-inclusive pricing
- Tax-exclusive pricing
- Rounding differences
- Zero-value transactions
- Negative exchange difference
- Positive exchange difference
- Even exchange
- Transactions with deleted or inactive products
- Users who become inactive after a transaction
- Branch transfers mistakenly referenced as sales
- Duplicate requests
- Offline-created transactions
- Out-of-order sync events
- Failed inventory update after payment adjustment
- Failed payment reversal after inventory return
- Damaged returned merchandise
- Batch and expiry tracking
- Leap year
- Current partial day, week, or month
- Division by zero in comparisons
- Unauthorized cross-branch access
- Self-approval attempts
- Concurrent adjustment attempts on the same transaction

==================================================
25. TESTING REQUIREMENTS
==================================================

Provide:

- Unit tests for all financial formulas
- Unit tests for date-range calculations
- Unit tests for permission rules
- Unit tests for approval thresholds
- Unit tests for partial void, refund, and exchange calculations
- Repository or service tests
- API integration tests
- Database constraint tests
- UI component tests
- End-to-end tests for critical workflows
- Export validation tests
- Real-time refresh tests
- Inventory consistency tests
- Idempotency tests
- Branch-isolation tests

Critical end-to-end test scenarios:

1. Complete sale appears in Current Sales immediately.
2. Full void restores inventory exactly once.
3. Partial void restores only the selected quantity.
4. Refund of a saleable item restores inventory.
5. Refund of a damaged item does not increase saleable inventory.
6. Even exchange correctly moves both inventory items.
7. Positive exchange difference creates additional payment.
8. Negative exchange difference creates refund or store credit.
9. Unauthorized cashier cannot approve a protected adjustment.
10. Manager approval is recorded in the immutable audit trail.
11. Retried operations do not duplicate stock or financial adjustments.
12. Branch users cannot access another branch's data.
13. UI, Excel, PDF, and CSV totals match.
14. Current Sales refreshes after void, refund, and exchange.

==================================================
26. REQUIRED DELIVERABLES
==================================================

Deliver the solution in this order:

1. Architecture summary
2. Assumptions
3. Financial definitions
4. Database schema and relationship explanation (SQLite + Firebase, per Section 43)
5. API or service endpoint map
6. Permissions and approval rules
7. Frontend route and component structure
8. Main dashboard wireframe
9. History-table wireframe
10. Business and inventory workflows
11. Complete production-ready implementation files
12. Database migrations and Firebase security rules/indexes (see Section 43)
13. Test files
14. Export implementation
15. Installation and integration steps
16. Created and modified file list
17. Verification checklist
18. Known limitations, if any

Do not return pseudocode when implementation code is requested.

Do not use placeholders such as:

- "Implement this later"
- "Add your logic here"
- "Existing code goes here"
- "..."
- "TODO"

Every delivered source file must be complete, compilable, null-safe where applicable, and ready to copy and paste.
==================================================
28. NOTIFICATIONS, ALERTS, RISK SCORING &
    ANOMALY DETECTION
==================================================

Purpose:

Proactively identify unusual sales, void, refund, exchange, approval,
inventory, and staff behavior without requiring managers to manually
inspect history tables.

The alerting system must support:

- Deterministic threshold-based rules
- Time-window rules
- Pattern-based rules
- Statistical anomaly detection
- Duplicate or repeated-action detection
- Role-specific notification routing
- Escalation and SLA monitoring
- Alert acknowledgment and resolution
- False-positive classification
- Configurable suppression and cooldown periods
- Historical alert analysis
- Explainable alert scoring

Do not use opaque anomaly results without explaining why a record was
flagged.

--------------------------------------------------
28.1 REQUIRED ALERT TRIGGERS
--------------------------------------------------

Thresholds must be configurable per:

- Company
- Region
- Branch
- Terminal
- Shift
- Staff role
- Adjustment type
- Product or category
- Payment method
- Date or time window

Required triggers include:

1. Void rate exceeds a configured percentage within a shift, day,
   week, or rolling time window.

2. Refund rate exceeds a configured percentage or amount within a
   shift, day, week, or rolling time window.

3. Exchange count, exchange amount, or negative exchange difference
   exceeds a configured threshold.

4. A single staff member exceeds a configured void, refund, or
   exchange count or amount.

5. An adjustment occurs:
   - Outside configured business hours
   - Outside the staff member's assigned shift
   - After the shift is closed
   - On a transaction from another terminal
   - On a transaction from another branch
   - Beyond the permitted return or adjustment period

6. Repeated voids, refunds, or exchanges involve:
   - The same transaction
   - The same SKU
   - The same customer
   - The same payment reference
   - The same staff and approver pairing
   - Repeated amounts just below the approval threshold

7. Refund is requested:
   - Without a receipt
   - Against a mismatched receipt
   - Against an already fully adjusted transaction
   - For a quantity exceeding the remaining refundable quantity
   - Using a different customer identity without authorization

8. Exchange has a negative price difference above a configured amount.

9. A high-value or high-risk item is repeatedly voided, refunded, or
   exchanged.

10. Sales performance falls below a configured target milestone, such
    as below 70 percent of the expected target by midday.

11. Sales increase or decrease beyond a configured statistical
    threshold compared with:
    - Rolling average
    - Same weekday average
    - Previous comparable shift
    - Previous week
    - Previous month
    - Seasonal baseline, when available

12. Approval remains pending beyond a configured SLA.

13. The same approver approves an unusually high number or value of
    adjustments from the same staff, terminal, or team.

14. A staff member attempts to approve their own adjustment.

15. A protected action is repeatedly denied because of invalid PIN,
    insufficient permission, or expired credentials.

16. Inventory restoration or deduction fails after a successful
    void, refund, or exchange.

17. Financial adjustment succeeds but its corresponding inventory,
    payment, audit, commission, or webhook operation is incomplete.

18. Duplicate idempotency keys, duplicate references, or conflicting
    concurrent adjustment attempts are detected.

19. Shift cash discrepancy exceeds the configured tolerance.

20. Real-time sales data becomes stale or the branch stops sending
    expected transaction updates (including a device that has stopped
    syncing — see Section 43.6).

--------------------------------------------------
28.2 ALERT SEVERITY AND LIFECYCLE
--------------------------------------------------

Required severity levels:

- Informational
- Low
- Medium
- High
- Critical

Required alert statuses:

- Open
- Acknowledged
- Under Investigation
- Escalated
- Resolved
- Dismissed as False Positive
- Auto-Resolved

Required lifecycle fields:

- Alert ID
- Rule ID
- Rule version
- Company ID
- Region ID
- Branch ID
- Terminal ID
- Shift ID
- Staff ID
- Approver ID
- Entity type
- Entity ID
- Transaction ID
- Alert category
- Severity
- Risk score
- Human-readable explanation
- Triggered metrics
- Threshold values
- Detection window
- First detected time
- Last detected time
- Occurrence count
- Due time or SLA deadline
- Assigned user or team
- Acknowledged by and time
- Resolution code
- Resolution note
- Resolved by and time
- Deep-link route
- Correlation ID
- Created and updated timestamps

Alerts must not be physically deleted through normal application
functions.

False-positive classification must not modify or delete the source
transaction, adjustment, inventory movement, approval, or audit event.

--------------------------------------------------
28.3 STAFF RISK SCORE
--------------------------------------------------

Implement an explainable composite staff-risk score.

Possible inputs include:

- Void count and value
- Refund count and value
- Exchange count and negative differences
- Void/refund rate relative to staff sales
- After-hours activity
- Adjustments outside assigned shifts
- Repeated activity involving the same SKU or customer
- Approval concentration
- Invalid approval attempts
- Transactions just below approval thresholds
- Shift cash discrepancies
- Comparison with branch and role peer averages

Risk-score requirements:

- Configurable factor weights
- Score range documented, such as 0–100
- Risk band: Low, Medium, High, or Critical
- Score explanation showing contributing factors
- Minimum sample-size requirement
- Protection against misleading scores for new or low-volume staff
- Historical score trend
- Role and branch peer comparison
- Permission-controlled visibility
- No automatic disciplinary action based only on a risk score
- Manual review workflow for high-risk scores

Required functions:

- getActiveAlerts(filters, pagination, sorting)
- getAlertById(alertId)
- acknowledgeAlert(alertId, userId, note)
- assignAlert(alertId, assigneeId)
- escalateAlert(alertId, userId, escalationLevel, note)
- resolveAlert(alertId, userId, resolutionCode, resolutionNote)
- dismissAlertAsFalsePositive(alertId, userId, note)
- configureAlertRule(ruleId, configuration, scope)
- enableAlertRule(ruleId)
- disableAlertRule(ruleId)
- testAlertRule(ruleId, sampleOrHistoricalData)
- getAlertHistory(dateRange, filters, pagination)
- getStaffRiskScore(staffId, dateRange)
- getStaffRiskScoreBreakdown(staffId, dateRange)
- evaluateAlertsForEvent(eventId)
- reevaluateAlerts(dateRange, ruleId)
- getAlertSlaSummary(filters)

--------------------------------------------------
28.4 DELIVERY CHANNELS
--------------------------------------------------

Required delivery channels:

- In-app notification center
- Navigation badge
- Dashboard High-Risk Activity widget
- Branch-manager alert queue
- Regional and Head Office rollup
- Optional email integration
- Optional SMS integration
- Optional mobile push integration
- Optional Microsoft Teams, Slack, or webhook integration hook

Delivery requirements:

- Configurable by severity, role, company, and branch
- User notification preferences
- Quiet hours with critical-alert override
- Delivery status tracking
- Deduplication
- Retry with exponential backoff
- Failed-delivery logging
- Read and unread state
- Deep link to the source record
- Escalation if not acknowledged within SLA

--------------------------------------------------
28.5 ALERT STORAGE
--------------------------------------------------

Add or account for:

- alert_rules
- alert_rule_versions
- alerts
- alert_occurrences
- alert_assignments
- alert_actions
- staff_risk_scores
- notification_preferences
- notification_deliveries

Alert rules must be stored in configuration and editable by authorized
administrators without a code deployment.

Every rule or threshold change must generate an immutable settings
audit event with the previous and new configuration.

==================================================
29. STAFF INCENTIVES, COMMISSIONS & CLAWBACKS
==================================================

Purpose:

Ensure incentive and commission calculations reconcile correctly with
later voids, refunds, exchanges, discounts, and promotional
adjustments.

This section is optional and must be controlled by a feature flag.

If the business does not use incentives or commissions:

- State "Not Applicable" in the Assumptions.
- Disable related routes and UI elements.
- Do not create unnecessary commission records.
- Preserve the ability to enable the feature later through migration
  and configuration.

--------------------------------------------------
29.1 COMMISSION RULES
--------------------------------------------------

Support configurable commission bases:

- Net completed sales
- Gross sales
- Gross profit or margin, if cost data is available and authorized
- Quantity sold
- Product-specific amount
- Category-specific percentage
- Staff-specific rate
- Team or branch target achievement
- Tiered performance target
- Combination rules

Net completed sales must be the default commission basis.

Commission rules must support:

- Effective start and end dates
- Rule priority
- Product scope
- Category scope
- Staff or role scope
- Branch scope
- Minimum margin requirement
- Daily, weekly, or monthly thresholds
- Caps
- Tiered percentages
- Excluded items and categories
- Excluded payment methods
- Excluded transaction types
- Waiting or vesting period before commission becomes payable
- Approval rules
- Rule-version snapshot at the time of calculation

--------------------------------------------------
29.2 IMMUTABLE COMMISSION LEDGER
--------------------------------------------------

Commission entries must never be silently overwritten.

Required entry types:

- Earned
- Pending
- Approved
- Payable
- Paid
- Clawback
- Positive Adjustment
- Negative Adjustment
- Reversal
- Expired
- Disputed

When a commission-eligible transaction is later voided, refunded, or
exchanged:

- Preserve the original commission record.
- Create a linked clawback or adjustment record.
- Reference the original transaction and commission entry.
- Calculate the adjustment only against the affected quantity or
  value.
- Prevent duplicate clawbacks using an idempotency key.
- Recalculate target progress where necessary.
- Preserve payroll-period history.

Required fields include:

- Commission entry ID
- Company ID
- Branch ID
- Staff ID
- Transaction ID
- Transaction item ID
- Adjustment ID
- Commission rule ID
- Rule-version snapshot
- Commission basis
- Eligible amount
- Rate
- Calculated amount
- Entry type
- Status
- Payroll period
- Effective date
- Correlation ID
- Idempotency key
- Created timestamp
- Approved by and time

Required functions:

- getCommissionSummary(staffId, dateRange, filters)
- getCommissionLedger(staffId, dateRange, filters)
- getCommissionClawbacks(staffId, dateRange)
- getCommissionEntryById(entryId)
- calculateCommissionForTransaction(transactionId)
- recalculateCommissionOnAdjustment(adjustmentId)
- getIncentiveTargetProgress(staffId, dateRange)
- approveCommissionAdjustment(entryId, approverId)
- disputeCommissionEntry(entryId, staffId, reason)
- resolveCommissionDispute(entryId, approverId, resolution)
- exportCommissionReport(dateRange, filters, format)

Add or account for:

- commission_rules
- commission_rule_versions
- commission_entries
- commission_adjustments
- incentive_targets
- incentive_achievements
- commission_disputes
- payroll_periods

==================================================
30. PROMOTIONS, BUNDLES, COMBOS, COUPONS &
    GIFT-WITH-PURCHASE ADJUSTMENT LOGIC
==================================================

Purpose:

Prevent financial, tax, discount, and inventory errors when adjusting
items purchased under a promotion.

--------------------------------------------------
30.1 PROMOTION SNAPSHOT
--------------------------------------------------

Every transaction using a promotion must store an immutable snapshot of:

- Promotion ID
- Promotion name
- Promotion type
- Rule version
- Eligibility conditions
- Included and excluded products
- Required quantities
- Discount calculation method
- Discount allocation per line
- Free-item rules
- Coupon code or reference
- Start and end dates at time of sale
- Branch scope
- Customer eligibility
- Gift-with-purchase obligations
- Stackability rules
- Approval or override details

Historical adjustments must use the stored snapshot, not the current
promotion configuration.

--------------------------------------------------
30.2 SUPPORTED PROMOTION TYPES
--------------------------------------------------

Account for:

- Percentage discount
- Fixed discount
- Item-level markdown
- Transaction-level discount
- Buy X, Get Y
- Buy X, Get Y at a discount
- Bundle or combo fixed price
- Mix-and-match
- Tiered quantity discount
- Coupon
- Loyalty redemption
- Member pricing
- Gift with purchase
- Free shipping or service benefit, where applicable
- Manual manager override discount

--------------------------------------------------
30.3 PARTIAL ADJUSTMENT RULES
--------------------------------------------------

For each partial void, refund, or exchange:

1. Determine which promotion groups are affected.

2. Calculate the remaining eligible items.

3. Validate whether the remaining transaction still satisfies the
   original promotion.

4. Reallocate the original promotional discount proportionally or
   according to the original promotion rule.

5. Preserve deterministic rounding so item allocations reconcile to
   the exact original discount.

6. If promotion eligibility is broken:
   - Reprice the remaining transaction using the original promotion
     snapshot;
   - Recover the invalid discount;
   - Deduct the recovered discount from the refund;
   - Require an additional payment;
   - Require return of the free item;
   - Or block the adjustment pending authorized manager override,
     according to configured policy.

7. Record the promotional impact as part of the adjustment audit
   snapshot.

Gift-with-purchase policies must support:

- Gift must be returned.
- Gift value is deducted from the refund.
- Gift may be retained with manager approval.
- Gift becomes a separately priced sale.
- Gift is marked damaged or unavailable for return.

Required functions:

- getPromotionSnapshot(transactionId)
- getPromotionGroups(transactionId)
- recalculatePromotionOnPartialAdjustment(
    transactionId,
    affectedItems,
    adjustmentType
  )
- validateBundleIntegrityBeforeAdjustment(
    transactionId,
    itemsBeingAdjusted
  )
- calculateDiscountRecovery(transactionId, affectedItems)
- validateGiftReturnRequirement(transactionId, affectedItems)
- applyPromotionOverride(
    transactionId,
    adjustmentId,
    approverId,
    reason
  )
- getPromotionImpactReport(dateRange, filters)
- getPromotionAdjustmentAudit(adjustmentId)

Add or account for:

- promotion_snapshots
- transaction_promotion_groups
- transaction_promotion_items
- promotion_adjustment_impacts
- promotion_overrides
- gift_return_requirements

Required tests must include:

- Partial return of a bundle
- Return of the qualifying item but not the free item
- Return of the free item only
- Buy-two-get-one-free allocation
- Coupon plus item promotion
- Rounding across multiple discounted items
- Exchange within a bundle
- Full adjustment of all promotional items
- Manager override of a broken promotion

==================================================
31. CASH DRAWER, SHIFT CLOSE &
    RECONCILIATION LINKAGE
==================================================

Purpose:

Ensure cash-impacting sales adjustments reconcile with shift close,
cash count, expected drawer value, and cash discrepancy reporting.

--------------------------------------------------
31.1 CANONICAL EXPECTED-CASH FORMULA
--------------------------------------------------

Use one shared reconciliation service.

The default formula is:

Expected Cash =
Opening Cash
+ Cash Sales Collected
+ Positive Cash Exchange Differences
+ Cash Pay-Ins
- Cash Refunds
- Negative Cash Exchange Differences Paid in Cash
- Cash Paid-Outs
- Cash Drops
- Cash Removed for Deposits
+/- Approved Cash Adjustments

Treatment of voids must depend on transaction settlement status:

- Pre-settlement cancellation:
  No cash was collected, so it must not increase expected cash.

- Post-settlement cash void with immediate cash return:
  Subtract the returned cash through a linked cash-impact record.

- Post-settlement void reversed electronically:
  Do not alter physical cash unless physical cash actually moved.

Never "add back voided cash sales" without considering whether the
cash was collected and whether it was returned. Expected cash must be
derived from actual cash movements, not only transaction statuses.

--------------------------------------------------
31.2 SHIFT RECONCILIATION DATA
--------------------------------------------------

Required shift reconciliation fields:

- Reconciliation ID
- Company ID
- Branch ID
- Terminal ID
- Shift ID
- Business date
- Opening cash
- Cash sales
- Cash refunds
- Cash exchange collections
- Cash exchange payouts
- Pay-ins
- Paid-outs
- Cash drops
- Deposits
- Other approved adjustments
- Expected cash
- Counted cash
- Over or short amount
- Tolerance
- Discrepancy status
- Counted by
- Approved by
- Notes
- Correlation ID
- Closed timestamp
- Reopened timestamp, if applicable
- Reopen approver and reason

Required functions:

- getShiftCashReconciliation(shiftId)
- calculateExpectedCash(shiftId)
- getCashImpactingAdjustments(shiftId)
- getCashMovements(shiftId)
- recordShiftDiscrepancy(
    shiftId,
    expectedAmount,
    countedAmount,
    note,
    approverId
  )
- approveShiftDiscrepancy(reconciliationId, approverId, note)
- reopenShiftReconciliation(
    reconciliationId,
    approverId,
    reason
  )
- getReconciliationHistory(dateRange, filters)
- exportShiftReconciliation(shiftId, format)
- validateShiftReconciliation(shiftId)

Requirements:

- Shift-close calculations must use canonical transaction, tender,
  refund, exchange, and cash-movement records.
- The shift cannot silently close with unresolved critical financial
  inconsistencies.
- Configurable tolerance must determine whether manager approval is
  required.
- Reopening a shift or reconciliation must require permission and an
  immutable audit event.
- Counted denominations must reconcile to the counted-cash total.
- Each discrepancy must appear in management and risk reporting.

Add or account for:

- cash_movements
- shift_reconciliations
- shift_discrepancies
- denomination_counts
- shift_reopen_events

==================================================
32. SECURITY, COMPLIANCE, PRIVACY &
    DATA PROTECTION
==================================================

--------------------------------------------------
32.1 AUTHENTICATION AND AUTHORIZATION
--------------------------------------------------

All endpoints, listeners, subscriptions, exports, background jobs,
and download URLs must enforce authorization server-side.

Never trust:

- Hidden buttons
- Client-side route guards
- Client-supplied company IDs
- Client-supplied branch IDs
- Client-supplied role names
- Cached permissions without server validation

Required controls:

- Short-lived access tokens
- Secure refresh-token rotation where applicable
- Token revocation
- Forced logout
- Session termination after role or employment changes
- Device-session visibility
- Configurable idle timeout
- Multi-factor authentication readiness
- Brute-force protection
- Approval-PIN lockout and cooldown
- Permission-denied audit logging
- Separation of duties
- Self-approval prevention
- Step-up authentication for high-risk actions

--------------------------------------------------
32.2 PAYMENT AND CUSTOMER DATA
--------------------------------------------------

Never store:

- Full card number
- CVV
- Raw magnetic-stripe data
- Raw payment credentials
- Plaintext approval PIN
- Plaintext user password

Store only:

- Tokenized payment reference
- Gateway transaction reference
- Payment brand
- Masked account or card suffix
- Payment status
- Authorized financial metadata

Sensitive fields must be:

- Encrypted at rest
- Encrypted in transit
- Masked in logs
- Permission-masked in the UI
- Masked or excluded from exports by default
- Protected from unauthorized search

--------------------------------------------------
32.3 INPUT AND OUTPUT SECURITY
--------------------------------------------------

Apply:

- Server-side schema validation
- Allow-list validation
- Parameterized SQL or safe ORM queries
- NoSQL query sanitization
- XSS protection
- Content Security Policy for web deployments
- CSRF protection where cookie-based authentication is used
- Secure file-name handling
- File type and size validation
- Export access control
- Signed, time-limited download URLs
- API request-size limits
- Rate limiting
- Request timeouts
- Safe error messages without stack traces or secrets

CSV exports must be protected against formula injection.

If a cell begins with a dangerous spreadsheet character such as:

- =
- +
- -
- @

the export service must safely encode or prefix the value according to
the documented export policy.

This sanitization must be tested.

--------------------------------------------------
32.4 PRIVACY AND DATA SUBJECT REQUESTS
--------------------------------------------------

Support privacy workflows where legally required:

- Customer data access request
- Customer correction request
- Customer anonymization request
- Export of customer-linked data
- Consent or lawful-basis tracking where applicable
- Data-processing audit log

Financial and audit records that must legally be retained must not be
deleted in a way that destroys audit integrity.

Where deletion is not permitted:

- Anonymize customer-identifying fields.
- Preserve required financial values.
- Preserve transaction and audit references.
- Record the anonymization action.
- Retain legal-hold records.

--------------------------------------------------
32.5 SECURITY TESTING
--------------------------------------------------

Provide tests for:

- Horizontal privilege escalation
- Vertical privilege escalation
- Cross-company leakage
- Cross-branch leakage
- Spoofed branch ID
- Expired and revoked tokens
- Self-approval
- Approval brute force
- SQL and NoSQL injection attempts
- XSS payloads
- CSV formula injection
- Unauthorized export
- Unauthorized receipt reprint
- Unauthenticated real-time subscription
- Sensitive-data leakage in logs
- Signed download-link expiration
- Request replay and duplicate submissions

==================================================
33. ACCESSIBILITY, LOCALIZATION &
    INTERNATIONALIZATION
==================================================

The module must target WCAG 2.1 AA where feasible.

Required accessibility behavior:

- Keyboard-accessible navigation
- Logical focus order
- Visible focus indicators
- Skip-navigation support on web
- Screen-reader labels
- Accessible names for icon-only buttons
- Table headers associated with data cells
- Accessible sorting announcements
- Dialog focus trap and focus restoration
- Accessible error summaries
- Sufficient color contrast
- Reduced-motion support
- Scalable text
- Touch targets of an appropriate size
- Accessible chart alternatives
- Text summary for every chart
- Pattern, icon, and text indicators in addition to color
- Heatmap values available in non-color format
- Status labels that do not rely only on red, green, or orange

Localization requirements:

- Use translation keys instead of hardcoded UI text.
- Initially support English and Filipino when required.
- Support adding languages without changing business logic.
- Localize dates, times, numbers, percentages, and currencies.
- Keep database reason codes language-neutral.
- Store translated reason labels separately.
- Support branch-specific timezone and locale.
- Support pluralization.
- Support long translated strings.
- Keep layouts ready for right-to-left presentation.
- Avoid hardcoded left/right positioning in reusable components.

Charts and exports must use the selected report locale while retaining
stable machine-readable codes where necessary.

Accessibility verification must include:

- Automated accessibility scanning where supported
- Keyboard-only review
- Screen-reader smoke test
- Color-contrast verification
- High-zoom or large-text review
- Mobile touch-target review

==================================================
34. DATA RETENTION, ARCHIVING, LEGAL HOLD,
    BACKUP & DISASTER RECOVERY
==================================================

--------------------------------------------------
34.1 RETENTION POLICY
--------------------------------------------------

Define configurable retention policies for:

- Transactions
- Transaction items
- Tenders
- Voids
- Refunds
- Exchanges
- Inventory movements
- Audit events
- Alerts
- Approval records
- Shift reconciliations
- Exported reports
- Notification delivery logs
- Webhook payloads
- Application logs
- Customer PII
- Commission records
- Configuration history

Policies must specify:

- Live-storage duration
- Archive-storage duration
- Deletion or anonymization policy
- Legal-hold behavior
- Responsible role
- Verification procedure

Retention values must be configuration-driven and approved against the
applicable accounting, tax, privacy, and organizational requirements.

Do not claim a universal fixed legal retention period without explicit
project requirements.

--------------------------------------------------
34.2 ARCHIVING
--------------------------------------------------

Archiving must:

- Be tenant-aware and branch-aware.
- Preserve relationships and references.
- Preserve original timestamps and audit hashes.
- Keep archived records queryable by authorized users.
- Support report regeneration.
- Support legal holds.
- Prevent archived data from degrading current dashboard performance.
- Provide archive-job status and failure logs.
- Verify record counts and checksums before live-data cleanup.
- Be idempotent.
- Support a documented restore process.

Archived records must be clearly identified in the UI.

--------------------------------------------------
34.3 BACKUP AND RECOVERY
--------------------------------------------------

Document:

- Backup frequency
- Backup retention
- Encryption
- Geographic redundancy where required
- Recovery Point Objective
- Recovery Time Objective
- Restore procedure
- Restore-testing frequency
- Responsible team
- Escalation path
- Post-recovery reconciliation

Suggested targets must be labeled as assumptions until approved.

--------------------------------------------------
34.4 MID-SHIFT OUTAGE PROCEDURE
--------------------------------------------------

Define behavior when the central database or network is unavailable:

- Local transaction queue
- Local adjustment restrictions
- Offline authorization policy
- Offline approval policy
- Local inventory reservation
- Idempotency keys assigned before sync
- Ordered synchronization
- Conflict detection
- Duplicate prevention
- Reconciliation report after reconnect
- Manual exception process
- Stale-data indicators
- Audit of offline events
- Device clock-drift handling

High-risk refunds, exchanges, or voids may be disabled offline unless an
approved offline workflow exists. See Section 43.7 for the full
SQLite/Firebase offline-operation policy for this project.

==================================================
35. SCHEDULED, AUTOMATED & SUBSCRIBED REPORTING
==================================================

Purpose:

Allow management reports to be generated and distributed automatically
using the same calculation services as on-demand reporting.

Supported report types:

- Daily Performance
- Weekly Performance
- Monthly Performance
- Current Shift Summary
- Void Summary
- Refund Summary
- Exchange Summary
- Staff Performance
- Branch Comparison
- Sales vs. Loss
- Alert and Risk Summary
- Shift Reconciliation
- Consolidated Sales Performance

Supported frequencies:

- Once
- Daily
- Weekly
- Monthly
- Fiscal period
- Custom cron-like schedule, when authorized

Required schedule settings:

- Schedule ID
- Company and branch scope
- Report type
- Report version
- Frequency
- Timezone
- Run time
- Day of week or month
- Filters
- Format
- Recipients
- Recipient roles
- Delivery channel
- Password-protection policy where applicable
- Enabled status
- Next run time
- Last run time
- Created by
- Updated by

Required functions:

- createReportSchedule(
    reportType,
    recipients,
    frequency,
    filters,
    format,
    deliveryChannel
  )
- getReportSchedules(userId, filters)
- getReportScheduleById(scheduleId)
- updateReportSchedule(scheduleId, changes)
- pauseReportSchedule(scheduleId)
- resumeReportSchedule(scheduleId)
- deleteReportSchedule(scheduleId)
- runReportScheduleNow(scheduleId)
- getScheduledReportRunHistory(scheduleId, pagination)
- retryScheduledReportRun(runId)
- cancelScheduledReportRun(runId)

Requirements:

- Scheduled and on-demand reports must call the same reporting service.
- Store a snapshot of filters and report configuration for every run.
- Prevent duplicate runs.
- Use timezone-aware scheduling.
- Handle daylight-saving changes for applicable timezones.
- Retry transient failures with bounded exponential backoff.
- Alert after repeated failures.
- Log generation and delivery separately.
- Do not email unprotected sensitive reports unless policy permits it.
- Store report checksums or hashes for reproducibility.
- Apply data-access permissions at execution time and delivery time.
- Handle disabled users and changed roles safely.

Add or account for:

- report_schedules
- report_schedule_recipients
- report_runs
- report_deliveries
- report_artifacts

==================================================
36. RECEIPT, SLIP & PRINT-TEMPLATE MANAGEMENT
==================================================

Purpose:

Provide auditable and configurable original, void, refund, exchange,
and reprint documents.

Supported templates:

- Original sales receipt
- Reprint receipt
- Full void slip
- Partial void slip
- Refund slip
- Exchange slip
- Store-credit slip
- Shift reconciliation report
- Adjustment approval copy

Template scope:

- Company
- Branch
- Terminal or printer type
- Locale
- Document type
- Effective date
- Version

Template configuration may include:

- Logo
- Company name
- Branch name and address
- Tax identifiers
- Header
- Footer
- Return policy
- Exchange policy
- Tax breakdown
- Cashier and approver display
- Barcode or QR code
- Signature lines
- Customer acknowledgment
- Copy count
- Printer width
- Font size
- Paper-cut instruction
- Optional transaction verification reference

Required formats:

- 58mm thermal
- 80mm thermal
- A4 PDF
- Screen preview
- Optional email-friendly PDF

Required document markers:

- VOID
- PARTIAL VOID
- REFUND
- PARTIAL REFUND
- EXCHANGE
- STORE CREDIT
- REPRINT — COPY

Every adjustment document must reference:

- Original receipt number
- Original transaction ID
- Adjustment reference number
- Adjustment date and time
- Items and quantities affected
- Financial impact
- Reason
- Processing staff
- Approver, when applicable
- Branch and terminal
- Copy or reprint status

Required functions:

- getReceiptTemplate(documentType, branchId, locale)
- previewReceiptTemplate(templateId, sampleData)
- createReceiptTemplate(configuration)
- updateReceiptTemplate(templateId, configuration)
- publishReceiptTemplate(templateId)
- archiveReceiptTemplate(templateId)
- printAdjustmentSlip(adjustmentId, documentType)
- reprintReceipt(transactionId, authorizedStaffId)
- reprintAdjustmentSlip(adjustmentId, authorizedStaffId)
- getPrintHistory(entityType, entityId)

Requirements:

- Published templates must be versioned.
- Historical reprints should use the applicable historical template
  snapshot or clearly identified current-template policy.
- Reprints must generate an audit event.
- Print failures and retries must be logged.
- Duplicate button presses must not create duplicate financial events.
- Printed totals must match the canonical service.
- Printer-unavailable behavior must not roll back an already committed
  financial adjustment.

Add or account for:

- receipt_templates
- receipt_template_versions
- print_jobs
- print_events
- document_snapshots

==================================================
37. API VERSIONING, THROTTLING, IDEMPOTENCY &
    WEBHOOKS
==================================================

--------------------------------------------------
37.1 API VERSIONING
--------------------------------------------------

Version all public and internal integration APIs, for example:

- /api/v1/sales-performance
- /api/v1/transactions
- /api/v1/voids
- /api/v1/refunds
- /api/v1/exchanges
- /api/v1/alerts
- /api/v1/reports
- /api/v1/webhooks

Define:

- Version support policy
- Deprecation policy
- Sunset notification
- Backward-compatibility rules
- Migration guide
- API schema or OpenAPI documentation

--------------------------------------------------
37.2 RATE LIMITING AND THROTTLING
--------------------------------------------------

Apply appropriate limits by:

- Tenant
- Branch
- Terminal
- User
- IP address
- API key
- Endpoint category

Use different policies for:

- Authentication
- Approval PIN
- Search
- Exports
- Real-time subscriptions
- Polling
- Financial mutations
- Webhook resend

Return structured rate-limit errors with retry information.

Polling clients must use backoff and must not create a request storm.

--------------------------------------------------
37.3 IDEMPOTENCY
--------------------------------------------------

Require idempotency keys for financial mutations, including:

- Sale completion
- Full void
- Partial void
- Refund
- Exchange
- Payment reversal
- Inventory movement
- Commission clawback
- Shift-close submission

The server must:

- Scope the key to the tenant and operation.
- Store request fingerprints.
- Return the original result for a valid retry.
- Reject key reuse with a conflicting payload.
- Record the final status.
- Support safe recovery from an interrupted request.

--------------------------------------------------
37.4 OUTBOUND WEBHOOKS
--------------------------------------------------

Supported events include:

- transaction.completed
- transaction.updated
- void.created
- refund.created
- exchange.created
- shift.opened
- shift.closed
- reconciliation.completed
- alert.created
- alert.resolved
- inventory.movement.created
- report.completed

Webhook payloads must include:

- Event ID
- Event type
- API version
- Schema version
- Company ID
- Branch ID
- Entity ID
- Event timestamp
- Correlation ID
- Idempotency key
- Payload
- Signature metadata

Security requirements:

- HMAC signature
- Timestamp in signature input
- Replay-window validation
- Secret rotation
- TLS endpoint requirement
- Optional IP allow-list
- Sensitive-field filtering

Delivery requirements:

- At-least-once delivery
- Receiver deduplication through event ID
- Exponential backoff
- Maximum retry policy
- Dead-letter state
- Manual resend
- Delivery logs
- Request and response metadata
- Masked sensitive headers
- Endpoint disablement after repeated failures
- Administrative test-delivery function

Required functions:

- createWebhookSubscription(configuration)
- updateWebhookSubscription(subscriptionId, changes)
- disableWebhookSubscription(subscriptionId)
- rotateWebhookSecret(subscriptionId)
- sendWebhookTest(subscriptionId)
- getWebhookDeliveries(filters, pagination)
- getWebhookDeliveryById(deliveryId)
- resendWebhookDelivery(deliveryId)
- verifyWebhookSignature(payload, timestamp, signature)

Add or account for:

- api_clients
- idempotency_records
- webhook_subscriptions
- webhook_secrets
- webhook_events
- webhook_deliveries
- webhook_delivery_attempts

==================================================
38. FEATURE FLAGS, SETTINGS &
    CONFIGURATION GOVERNANCE
==================================================

Optional and advanced functionality must be controlled through feature
flags and versioned configuration.

Possible feature flags:

- salesPerformance.enabled
- salesPerformance.realTime.enabled
- salesPerformance.alerts.enabled
- salesPerformance.anomalyDetection.enabled
- salesPerformance.commissions.enabled
- salesPerformance.promotions.enabled
- salesPerformance.scheduledReports.enabled
- salesPerformance.webhooks.enabled
- salesPerformance.crossBranchComparison.enabled
- salesPerformance.offlineAdjustments.enabled
- salesPerformance.staffRiskScore.enabled

Feature-flag scope:

- Global
- Company
- Region
- Branch
- Role
- User
- Terminal
- Percentage rollout

Configuration must include:

- Approval thresholds
- Return windows
- Void windows
- Exchange policies
- Cash-discrepancy tolerance
- Alert rules
- Risk-score weights
- Receipt templates
- Report schedules
- Retention policies
- Commission rules
- Export masking policies
- Real-time refresh intervals
- Week-start setting
- Currency, locale, and timezone

Required governance:

- Typed settings schema
- Validation before publication
- Draft and published versions
- Effective dates
- Rollback to prior version
- Permission-controlled editing
- Configuration preview
- Dependency validation
- Immutable change history
- Before-and-after snapshots
- Change reason
- Approval for high-risk settings
- Cache invalidation after publication

Required functions:

- getEffectiveFeatureFlags(context)
- evaluateFeatureFlag(flagKey, context)
- createConfigurationDraft(scope, values)
- validateConfigurationDraft(configurationId)
- publishConfiguration(configurationId, approverId)
- rollbackConfiguration(configurationId, targetVersion, approverId)
- getConfigurationHistory(scope, filters)
- getEffectiveConfiguration(scope, timestamp)
- compareConfigurationVersions(version1, version2)

Add or account for:

- feature_flags
- feature_flag_rules
- settings
- setting_versions
- setting_change_requests
- settings_audit_events

The application must fail safely when configuration is missing or
invalid. High-risk financial behavior must not default to an
unrestricted state.

==================================================
39. MULTI-TENANT, REGIONAL & HEAD-OFFICE
    CONSOLIDATION
==================================================

This section applies when the deployment supports multiple companies,
tenants, regions, or branches. This project is explicitly multi-branch
(see Section 43), so this section is applicable.

--------------------------------------------------
39.1 TENANT ISOLATION
--------------------------------------------------

Every tenant-owned record must carry a company or tenant identifier.

Tenant scope must be enforced in:

- Authentication claims
- Repository or data-access layer
- Database query filters
- Database security rules
- Real-time subscriptions
- Cache keys
- Background jobs
- Export generation
- Archived-data queries
- Webhook delivery
- Object-storage paths
- Audit queries
- Support tooling

Do not rely on UI filters for tenant isolation.

Where supported, use defense-in-depth such as:

- PostgreSQL row-level security
- Firebase Security Rules
- Tenant-specific service accounts
- Tenant-aware repository wrappers
- Separate encryption keys
- Tenant-aware storage prefixes

--------------------------------------------------
39.2 CONSOLIDATED REPORTING
--------------------------------------------------

Authorized Regional and Head Office users must be able to:

- View cross-branch summary cards
- Compare branches
- Rank branches
- Drill from company to region
- Drill from region to branch
- Drill from branch to terminal
- Drill from terminal to transaction
- Compare same-store performance
- Exclude newly opened or closed branches
- View consolidated sales and adjustment trends
- Export consolidated results

Required branch-comparison metrics:

- Gross sales
- Net sales
- Sales target attainment
- Transaction count
- Average transaction value
- Items per transaction
- Void count, value, and rate
- Refund count, value, and rate
- Exchange count and net difference
- Sales-vs-loss ratio
- Cash discrepancy
- Staff-risk indicators

Required functions:

- getHeadOfficeDashboard(filters)
- getRegionalDashboard(regionId, filters)
- getBranchPerformanceRanking(dateRange, metric, filters)
- compareBranches(branchIds, dateRange, metrics)
- getSameStorePerformance(dateRange, comparisonRange, filters)
- getConsolidatedAdjustmentSummary(dateRange, filters)
- exportConsolidatedPerformanceReport(dateRange, filters, format)

--------------------------------------------------
39.3 TENANT-ISOLATION TESTS
--------------------------------------------------

Tests must verify that Tenant A cannot access Tenant B through:

- Modified query parameters
- Modified request bodies
- Guessed IDs
- Direct detail endpoints
- Search endpoints
- Export jobs
- Download links
- Real-time channels
- Archived-data queries
- Webhook logs
- Cache collisions
- Background-job references
- File-storage paths

Tests must also verify branch and regional boundaries within the same
tenant.

==================================================
40. OBSERVABILITY, LOGGING, MONITORING &
    END-TO-END TRACEABILITY
==================================================

Purpose:

Allow engineering, operations, finance, audit, and support teams to
trace a transaction and its downstream effects without exposing
sensitive information.

--------------------------------------------------
40.1 STRUCTURED LOGGING
--------------------------------------------------

Use structured application logging rather than unstructured console
output.

Every relevant log must include:

- Timestamp
- Environment
- Service
- Application version
- Severity
- Event name
- Company ID, where safe
- Branch ID
- Terminal ID
- User ID
- Entity type
- Entity ID
- Request ID
- Correlation ID
- Trace ID
- Span ID
- Duration
- Outcome
- Error code
- Retry count

Logs must never contain:

- Passwords
- Approval PINs
- Access or refresh tokens
- Webhook secrets
- Encryption keys
- Full payment credentials
- Full unmasked customer PII
- Sensitive request bodies

--------------------------------------------------
40.2 REQUIRED METRICS
--------------------------------------------------

Emit metrics for:

- Request count
- API latency by endpoint
- API error rate
- Database query latency
- Slow-query count
- Authentication failures
- Approval failures
- Permission-denied attempts
- Transaction completion latency
- Void-processing latency
- Refund-processing latency
- Exchange-processing latency
- Inventory update latency
- Inventory consistency failures
- Real-time delivery latency
- Active real-time connections
- Stale branch data
- Export queue depth
- Export duration and failure rate
- Scheduled-report success rate
- Alert-rule evaluation latency
- Alerts by severity
- Webhook queue depth
- Webhook success and failure rate
- Offline queue depth
- Synchronization conflicts
- Shift-reconciliation discrepancies
- Idempotency conflicts

Metrics must be tenant-safe and must not expose sensitive transaction
details through labels.

--------------------------------------------------
40.3 DISTRIBUTED TRACEABILITY
--------------------------------------------------

A single correlation ID must connect, where applicable:

Sale
→ Payment
→ Transaction items
→ Inventory deduction
→ Commission creation
→ Audit event
→ Real-time notification
→ Webhook delivery
→ Void, refund, or exchange
→ Inventory restoration or replacement deduction
→ Payment reversal or additional collection
→ Promotion recalculation
→ Commission clawback
→ Shift cash impact
→ Alert evaluation
→ Export or report inclusion

Provide an authorized support trace view that shows:

- Timeline
- Component
- Event type
- Status
- Reference ID
- Duration
- Retry count
- Error code
- Linked audit event
- Linked inventory movement
- Linked payment event
- Linked webhook delivery

The trace view must mask sensitive information and must itself be
permission-controlled and audit-logged.

--------------------------------------------------
40.4 HEALTH AND READINESS
--------------------------------------------------

Provide:

- Liveness endpoint
- Readiness endpoint
- Database connectivity check
- Queue connectivity check
- Real-time service check
- Storage check
- Export-worker check
- Scheduler check

Health endpoints must not reveal secrets, internal stack traces, or
sensitive infrastructure details.

--------------------------------------------------
40.5 ALERTING AND OPERATIONAL RUNBOOKS
--------------------------------------------------

Operational alerts should cover:

- Elevated API errors
- Database unavailability
- Slow financial mutations
- Inventory consistency failures
- Export backlog
- Webhook backlog
- Scheduler failures
- Real-time update delays
- Offline queue growth
- High duplicate-request rate
- Cross-service reconciliation failure

Provide runbooks for:

- Payment completed but inventory failed
- Inventory changed but adjustment failed
- Duplicate adjustment suspected
- Branch offline for an extended period
- Scheduled reports repeatedly failing
- Webhook backlog
- Archive job failure
- Database recovery
- Shift close with unresolved discrepancy

==================================================
41. ACCEPTANCE CRITERIA
==================================================

The implementation is complete only when all original acceptance
criteria and the following advanced criteria are satisfied:

ALERTS AND RISK

- Alert rules fire correctly at configured thresholds.
- Alerts are scoped by tenant, region, branch, and role.
- Every alert deep-links to its source record.
- Alert acknowledgment does not modify the source audit record.
- Alert rule changes are audit-logged.
- Risk scores are explainable and show contributing factors.
- Risk scores do not automatically trigger disciplinary actions.
- Duplicate alert occurrences are grouped according to configured
  suppression and cooldown rules.

COMMISSIONS

- Commission functionality is feature-flagged.
- If commissions are not used, the feature is marked Not Applicable.
- Commission clawbacks are generated automatically after eligible
  voids, refunds, and exchanges.
- Historical commission records are never silently overwritten.
- Partial adjustments create proportional commission adjustments.
- Duplicate adjustment retries do not create duplicate clawbacks.

PROMOTIONS

- Every applied promotion has an immutable rule snapshot.
- Partial adjustments recalculate promotion effects correctly.
- Bundle discounts reconcile to the original exact discount.
- Free-item exploitation through a partial return is prevented.
- Gift-with-purchase policy is enforced.
- Promotion overrides require permission and are audit-logged.

SHIFT RECONCILIATION

- Expected cash is derived from canonical cash movements.
- Cash sales, refunds, exchange differences, pay-ins, paid-outs, cash
  drops, and deposits reconcile correctly.
- Pre-settlement and post-settlement voids are treated correctly.
- Shift discrepancies are immutable and approval-controlled.
- Denomination totals match counted-cash totals.
- Reopening a shift or reconciliation is audit-logged.

SECURITY AND PRIVACY

- Authentication and authorization are enforced server-side.
- Client-supplied tenant, company, branch, and role values are never
  trusted without server validation.
- No full payment credentials, CVV, raw card data, passwords, PINs,
  tokens, secrets, or encryption keys are stored in plaintext.
- Sensitive fields are masked in logs, UI surfaces, and exports
  according to permission.
- CSV exports are sanitized against formula injection.
- Approval and authentication endpoints are rate-limited.
- Revoked or expired sessions cannot access APIs or subscriptions.
- Permission-denied attempts are audit-logged.
- Privacy anonymization preserves legally required financial history.

ACCESSIBILITY AND LOCALIZATION

- Core workflows are keyboard-accessible.
- Status is never communicated through color alone.
- Charts provide accessible labels or text alternatives.
- Heatmaps remain understandable without color.
- Currency, date, number, and time formatting follow configuration.
- UI strings use an internationalization layer.
- The reusable layout is ready for right-to-left presentation.

RETENTION AND RECOVERY

- Retention policies are documented by record type.
- Archived records remain queryable by authorized users.
- Reports and audit records can be regenerated from archives.
- Archive jobs verify counts and integrity.
- Backup and restore procedures are documented and tested.
- Mid-shift outage and reconnect reconciliation are documented.
- Offline retries do not duplicate financial or inventory records.

SCHEDULED REPORTS

- Scheduled reports call the same calculation service as on-demand
  reports.
- Scheduled and on-demand totals match exactly for identical filters.
- Report generation and delivery are tracked separately.
- Failed runs retry according to policy.
- Repeated failures create an operational alert.
- Report runs store filter and configuration snapshots.
- Disabled users do not continue receiving unauthorized reports.

RECEIPTS AND PRINTING

- Void, refund, and exchange slips are visually distinct.
- Adjustment slips reference the original receipt.
- Thermal and A4 formats are supported where required.
- Reprints are labeled REPRINT — COPY.
- Every reprint is audit-logged.
- A printer failure does not duplicate or reverse a completed
  financial adjustment.
- Printed totals match canonical service totals.

API AND WEBHOOKS

- APIs are versioned.
- Financial mutations require idempotency keys.
- Conflicting reuse of an idempotency key is rejected.
- Rate limits protect polling, authentication, approval, export, and
  mutation endpoints.
- Webhook payloads are signed.
- Webhook receivers can deduplicate using event IDs.
- Failed webhook deliveries retry with backoff.
- Delivery logs are visible to authorized users.
- Manual resend is audit-logged.
- Webhook payloads include correlation IDs.

FEATURE FLAGS AND SETTINGS

- Optional functionality is controlled through feature flags.
- Effective flags are evaluated by scope.
- Approval thresholds and other sensitive settings are not hardcoded.
- Configuration changes include before-and-after values.
- Sensitive configuration changes require authorization.
- Configuration changes are audit-logged.
- Invalid or missing configuration fails safely.
- Published settings can be rolled back through an audited process.

MULTI-TENANT AND HEAD OFFICE

- Tenant scope is enforced in the data-access layer.
- Branch scope is enforced in queries and real-time subscriptions.
- Cross-tenant and cross-branch isolation is verified with automated
  tests.
- Consolidated dashboards reconcile to branch-level totals.
- Drill-down preserves tenant and branch authorization.
- Export and archive access cannot bypass tenant isolation.
- Cache keys and background jobs are tenant-aware.

OBSERVABILITY

- Structured logs include correlation IDs.
- Sensitive information is excluded from logs.
- Critical services expose safe health and readiness status.
- Metrics exist for API, database, export, webhook, alert, inventory,
  reconciliation, real-time, and synchronization operations.
- Authorized support users can trace a transaction end-to-end through
  one correlation ID.
- Access to support tracing is permission-controlled and audit-logged.
- Operational runbooks exist for critical failure scenarios.

SQLITE ⇄ FIREBASE SYNC (see Section 43)

- Every device generates collision-free IDs (UUID/ULID) for
  offline-created records.
- Two devices creating records offline simultaneously sync without
  ID collisions or duplicate financial records.
- Sync queue retries do not create duplicate Firebase documents
  (idempotency enforced at the Cloud Function layer).
- Firebase Security Rules reject writes with a spoofed branch_id.
- Offline-created records are permanently flagged as
  `created_offline: true`.
- Rollup documents used by dashboards correctly recompute after a
  late-arriving (backdated) offline sync.
- A schema-version mismatch between an app instance and Firebase
  blocks sync with a clear message rather than corrupting data.
- Head Office/Regional consolidated totals reconcile exactly to the
  sum of branch rollups and to the sum of individual synced device
  transactions.

FINAL RECONCILIATION

- Dashboard totals, history tables, receipts, shift reconciliation,
  CSV exports, Excel exports, PDF reports, scheduled reports, archived
  reports, and external webhook event amounts reconcile to the same
  canonical calculation services.
- No action can restore, deduct, refund, void, exchange, pay, or
  claw back the same value or quantity more than once.
- No working project feature is removed or broken.

==================================================
42. REQUIREMENT TRACEABILITY MATRIX
==================================================

Provide a completed traceability matrix for every requirement in
Sections 1–43.

At minimum, each traceability entry must contain:

- Requirement ID
- Requirement description
- Applicability
- Assumption or configuration dependency
- Feature flag
- SQLite table and Firebase collection/path (per Section 43)
- Schema field or index
- Migration or Firebase security-rule file
- Domain model
- Repository or data-access function
- Service or API function
- API endpoint
- Required permission
- Approval requirement
- Frontend route
- Frontend screen or component
- Background job, Cloud Function, or event handler
- Audit event
- Inventory impact
- Payment or cash impact
- Export or receipt impact
- Sync behavior (see Section 43)
- Unit test
- Integration test
- End-to-end test
- Security test
- Accessibility verification
- Monitoring or metric
- Implementation status
- Verification evidence
- Known limitation
- Follow-up action

Use these implementation-status values only:

- Not Started
- In Progress
- Implemented
- Verified
- Not Applicable
- Blocked

Do not mark a requirement Verified unless evidence is provided.

--------------------------------------------------
42.1 REQUIRED ADVANCED TRACEABILITY ENTRIES
--------------------------------------------------

For alerting, map:

Alert requirement
→ Alert-rule storage
→ Rule version
→ Evaluation service
→ Event source
→ Notification channel
→ UI surface
→ Permission
→ Audit event
→ Metric
→ Test case

For commission and clawback logic, map:

Commission requirement
→ Feature flag
→ Commission-rule table
→ Rule snapshot
→ Ledger entry
→ Clawback service
→ Payroll impact
→ Permission
→ Test case

For promotions, map:

Promotion requirement
→ Promotion snapshot
→ Promotion item allocation
→ Recalculation service
→ Manager override
→ Receipt impact
→ Audit event
→ Test case

For shift reconciliation, map:

Cash source
→ Cash movement
→ Reconciliation formula
→ Shift screen
→ Discrepancy record
→ Approval
→ Export
→ Test case

For security, map:

Security control
→ Threat addressed
→ Implementation location
→ Configuration
→ Audit event
→ Automated test
→ Manual verification
→ Monitoring signal

For accessibility, map:

Accessibility requirement
→ Component
→ Accessible behavior
→ Automated audit result
→ Manual review result
→ Remaining limitation

For retention and recovery, map:

Record type
→ Retention period
→ Archive destination
→ Legal-hold behavior
→ Archive job
→ Restore procedure
→ Verification evidence

For scheduled reporting, map:

Schedule type
→ Schedule record
→ Calculation service
→ Artifact
→ Delivery mechanism
→ Retry behavior
→ Alert
→ Test case

For receipt templates, map:

Document type
→ Template version
→ Template engine
→ Printer format
→ Audit event
→ Visual verification
→ Test case

For webhooks, map:

Event
→ Source domain event
→ Payload schema
→ Sensitive-field policy
→ Signature method
→ Delivery queue
→ Retry policy
→ Delivery log
→ Test case

For feature flags and settings, map:

Flag or setting
→ Configuration store
→ Scope
→ Default behavior
→ Gated service
→ Gated UI
→ Change audit
→ Test case

For tenant isolation, map:

Entity
→ Tenant identifier
→ Repository enforcement
→ Database/security-rule enforcement
→ Cache isolation
→ Export isolation
→ Archive isolation
→ Negative test case

For observability, map:

Operation
→ Correlation ID source
→ Log event
→ Trace span
→ Metric
→ Alert threshold
→ Support trace view
→ Runbook

For SQLite ⇄ Firebase sync (Section 43), map:

Syncable entity
→ SQLite table and sync-control columns
→ Firebase path
→ Sync-engine function
→ Conflict-resolution rule
→ Device/offline policy
→ Security-rule enforcement
→ Rollup dependency
→ Test case

--------------------------------------------------
42.2 REQUIREMENT IDENTIFIERS
--------------------------------------------------

Assign stable requirement identifiers, for example:

- SP-CUR-001 for Current Sales
- SP-TXN-001 for Transaction History
- SP-DAY-001 for Daily Performance
- SP-WEEK-001 for Weekly Performance
- SP-MONTH-001 for Monthly Performance
- SP-VOID-001 for Void History
- SP-REF-001 for Refund History
- SP-EXC-001 for Exchange History
- SP-ALERT-001 for Alerts
- SP-COMM-001 for Commissions
- SP-PROMO-001 for Promotions
- SP-RECON-001 for Shift Reconciliation
- SP-SEC-001 for Security
- SP-A11Y-001 for Accessibility
- SP-RET-001 for Retention
- SP-SCHED-001 for Scheduled Reports
- SP-PRINT-001 for Printing
- SP-API-001 for API Governance
- SP-WEBHOOK-001 for Webhooks
- SP-FLAG-001 for Feature Flags
- SP-TENANT-001 for Tenant Isolation
- SP-OBS-001 for Observability
- SP-SYNC-001 for SQLite ⇄ Firebase Synchronization

Use the same requirement identifiers in:

- Source-code comments where appropriate
- Test names
- API documentation
- Database migration notes
- Traceability matrix
- Verification checklist
- Release notes
==================================================
43. SQLITE ⇄ FIREBASE MULTI-DEVICE, MULTI-BRANCH
    SYNCHRONIZATION ARCHITECTURE
==================================================

STACK OVERRIDE:

This section overrides the generic default stack stated in the ROLE
section. The actual architecture for this project is:

- Local device database: SQLite (per terminal/device)
- Cloud database: Firebase (Firestore or Realtime Database — state
  which one is in use, or default to Firestore and justify why if not
  specified)
- Multiple devices per branch, multiple branches per company, all
  syncing to one shared Firebase backend
- The app must function fully offline using SQLite and reconcile with
  Firebase when connectivity returns

Every requirement in Sections 1–42 that assumed a single relational
database (PostgreSQL/Prisma) must be reinterpreted through this
dual-database model. Do not silently keep the Postgres/Prisma default
— explicitly restate the stack as SQLite + Firebase in the
Architecture Summary and Assumptions output.

--------------------------------------------------
43.1 ARCHITECTURE OVERVIEW
--------------------------------------------------

Required data-flow model:

Device (SQLite, source of truth for local writes)
  → Local write committed immediately (offline-first)
  → Change queued in a local outbox/sync-queue table
  → Sync engine pushes queued changes to Firebase when online
  → Firebase acts as the cross-branch, cross-device source of truth
  → Other devices (same branch or other branches, per permission)
    receive changes via Firebase listeners
  → Receiving device merges changes into its local SQLite
  → Local UI reads only from SQLite (never directly from Firebase
    for rendering), so the app remains fully responsive offline

State explicitly:

- Every terminal/device operates offline-first. No screen in the
  Sales Performance module should block or spinner-wait on network
  connectivity for core POS functions (sale, void, refund, exchange).
- Cross-device or cross-branch visibility (e.g., Head Office dashboard,
  another terminal's Current Sales) is inherently eventually
  consistent, bounded by sync latency. Document the expected sync
  latency target (e.g., under 5–10 seconds when online).
- Firebase is the arbitration authority for conflicts and the
  consolidated multi-branch view. SQLite is the authority for what a
  single device has committed locally, until synced.

--------------------------------------------------
43.2 LOCAL SQLITE SCHEMA REQUIREMENTS
--------------------------------------------------

Every syncable table (transactions, transaction_items, voids, refunds,
exchanges, inventory_movements, shifts, cash_movements, etc.) must
include these sync-control columns in SQLite:

- local_id (device-generated primary key, e.g., UUID — never an
  auto-increment integer, to avoid collision across devices)
- global_id (nullable until first successful sync; may be identical to
  local_id if UUIDs are used consistently end-to-end)
- device_id (the originating device/terminal)
- branch_id
- created_at_local (device clock)
- created_at_server (nullable until synced; set by Firebase server
  timestamp)
- updated_at_local
- updated_at_server
- sync_status: one of `pending`, `syncing`, `synced`, `conflict`,
  `failed`
- sync_attempts (count, for backoff)
- last_sync_error (nullable)
- is_deleted (soft-delete flag; never hard-delete financial records
  locally or remotely)
- row_version or vector-clock/logical-clock value (for conflict
  detection — see 43.5)

Use UUIDs (or ULIDs, which are sortable) as primary keys everywhere a
record may be created offline, so two devices can never generate a
colliding ID for two different records.

--------------------------------------------------
43.3 FIREBASE CLOUD SCHEMA REQUIREMENTS
--------------------------------------------------

Structure Firebase data explicitly around branch isolation. Example
Firestore path convention (adapt if using Realtime Database):

```
/companies/{companyId}/branches/{branchId}/transactions/{transactionId}
/companies/{companyId}/branches/{branchId}/voids/{voidId}
/companies/{companyId}/branches/{branchId}/refunds/{refundId}
/companies/{companyId}/branches/{branchId}/exchanges/{exchangeId}
/companies/{companyId}/branches/{branchId}/shifts/{shiftId}
/companies/{companyId}/branches/{branchId}/inventory_movements/{movementId}
/companies/{companyId}/branches/{branchId}/cash_movements/{movementId}
/companies/{companyId}/devices/{deviceId}
/companies/{companyId}/audit_events/{eventId}
/companies/{companyId}/alerts/{alertId}
```

Requirements:

- Never use a flat top-level collection with a `branchId` field alone
  for high-write-volume collections — nested/branch-scoped paths make
  Firebase Security Rules simpler and cheaper, and reduce the chance
  of cross-branch query leakage.
- Every document must carry the same identifying fields as its SQLite
  counterpart (global_id matching local_id where possible, device_id,
  branch_id, created/updated timestamps) so a document can be traced
  back to the originating device unambiguously.
- Use Firestore server timestamps (`FieldValue.serverTimestamp()`) as
  the canonical timestamp for cross-device ordering and reporting —
  never trust device clocks for financial ordering, only for local UI
  display and initial optimistic sequencing.
- Aggregation/rollup documents (daily/weekly/monthly summaries used by
  Current Sales, Daily/Weekly/Monthly Performance dashboards) should be
  maintained via Cloud Functions triggers on write, not recalculated
  client-side from the full transaction collection on every dashboard
  load — this keeps multi-branch dashboards fast and consistent
  regardless of how many devices are syncing.

--------------------------------------------------
43.4 SYNC ENGINE REQUIREMENTS
--------------------------------------------------

Implement a dedicated sync engine/service (not ad hoc calls scattered
through the UI). Required responsibilities:

- Maintain a local outbox table listing every pending local mutation
  in order of creation.
- Push outbox entries to Firebase in dependency order (e.g., a
  transaction must sync before a void that references it, or the sync
  engine must handle out-of-order arrival gracefully on the Firebase
  side).
- Use batched writes where possible to reduce round-trips and cost.
- Listen to relevant Firebase paths (scoped to the device's branch,
  plus any cross-branch paths the user's role authorizes, e.g., Head
  Office) and pull remote changes into SQLite.
- Deduplicate incoming changes using global_id — a record already
  present locally with the same global_id must be merged, not
  duplicated.
- Track a `last_synced_at` cursor per collection per device to support
  efficient incremental pulls instead of re-downloading entire
  collections.
- Expose sync state to the UI: `Online & Synced`, `Online & Syncing`,
  `Offline — N pending changes`, `Sync Error — N failed`.
- Retry failed syncs with exponential backoff and a maximum retry
  count before flagging for manual review.
- Never let a failed sync silently drop a financial record — failed
  outbox entries must remain visible and retriable, and must trigger
  an alert per Section 28 if unresolved beyond a configured time.

Required functions:

- enqueueLocalChange(entityType, entityId, changeType, payload)
- getPendingSyncQueue(deviceId)
- pushPendingChanges(deviceId)
- pullRemoteChanges(collectionPath, sinceCursor)
- mergeRemoteChange(localRecord, remoteRecord)
- getSyncStatus(deviceId)
- retryFailedSync(queueEntryId)
- forceFullResync(deviceId, collectionPath)
- getLastSyncedTimestamp(deviceId, collectionPath)

--------------------------------------------------
43.5 CONFLICT DETECTION AND RESOLUTION
--------------------------------------------------

Because multiple devices can act on related records (e.g., two
terminals both referencing the same held transaction, or a manager
approving from a tablet while a cashier's terminal is also updating
the same shift), define explicit conflict rules — do not rely on
"last write wins" for financial data without justification.

Required approach:

- Use a row_version (incrementing integer) or a vector clock per
  record to detect concurrent edits.
- For records that are created-once-and-immutable (completed
  transactions, void records, refund records, exchange records, audit
  events) — conflicts should be structurally impossible if each
  device generates its own unique ID for new records; the concern is
  duplicate creation, not concurrent edits. Prevent duplicates via
  idempotency keys (Section 37.3) checked at the Firebase Cloud
  Function layer before accepting a write.
- For mutable shared state (shift status, inventory stock counts, cash
  drawer running totals) — do NOT sync raw mutable totals directly.
  Instead, sync the individual immutable movement/event records
  (sale, void, refund, stock adjustment) and derive current totals by
  aggregation (via Cloud Function or local computed view). This
  avoids the entire class of "two devices overwrote the stock count"
  conflicts.
- If a true conflict is detected on a genuinely mutable field (e.g.,
  two managers editing the same product's price at the same time),
  apply a documented resolution policy: server-timestamp-wins, or
  flag as `sync_status = conflict` and surface it in an admin
  "Sync Conflicts" screen requiring manual resolution — never silently
  discard one side.
- Log every detected conflict as its own record (conflict_id, entity
  type, entity id, local version, remote version, resolution applied,
  resolved by) for audit purposes.

--------------------------------------------------
43.6 DEVICE AND TERMINAL REGISTRATION
--------------------------------------------------

Since this is multi-device per branch:

- Each physical device/terminal must be registered with a stable
  device_id, assigned to exactly one branch (or explicitly flagged as
  a roaming/head-office device with cross-branch read access).
- Store: device_id, device name/label, branch_id, terminal number,
  platform (Android/iOS/Windows/Web), app version, last_seen_at,
  last_sync_at, status (active/inactive/decommissioned), registered_by.
- Support remote deactivation of a lost/stolen device (revoke its
  Firebase auth/session and stop accepting its syncs) without requiring
  physical access to the device.
- Device registration and deactivation must generate audit events.
- The Current Sales module (Section 4) must be able to show which
  devices/terminals are actively contributing to "today's sales" for
  a branch, and flag a device that has gone silent (no sync in X
  minutes) — feeds into the anomaly/alert system (Section 28.1, item
  20).

--------------------------------------------------
43.7 OFFLINE OPERATION POLICY FOR SENSITIVE ACTIONS
--------------------------------------------------

Define explicitly which Sales Performance actions are permitted while
a device is offline, since approval workflows (Section 14) and alert
evaluation (Section 28) may depend on server-side data other devices
have written that this device hasn't synced yet:

- Sales: always allowed offline.
- Void (pre-settlement, same-device, same-shift): allowed offline.
- Void/Refund/Exchange requiring manager approval: allowed offline
  ONLY if the approving manager's credentials/PIN can be verified
  locally (e.g., cached hashed PIN with role/permission snapshot) —
  document the acceptable staleness window for cached permissions
  (e.g., permissions cached at last successful login/sync, revoked
  access takes effect only after that device's next successful sync).
- High-risk refunds/exchanges (Section 28.1 triggers, e.g., no
  receipt, large negative exchange difference) should be configurable
  to block or require supervisor override until the device is back
  online, per Section 34.4.
- Every offline-created record must carry a flag (`created_offline:
  true`) preserved permanently through sync, so reports and audits can
  distinguish offline-originated actions from online ones.

--------------------------------------------------
43.8 MULTI-BRANCH VISIBILITY AND FIREBASE SECURITY RULES
--------------------------------------------------

- Firebase Security Rules (Firestore Rules or Realtime Database Rules)
  must enforce branch isolation at the database layer — a device
  authenticated for Branch A must not be able to read or write
  Branch B's path unless its role is Regional/Head Office/Admin.
- Encode role and branch assignment in Firebase Auth custom claims (or
  a securely-fetched, rules-validated permissions document), refreshed
  on login and periodically — do not trust a role field embedded only
  in client-side app state.
- Head Office/Regional consolidated dashboards (Section 39) reading
  across many branches should NOT do so via direct multi-path
  real-time listeners fanned out across every branch on the client —
  use pre-aggregated rollup documents (maintained by Cloud Functions)
  per branch per day/week/month that a Head Office device can read
  cheaply, falling back to per-branch drill-down reads only when the
  user actually drills in.
- Rules must be written and tested to reject: a Branch A device
  writing a transaction with branch_id = B; a device writing to another
  device's device_id path; a non-approver writing an `approved_by`
  field; a client attempting to set `created_at_server` or financial
  totals directly rather than letting a Cloud Function derive them
  where server-side derivation is required.

--------------------------------------------------
43.9 SCHEMA MIGRATION ACROSS SQLITE AND FIREBASE
--------------------------------------------------

- Maintain a local SQLite schema version table and migration scripts
  (e.g., via a migration runner) that run on app startup, consistent
  with the app version.
- Maintain a parallel Firebase schema/document-shape version, since
  Firestore has no enforced schema — document the expected shape per
  collection (ideally with a validation layer, e.g., Cloud Function
  triggers or Firestore Rules `request.resource.data` validation) so
  malformed documents from an out-of-date app version cannot corrupt
  shared branch data.
- Define a compatibility policy: what happens when an older app
  version (older local schema) syncs against a newer Firebase schema,
  and vice versa. At minimum, the sync engine must detect a schema
  version mismatch and block sync (with a clear "Update Required"
  message) rather than writing malformed or partial records.
- Migrations that change a financial record's shape must never mutate
  historical synced records in place without an explicit, audited
  backfill process — prefer additive schema changes.

--------------------------------------------------
43.10 NETWORK RESILIENCE, BATCHING & COST CONTROL
--------------------------------------------------

- Batch Firebase writes (e.g., Firestore batched writes or
  transactions) when multiple related records are created together
  (a sale + its line items + its inventory movements) to reduce
  round-trips and preserve atomicity where Firestore transactions
  support it.
- Debounce/throttle real-time listener updates feeding the Current
  Sales dashboard so a burst of synced transactions doesn't cause UI
  thrashing.
- Use pagination/cursor-based pulls for initial device provisioning
  (a new or reset device syncing a branch's historical data) instead
  of pulling entire collections at once.
- Monitor and document expected Firebase read/write volume per branch
  per day to control cost, especially for Current Sales real-time
  listeners across many devices — prefer listening to a rollup
  document over listening to the raw transaction collection where
  only aggregate numbers are needed.
- Define behavior on flaky/intermittent connectivity (not fully
  offline, but slow or dropping): sync engine must not spam retries
  aggressively; use jittered backoff.

--------------------------------------------------
43.11 REQUIRED SYNC-SPECIFIC FUNCTIONS
--------------------------------------------------

- registerDevice(deviceInfo, branchId)
- deactivateDevice(deviceId, reason, adminId)
- getDeviceSyncHealth(branchId) — list of devices with last_sync_at,
  pending-change counts, and staleness flags
- getSyncConflicts(filters)
- resolveSyncConflict(conflictId, resolutionStrategy, userId)
- getOfflineOriginatedRecords(dateRange, filters)
- getBranchRollupSummary(branchId, period) — reads the Cloud
  Function-maintained aggregate, not raw collections
- rebuildBranchRollup(branchId, period) — admin/manual trigger to
  recompute a rollup if drift is suspected
- validateLocalRemoteReconciliation(branchId, dateRange) — compares
  SQLite totals on a sampled device against Firebase rollups and flags
  discrepancies

--------------------------------------------------
43.12 REQUIRED TESTS FOR SYNC ARCHITECTURE
--------------------------------------------------

- Two devices create transactions offline simultaneously; both sync
  successfully with no ID collision.
- Device goes offline mid-shift, performs a sale, a partial void, and
  a refund, then reconnects — all three sync in correct dependency
  order and reconcile to the same totals as if done online.
- Sync retried after a forced failure does not create duplicate
  records (idempotency verified end-to-end from SQLite outbox through
  Firebase write).
- A device with stale/cached permissions attempts an offline approval
  after its access was revoked online — verify the documented staleness
  policy is honored, not silently bypassed.
- Firebase Security Rules reject a spoofed branch_id write from an
  authenticated but wrong-branch device.
- Head Office dashboard totals match the sum of individual branch
  rollups match the sum of individual device-synced transactions.
- A device with a mismatched/outdated schema version is blocked from
  syncing malformed data, with a clear user-facing message.
- Killing the app mid-sync (simulating a crash) does not leave the
  outbox or Firebase in a state that causes duplicate or lost records
  on next launch.
- Rollup Cloud Functions correctly recompute after a late-arriving
  offline transaction changes a day's historical total (i.e., rollups
  are not "write-once" — they must handle backdated syncs).

--------------------------------------------------
43.13 UPDATED ASSUMPTIONS TO STATE UP FRONT
--------------------------------------------------

Before implementation, Opus must explicitly confirm or assume:

- Firestore vs. Realtime Database choice (default to Firestore unless
  told otherwise, and justify: better structured queries, better
  security-rule granularity for multi-branch, native offline
  persistence via the Firestore SDK which can complement but not
  replace the app's own SQLite layer).
- Whether Firebase's own offline persistence (Firestore's built-in
  local cache) is used *in addition to* the custom SQLite layer, or
  whether SQLite is the sole local store and Firebase is treated as
  purely a remote sync target with no client-side Firestore cache
  reliance. This materially changes the sync engine design — state
  the choice clearly, as building both simultaneously without a clear
  boundary risks two competing sources of local truth.
- Mobile platform(s) in scope (Android/iOS/tablet/desktop POS
  hardware) and the SQLite access library/ORM to be used per platform.
- Expected number of branches, devices per branch, and daily
  transaction volume, since this drives rollup strategy, listener
  scoping, and Firebase cost/design decisions.
==================================================
FINAL DELIVERY INSTRUCTION
==================================================

At the end of implementation, provide:

1. Completed traceability matrix
2. Build and test results
3. SQLite migration result and Firebase security-rule verification result
4. Branch and tenant isolation test result
5. Financial reconciliation test result
6. Inventory consistency test result
7. Export reconciliation result
8. Accessibility review result
9. Performance and load-test summary
10. Multi-device sync test result (see Section 43.12)
11. Screenshots or rendered previews where supported
12. Created and modified file list
13. Deployment instructions
14. Rollback instructions
15. Known limitations
16. Production-readiness recommendation

Do not declare the module production-ready if any critical financial,
inventory, authorization, tenant-isolation, idempotency, audit,
reconciliation, or SQLite⇄Firebase sync test is failing.