// lib/screens/profit_loss/profit_loss_screen.dart
// Main P&L Screen with Summary + Monthly Table tabs

import 'package:flutter/material.dart';
import '../../models/profit_loss_model.dart';
import '../../models/settings_model.dart';
import '../../services/profit_loss_service.dart';
import 'pl_summary_tab.dart';
import 'pl_monthly_tab.dart';
import '../../utils/profit_loss_export.dart';

class ProfitLossScreen extends StatefulWidget {
  final String branch;
  final String currentUser;
  const ProfitLossScreen({super.key, required this.branch, required this.currentUser});

  @override
  State<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Summary tab state
  DateTime _periodStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _periodEnd = DateTime.now();
  String _periodLabel = 'This Month';
  String _selectedBranch = 'All Branches';
  PLReport? _summaryReport;
  bool _summaryLoading = false;

  // Annual tab state
  int _selectedYear = DateTime.now().year;
  AnnualPLReport? _annualReport;
  bool _annualLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() => _summaryLoading = true);
    try {
      final report = await ProfitLossService.calculate(
        start: _periodStart,
        end: _periodEnd,
        branch: _selectedBranch == 'All Branches' ? null : _selectedBranch,
      );
      if (mounted) setState(() { _summaryReport = report; _summaryLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _summaryLoading = false);
      _showSnack('Error: $e', Colors.red);
    }
  }

  Future<void> _loadAnnual() async {
    setState(() => _annualLoading = true);
    try {
      final report = await ProfitLossService.calculateAnnual(
        year: _selectedYear,
        branch: _selectedBranch == 'All Branches' ? null : _selectedBranch,
      );
      if (mounted) setState(() { _annualReport = report; _annualLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _annualLoading = false);
      _showSnack('Error: $e', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  void _setPeriod(String label) {
    final now = DateTime.now();
    setState(() {
      _periodLabel = label;
      switch (label) {
        case 'Today':
          _periodStart = DateTime(now.year, now.month, now.day);
          _periodEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'This Week':
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          _periodStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
          _periodEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'This Month':
          _periodStart = DateTime(now.year, now.month, 1);
          _periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case 'Last Month':
          final lastMonth = DateTime(now.year, now.month - 1, 1);
          _periodStart = lastMonth;
          _periodEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
          break;
        case 'This Year':
          _periodStart = DateTime(now.year, 1, 1);
          _periodEnd = DateTime(now.year, 12, 31, 23, 59, 59);
          break;
      }
    });
    _loadSummary();
  }

  Future<void> _pickCustomRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _periodStart, end: _periodEnd),
    );
    if (result != null) {
      setState(() {
        _periodStart = result.start;
        _periodEnd = DateTime(result.end.year, result.end.month, result.end.day, 23, 59, 59);
        _periodLabel = 'Custom';
      });
      _loadSummary();
    }
  }

  void _drillDownToMonth(MonthlyPLData monthData) {
    setState(() {
      _selectedYear = _annualReport?.year ?? DateTime.now().year;
      _periodStart = DateTime(_selectedYear, monthData.month, 1);
      _periodEnd = DateTime(_selectedYear, monthData.month + 1, 0, 23, 59, 59);
      _periodLabel = '${monthData.monthName} $_selectedYear';
    });
    _tabController.animateTo(0);
    _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit & Loss', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Summary'),
            Tab(icon: Icon(Icons.calendar_view_month), text: 'Monthly'),
          ],
          onTap: (i) {
            if (i == 1 && _annualReport == null) _loadAnnual();
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.share),
            tooltip: 'Export',
            onSelected: (v) async {
              if (v == 'pdf_summary' && _summaryReport != null) {
                await ProfitLossExport.exportSummaryPDF(context, _summaryReport!, preparedBy: widget.currentUser);
              } else if (v == 'excel_summary' && _summaryReport != null) {
                await ProfitLossExport.exportSummaryExcel(context, _summaryReport!);
              } else if (v == 'pdf_monthly' && _annualReport != null) {
                await ProfitLossExport.exportMonthlyPDF(context, _annualReport!);
              } else if (v == 'excel_monthly' && _annualReport != null) {
                await ProfitLossExport.exportMonthlyExcel(context, _annualReport!);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No data to export'), backgroundColor: Colors.orange),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'pdf_summary', child: Row(children: [
                Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                SizedBox(width: 10),
                Text('PDF - Summary'),
              ])),
              const PopupMenuItem(value: 'excel_summary', child: Row(children: [
                Icon(Icons.table_chart, color: Colors.green, size: 20),
                SizedBox(width: 10),
                Text('Excel - Summary'),
              ])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'pdf_monthly', child: Row(children: [
                Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                SizedBox(width: 10),
                Text('PDF - Monthly'),
              ])),
              const PopupMenuItem(value: 'excel_monthly', child: Row(children: [
                Icon(Icons.table_chart, color: Colors.green, size: 20),
                SizedBox(width: 10),
                Text('Excel - Monthly'),
              ])),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                _loadSummary();
              } else {
                _loadAnnual();
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Summary
          PLSummaryTab(
            report: _summaryReport,
            isLoading: _summaryLoading,
            periodLabel: _periodLabel,
            selectedBranch: _selectedBranch,
            onPeriodSelect: _setPeriod,
            onCustomRange: _pickCustomRange,
            onBranchChange: (b) {
              setState(() => _selectedBranch = b);
              _loadSummary();
            },
            currencySymbol: AppSettings.currencySymbol,
          ),
          // Tab 2: Monthly Table
          PLMonthlyTab(
            report: _annualReport,
            isLoading: _annualLoading,
            selectedYear: _selectedYear,
            selectedBranch: _selectedBranch,
            onYearChange: (year) {
              setState(() => _selectedYear = year);
              _loadAnnual();
            },
            onBranchChange: (b) {
              setState(() => _selectedBranch = b);
              _loadAnnual();
            },
            onMonthTap: _drillDownToMonth,
            currencySymbol: AppSettings.currencySymbol,
          ),
        ],
      ),
    );
  }
}
