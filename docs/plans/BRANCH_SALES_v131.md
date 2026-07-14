# BRANCH SALES ISOLATION FIX - v1.0.59+131

Priority: HIGH - Data isolation bugs found in v130 audit

BUGS FOUND (lib/helpers/database_helper.dart):
- Line 1071: getAllTransactions - no branch filter
- Line 1074: getTransactionsByDateRange - no branch filter
- Line 1088: getDailySales - no branch filter
- Line 1316-1317: dashboard aggregations - no branch filter

TOMORROW: Add optional branch parameter to all read functions.
HO users see all, branch users see only own branch.

Files to check: database_helper.dart, sales_history_screen.dart,
sales_analytics_screen.dart, dashboard_screen.dart

Est time with fresh brain: 2-3 hours
