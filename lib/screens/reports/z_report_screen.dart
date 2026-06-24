// lib/screens/reports/z_report_screen.dart
import 'package:flutter/foundation.dart' show debugPrint;
import '../../models/settings_model.dart';
import 'package:flutter/material.dart';
import '../../services/daily_lock_service.dart';
import '../../services/cashier_session_service.dart';
import '../../models/cashier_session_model.dart';
import '../../models/incident_report_model.dart';
import '../../models/denomination_model.dart';
import 'package:flutter/services.dart';
import '../../helpers/database_helper.dart';
import '../../models/transaction_model.dart';
import '../../models/z_report_model.dart';
import 'z_report_history_screen.dart';
import '../../utils/z_report_pdf.dart';
import '../../utils/export_helper.dart';

class ZReportScreen extends StatefulWidget {
  final String branch;
  final String cashier;
  const ZReportScreen({super.key, required this.branch, required this.cashier});
  @override
  State<ZReportScreen> createState() => _ZReportScreenState();
}

class _ZReportScreenState extends State<ZReportScreen> {
  bool _viewerAuthorized = false;
  bool _checkingLock = true;
  final List<Transaction> _transactions = Transaction.allTransactions;
  final _beginningCashController = TextEditingController();
  final _endingCashController = TextEditingController(text: '');
  final Map<double, TextEditingController> _denomCtrls = {};
  final bool _useDenominations = true;  // 🔒 Always — declaration popup is the only method
  bool _cashDeclared = false;
  String _redeclareReason = "";
  int _redeclareCount = 0;
  bool _isReportGenerated = false;
  CashierSession? _activeSession;
  CashierSession? _todaysClosedSession;
  IncidentReport? _ir;
  bool _loadingSession = true;
  bool _shiftMustClose = false;
  List<CashierSession> _allActiveShifts = [];
  final DateTime _reportDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _checkZReportLock();
    // Initialize denomination controllers
    for (final d in DenominationRecord.phDenominations) {
      _denomCtrls[d] = TextEditingController();
    }
    _loadSessionData();
    _checkExistingReport();
  }

  Future<void> _checkExistingReport() async {
    try {
      await ZReportRecord.loadFromDB();
      if (mounted && await ZReportRecord.hasReportForToday()) {
        setState(() => _isReportGenerated = true);
      }
    } catch (_) {}
  }

  Future<void> _loadSessionData() async {
    try {
      // Check if there's an active session (shift not closed!)
      final active = await CashierSessionService.getActiveSession(widget.cashier);
      final allActiveShifts = await CashierSessionService.getAllActiveShifts();
      // 🆕 Fall back: if no match by widget.cashier, use first open shift (different id field)
      final effectiveActive = active ?? (allActiveShifts.isNotEmpty
          ? allActiveShifts.first
          : null);

      // Get all sessions for today
      final allSessions = await DatabaseHelper().getAllSessions();
      CashierSession? todaysClosedSession;
      for (final row in allSessions) {
        final s = CashierSession.fromMap(row);
        if (s.status == 'closed' && _isSameDay(s.closedAt, _reportDate)) {
          todaysClosedSession = s;
          break;
        }
      }

      // 🆕 Final fallback: today's closed session (if no open shift found)
      final finalEffective = effectiveActive ?? todaysClosedSession;

      // Get IR for the closed session if any
      IncidentReport? ir;
      if (todaysClosedSession != null) {
        final irRow = await DatabaseHelper().getIncidentReportBySession(todaysClosedSession.id);
        if (irRow != null) ir = IncidentReport.fromMap(irRow);
      }

      if (!mounted) return;
      setState(() {
        _activeSession = finalEffective;
        _todaysClosedSession = todaysClosedSession;
        _ir = ir;
        _shiftMustClose = effectiveActive != null || allActiveShifts.isNotEmpty;
        _allActiveShifts = allActiveShifts;
        _loadingSession = false;

        // Auto-populate from closed session
        if (todaysClosedSession != null) {
          _beginningCashController.text = todaysClosedSession.beginningCash.toStringAsFixed(2);
          _endingCashController.text = todaysClosedSession.endingCashDeclared.toStringAsFixed(2);
        }
        // 🆕 Active session (current shift) overrides — uses login-time beginning cash
        if (finalEffective != null) {
          _beginningCashController.text = finalEffective.beginningCash.toStringAsFixed(2);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _loadingSession = false);
    }
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }


  // Only today's transactions
  List<Transaction> get _todayTransactions {
    final resetHour = {"12:00 AM": 0, "3:00 AM": 3, "6:00 AM": 6, "8:00 AM": 8}[AppSettings.zReportResetTime] ?? 0; final today = DateTime(_reportDate.year, _reportDate.month, _reportDate.day, resetHour);
    return _transactions.where((t) => t.dateTime.isAfter(today)).toList();
  }

  List<Transaction> get _validTransactions =>
      _todayTransactions.where((t) => t.status != 'voided' && t.status != 'refunded').toList();

  List<Transaction> get _voidedTransactions =>
      _todayTransactions.where((t) => t.status == 'voided').toList();

  double get _totalGrossSales =>
      _validTransactions.fold(0, (sum, t) => sum + t.total + t.totalDiscount);

  double get _totalDiscount =>
      _validTransactions.fold(0, (sum, t) => sum + t.totalDiscount);

  double get _totalNetSales =>
      _validTransactions.fold(0, (sum, t) => sum + t.total);

  int get _totalTransactions => _validTransactions.length;

  // 🧾 VAT computation (BIR-compliant)
  double get _totalVAT => _validTransactions.fold(0, (sum, t) => sum + t.tax);
  double get _totalVATableSales => _totalNetSales - _totalVAT;

  double get _totalVoidedAmount =>
      _voidedTransactions.fold(0, (sum, t) => sum + t.total);

  int get _totalVoidedCount => _voidedTransactions.length;

  List<Transaction> get _refundedTransactions =>
      _todayTransactions.where((t) => t.status == 'refunded').toList();

  double get _totalRefundedAmount =>
      _refundedTransactions.fold(0, (sum, t) => sum + t.total);

  int get _totalRefundedCount => _refundedTransactions.length;

  double _getPaymentTotal(String method) {
    return _validTransactions
        .where((t) => t.paymentMethod == method)
        .fold(0, (sum, t) => sum + t.total);
  }

  int _getPaymentCount(String method) {
    return _validTransactions.where((t) => t.paymentMethod == method).length;
  }

  double get _beginningCash => double.tryParse(_beginningCashController.text) ?? 0;
  double get _expectedCash => _beginningCash + _getPaymentTotal('Cash');
  double get _totalCounted {
    double total = 0;
    for (final entry in _denomCtrls.entries) {
      final qty = int.tryParse(entry.value.text.trim()) ?? 0;
      total += entry.key * qty;
    }
    return total;
  }
  double get _endingCash => _useDenominations ? _totalCounted : (double.tryParse(_endingCashController.text) ?? 0);
  double get _overShort => _endingCash - _expectedCash;
  double get _averageTransaction =>
      _totalTransactions > 0 ? _totalNetSales / _totalTransactions : 0;

  // ──────────────────────────────────────────────────────────
  // ✅ GENERATE Z REPORT - Save to history & reset
  // ──────────────────────────────────────────────────────────
  Future<void> _generateReport() async {
    // 🔒 Manager PIN required to End the Business Day (BIR compliance)
    final managerUsername = await ManagerPinDialog.verify(
      context,
      title: "End of Day Authorization",
      actionLabel: "Generate Z Report & Lock Day",
    );
    final managerAuthorized = managerUsername != null;
    if (!managerAuthorized) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("❌ End of Day cancelled — Manager authorization required"),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (!mounted) return;
    // BLOCK 1: Check if any active shifts (multi-cashier check!)
    if (_shiftMustClose) {
      _snack('🚨 BLOCKED: ${_allActiveShifts.length} active shift(s) detected! All cashiers must close their shifts first.');
      return;
    }

    // BLOCK 2: Check ending cash is entered
    if (_endingCashController.text.isEmpty && !_useDenominations) {
      _snack('Please enter the ending cash count');
      return;
    }

    if (_useDenominations && _totalCounted == 0) {
      _snack('Please enter denomination counts');
      return;
    }

    // BLOCK 3: Check if already generated
    if (await ZReportRecord.hasReportForToday()) {
      _snack('Z Report already generated for today!');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_amber, color: Colors.orange[700], size: 28),
          const SizedBox(width: 10),
          const Text('End of Day Authorization', style: TextStyle(fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10)),
            child: const Text(
              'This will:\n• Save today\'s report to history\n• Lock this day\'s transactions\n• Reset for the next business day\n\nThis action cannot be undone.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Net Sales:', style: TextStyle(fontWeight: FontWeight.w600)),
            Text(_totalNetSales.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Transactions:', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('$_totalTransactions'),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Over/Short:', style: TextStyle(fontWeight: FontWeight.w600)),
            Text(
              _overShort == 0 ? 'BALANCED' : '${_overShort.abs().toStringAsFixed(2)} ${_overShort > 0 ? "OVER" : "SHORT"}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _overShort == 0 ? Colors.green : _overShort > 0 ? Colors.blue : Colors.red,
              ),
            ),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _saveAndGenerate();
            },
            icon: const Icon(Icons.check),
            label: const Text('Manager Authorize'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[700], foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndGenerate() async {
    final now = DateTime.now();
    final methods = ['Cash', 'GCash', 'Maya', 'Card'];

    // Build payment breakdown
    final paymentBreakdown = methods.map((m) => ZReportPaymentBreakdown(
      method: m, count: _getPaymentCount(m), total: _getPaymentTotal(m),
    )).toList();

    // Build void records
    final voidRecords = _voidedTransactions.map((t) => ZReportVoidRecord(
      txnId: t.id, reason: t.voidReason, amount: t.total,
    )).toList();

    // Build transaction log
    final txnLog = _todayTransactions.map((t) => ZReportTxnRecord(
      txnId: t.id, dateTime: t.dateTime, paymentMethod: t.paymentMethod,
      amount: t.total, status: t.status,
    )).toList();

    // Create report ID
    final reportId = 'ZR-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    // Save to history
    await ZReportRecord.addReport(ZReportRecord(
      reportId: reportId,
      reportDate: DateTime(_reportDate.year, _reportDate.month, _reportDate.day),
      generatedAt: now,
      branch: widget.branch,
      cashier: widget.cashier,
      grossSales: _totalGrossSales,
      totalDiscount: _totalDiscount,
      netSales: _totalNetSales,
      totalTransactions: _totalTransactions,
      averageTransaction: _averageTransaction,
      paymentBreakdown: paymentBreakdown,
      voidedCount: _totalVoidedCount,
      voidedAmount: _totalVoidedAmount,
      voidedTransactions: voidRecords,
      refundedCount: _totalRefundedCount,
      refundedAmount: _totalRefundedAmount,
      refundedTransactions: _refundedTransactions.map((t) => ZReportVoidRecord(txnId: t.id, reason: 'Refund: ${t.refundMethod}', amount: t.total)).toList(),
      beginningCash: _beginningCash,
      expectedCash: _expectedCash,
      endingCash: _endingCash,
      overShort: _overShort,
      transactionLog: txnLog,
    ));
      // 🔒 Auto-lock business day (Manager PIN required to reopen)
      await DailyLockService.lockDayAfterZReport(reportId);

    // 💰 Save denominations to denomination_records (linked to this Z Report)
    try {
      final denomRecords = <Map<String, dynamic>>[];
      for (final d in DenominationRecord.phDenominations) {
        final qty = int.tryParse(_denomCtrls[d]?.text.trim() ?? '') ?? 0;
        if (qty > 0) {
          denomRecords.add(DenominationRecord(
            sessionId: reportId,
            type: 'ending',
            denomination: d,
            quantity: qty,
            total: d * qty,
            createdAt: now,
          ).toMap());
        }
      }
      if (denomRecords.isNotEmpty) {
        await DatabaseHelper().insertDenominationBatch(denomRecords);
        debugPrint('💰 Saved ${denomRecords.length} denominations for $reportId');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to save denominations: $e');
    }

    setState(() {
      _isReportGenerated = true;
    });

    _snack('✅ Z Report generated & saved! Report ID: $reportId');
  }

  void _printReport() {
    final methods = ['Cash', 'GCash', 'Maya', 'Card'];
    final paymentMap = <String, Map<String, dynamic>>{};
    for (final m in methods) {
      paymentMap[m] = {'count': _getPaymentCount(m), 'total': _getPaymentTotal(m)};
    }
    final voidedList = _voidedTransactions.map((t) => {
      'id': t.id, 'reason': t.voidReason, 'amount': t.total,
    }).toList();
    final txnList = _todayTransactions.map((t) => {
      'id': t.id, 'dateTime': t.dateTime, 'payment': t.paymentMethod,
      'amount': t.total, 'status': t.status,
    }).toList();

    // Build denominations map from controllers
    final denomMap = <double, int>{};
    for (final d in DenominationRecord.phDenominations) {
      final qty = int.tryParse(_denomCtrls[d]?.text.trim() ?? '') ?? 0;
      if (qty > 0) denomMap[d] = qty;
    }
    ZReportPdf.printCurrentDay(
      branch: widget.branch, cashier: widget.cashier, reportDate: _reportDate,
      grossSales: _totalGrossSales, totalDiscount: _totalDiscount,
      netSales: _totalNetSales, totalTransactions: _totalTransactions,
      averageTransaction: _averageTransaction, paymentBreakdown: paymentMap,
      voidedCount: _totalVoidedCount, voidedAmount: _totalVoidedAmount, refundedCount: _totalRefundedCount, refundedAmount: _totalRefundedAmount,
      voidedList: voidedList, beginningCash: _beginningCash,
      expectedCash: _expectedCash, endingCash: _endingCash,
      overShort: _overShort, denominations: denomMap, transactions: txnList,
      isGenerated: _isReportGenerated,
    );
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  Color _getPaymentColor(String method) {
    switch (method) {
      case 'Cash': return Colors.green;
      case 'GCash': return Colors.blue;
      case 'Maya': return Colors.green[800]!;
      case 'Card': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  void dispose() {
    _beginningCashController.dispose();
    _endingCashController.dispose();
    for (final c in _denomCtrls.values) { c.dispose(); }
    super.dispose();
  }

  String _fmtDt(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day}/${dt.year} $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _exportExcel() {
    final data = _validTransactions;
    ExportHelper.exportExcel(
      headers: ['TXN ID', 'Date/Time', 'Items', 'Subtotal', 'Discount', 'Tax', 'Total', 'Payment', 'Status'],
      rows: data.map((t) => [
        t.id, _fmtDt(t.dateTime), t.items.length.toString(),
        t.subtotal.toStringAsFixed(2), t.totalDiscount.toStringAsFixed(2),
        t.tax.toStringAsFixed(2), t.total.toStringAsFixed(2),
        t.paymentMethod, t.status,
      ]).toList(),
      sheetName: 'Z_Report',
      fileName: 'ZReport_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Excel exported!'), backgroundColor: Colors.green));
  }

  void _exportPdf() {
    final data = _validTransactions;
    ExportHelper.exportPdf(
      title: 'Z Report',
      subtitle: 'Gross: ${_totalGrossSales.toStringAsFixed(2)} | Net: ${_totalNetSales.toStringAsFixed(2)} | ${data.length} transactions',
      headers: ['TXN ID', 'Date/Time', 'Items', 'Subtotal', 'Discount', 'Tax', 'Total', 'Payment', 'Status'],
      rows: data.map((t) => [
        t.id, _fmtDt(t.dateTime), t.items.length.toString(),
        t.subtotal.toStringAsFixed(2), t.totalDiscount.toStringAsFixed(2),
        t.tax.toStringAsFixed(2), t.total.toStringAsFixed(2),
        t.paymentMethod, t.status,
      ]).toList(),
      fileName: 'ZReport_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ PDF exported!'), backgroundColor: Colors.green));
  }



  @override

  Widget _buildActiveShiftsBanner() {
    if (!_shiftMustClose) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red[300]!, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.warning_amber, color: Colors.red[800], size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚠️ Z REPORT BLOCKED',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red[900]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Active shifts detected (${_allActiveShifts.length}). All cashiers must close their shifts before Z Report can be generated.',
            style: TextStyle(fontSize: 12, color: Colors.red[800]),
          ),
          if (_allActiveShifts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Open Shifts:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[800])),
                  const SizedBox(height: 4),
                  ..._allActiveShifts.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Icon(Icons.person, size: 14, color: Colors.red[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${s.cashierName} (opened ${s.openedAt.hour.toString().padLeft(2, "0")}:${s.openedAt.minute.toString().padLeft(2, "0")})',
                          style: TextStyle(fontSize: 11, color: Colors.red[900]),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(10)),
                        child: Text('OPEN', style: TextStyle(fontSize: 9, color: Colors.red[900], fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '💡 Each cashier must login → End Shift → declare cash → submit before Z Report.',
            style: TextStyle(fontSize: 10, color: Colors.red[700], fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }


  Future<void> _checkZReportLock() async {
    final locked = await DailyLockService.isLocked();
    if (!mounted) return;
    setState(() {
      _checkingLock = false;
      _viewerAuthorized = !locked;
    });

    // 🔒 BIR persistence — restore cash declared state from database
    final wasDeclared = await DailyLockService.isCashDeclared();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("wasDeclared=$wasDeclared"), backgroundColor: wasDeclared ? Colors.green : Colors.red, duration: const Duration(seconds: 6)));
    if (wasDeclared && mounted) {
      // 💰 Load previously declared denominations back into controllers
      final savedDenoms = await DailyLockService.getCashDeclaredDenominations();
      for (final entry in savedDenoms.entries) {
        _denomCtrls[entry.key]?.text = entry.value.toString();
      }
      setState(() { _cashDeclared = true; });
    }

    // 🔒 BIR blind audit — show declaration popup if day is unlocked
    if (!locked && !wasDeclared && !_isReportGenerated && mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        await _showCashDeclarationDialog();
        if (mounted && !_cashDeclared) {
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _unlockView() async {
    final ok = await DailyLockService.unlockForView(context);
    if (!ok) return;
    if (!mounted) return;
    setState(() { _viewerAuthorized = true; });
  }

  Widget _buildLockedScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔒 Z Report — Locked'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orange.shade300, width: 3),
                ),
                child: Icon(Icons.lock_outline, size: 100, color: Colors.orange.shade700),
              ),
              const SizedBox(height: 32),
              Text('LOCKED', style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
                letterSpacing: 8,
              )),
              const SizedBox(height: 16),
              const Text(
                'Z Report has been generated.\nAuthorization required to view.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 280, height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                  ),
                  onPressed: _unlockView,
                  icon: const Icon(Icons.lock_open, size: 24),
                  label: const Text('Click me to unlock',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    Text('Manager / Admin PIN required',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget build(BuildContext context) {
    if (_checkingLock) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_viewerAuthorized) return _buildLockedScreen();
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Z Report', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple[700], foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${ZReportRecord.history.length}', style: const TextStyle(fontSize: 9)),
              isLabelVisible: ZReportRecord.history.isNotEmpty,
              child: const Icon(Icons.history),
            ),
            tooltip: 'Z Report History',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ZReportHistoryScreen(branch: widget.branch))),
          ),
        ],
      ),
      body: _isReportGenerated ? _buildGeneratedView() : _buildCurrentDayView(),
    );
  }

  // ──────────────────────────────────────────────────────────
  // ✅ CURRENT DAY VIEW (before generating)
  // ──────────────────────────────────────────────────────────
  Widget _buildCurrentDayView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildActiveShiftsBanner(),
        _buildReportHeader(),
        const SizedBox(height: 16),
        _buildSectionTitle('Sales Summary', Icons.trending_up),
        const SizedBox(height: 8),
        _buildSalesSummaryCard(),
        const SizedBox(height: 16),
        _buildSectionTitle('Payment Breakdown', Icons.payment),
        const SizedBox(height: 8),
        _buildPaymentBreakdownCard(),
        const SizedBox(height: 16),
        _buildSectionTitle('Voided Transactions', Icons.cancel),
        const SizedBox(height: 8),
        _buildVoidSummaryCard(),
        const SizedBox(height: 16),
        _buildSectionTitle('Cash Count', Icons.account_balance_wallet),
        const SizedBox(height: 8),
        _buildCashCountCard(),
        const SizedBox(height: 16),
        // 🔄 Re-Declare Cash (Manager PIN required)
        if (_cashDeclared) Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final username = await ManagerPinDialog.verify(
                  context,
                  title: "🔄 Re-Declare Cash",
                  actionLabel: "Recount drawer (with reason)",
                );
                if (username != null) {
                  DailyLockService.resetCashDeclared();
                  if (mounted) {
                    setState(() {
                      _cashDeclared = false;
                      _redeclareCount++;
                      _redeclareReason = "Manager " + username + " recounted (#" + _redeclareCount.toString() + ")";
                    });
                  }
                  if (mounted) _showCashDeclarationDialog();
                }
              },
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text("🔄 Re-Declare Cash (Manager PIN)"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
                side: BorderSide(color: Colors.orange.shade400, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
        // Generate button
        SizedBox(width: double.infinity, height: 55,
          child: ElevatedButton.icon(
            onPressed: _generateReport,
            icon: const Icon(Icons.assessment, size: 28),
            label: const Text('🔒 END OF DAY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700], foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────
  // ✅ GENERATED VIEW (after generating - locked)
  // ──────────────────────────────────────────────────────────
  Widget _buildGeneratedView() {
    final todayReport = ZReportRecord.history.isNotEmpty ? ZReportRecord.history.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildActiveShiftsBanner(),
        // ✅ Generated banner
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [Colors.green[700]!, Colors.green[500]!]),
          ),
          child: Column(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 48),
            const SizedBox(height: 8),
            const Text('Z Report Generated!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${_reportDate.month}/${_reportDate.day}/${_reportDate.year}',
              style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14)),
            if (todayReport != null) ...[
              const SizedBox(height: 4),
              Text('ID: ${todayReport.reportId}', style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11)),
            ],
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _buildHeaderStat('Net Sales', _totalNetSales.toStringAsFixed(2)),
              _buildHeaderStat('Transactions', '$_totalTransactions'),
              _buildHeaderStat('Avg/TXN', _averageTransaction.toStringAsFixed(2)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // ✅ Quick summary
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            _buildReportRow('Gross Sales', _totalGrossSales.toStringAsFixed(2)),
            _buildReportRow('Discounts', '-${_totalDiscount.toStringAsFixed(2)}', valueColor: Colors.red),
            const Divider(),
            _buildReportRow('NET SALES', _totalNetSales.toStringAsFixed(2), isBold: true, valueColor: Colors.green[800], fontSize: 18),
            const Divider(),
        _buildReportRow("VATable Sales", _totalVATableSales.toStringAsFixed(2)),
        _buildReportRow("VAT (12%)", _totalVAT.toStringAsFixed(2), valueColor: Colors.purple),
        _buildReportRow("VAT-Exempt Sales", "0.00"),
        _buildReportRow("Zero-Rated Sales", "0.00"),
        const Divider(),
            _buildReportRow('Cash Sales', _getPaymentTotal('Cash').toStringAsFixed(2)),
            _buildReportRow('GCash', _getPaymentTotal('GCash').toStringAsFixed(2)),
            _buildReportRow('Maya', _getPaymentTotal('Maya').toStringAsFixed(2)),
            _buildReportRow('Card', _getPaymentTotal('Card').toStringAsFixed(2)),
            const Divider(),
            _buildReportRow('Voided', '$_totalVoidedCount (${_totalVoidedAmount.toStringAsFixed(2)})', valueColor: Colors.red),
            _buildReportRow('Refunded', '$_totalRefundedCount (${_totalRefundedAmount.toStringAsFixed(2)})', valueColor: Colors.orange),
            _buildReportRow('Over/Short',
              _overShort == 0 ? 'BALANCED' : '${_overShort.abs().toStringAsFixed(2)} ${_overShort > 0 ? "OVER" : "SHORT"}',
              valueColor: _overShort == 0 ? Colors.green : _overShort > 0 ? Colors.blue : Colors.red),
          ])),
        ),
        const SizedBox(height: 16),

        // ✅ Action buttons
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ZReportHistoryScreen(branch: widget.branch))),
            icon: const Icon(Icons.history),
            label: const Text('View History'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: _printReport,
            icon: const Icon(Icons.print),
            label: const Text('Print'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          )),
        ]),
        const SizedBox(height: 16),
        const SizedBox(height: 8),

        // ✅ Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Today\'s Z Report has been generated and saved. New transactions will appear in tomorrow\'s report.',
              style: TextStyle(fontSize: 12, color: Colors.blue[800]))),
          ]),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────
  // UI COMPONENTS
  // ──────────────────────────────────────────────────────────
  Widget _buildReportHeader() {
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [Colors.purple[700]!, Colors.purple[500]!])),
        child: Column(children: [
          const Icon(Icons.assessment, color: Colors.white, size: 40),
          const SizedBox(height: 8),
          const Text('End of Day Report', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${_reportDate.month}/${_reportDate.day}/${_reportDate.year}',
            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14)),
          Text('${widget.branch} • ${widget.cashier}',
            style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _buildHeaderStat('Net Sales', _totalNetSales.toStringAsFixed(2)),
            _buildHeaderStat('Transactions', '$_totalTransactions'),
            _buildHeaderStat('Avg/TXN', _averageTransaction.toStringAsFixed(2)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11)),
    ]);
  }

  Widget _buildSalesSummaryCard() {
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        _buildReportRow('Gross Sales', _totalGrossSales.toStringAsFixed(2), isBold: true),
        const Divider(),
        _buildReportRow('Less: Discounts', '-${_totalDiscount.toStringAsFixed(2)}', valueColor: Colors.red),
        const Divider(),
        _buildReportRow('NET SALES', _totalNetSales.toStringAsFixed(2), isBold: true, valueColor: Colors.green[800], fontSize: 20),
        const Divider(),
        _buildReportRow("VATable Sales", _totalVATableSales.toStringAsFixed(2)),
        _buildReportRow("VAT (12%)", _totalVAT.toStringAsFixed(2), valueColor: Colors.purple),
        _buildReportRow("VAT-Exempt Sales", "0.00"),
        _buildReportRow("Zero-Rated Sales", "0.00"),
        const Divider(),
        _buildReportRow('Total Transactions', '$_totalTransactions'),
        _buildReportRow('Average per Transaction', _averageTransaction.toStringAsFixed(2)),
      ])));
  }

  Widget _buildPaymentBreakdownCard() {
    final methods = ['Cash', 'GCash', 'Maya', 'Card'];
    final icons = [Icons.money, Icons.phone_android, Icons.phone_iphone, Icons.credit_card];
    final colors = [Colors.green, Colors.blue, Colors.green, Colors.purple];
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        for (int i = 0; i < methods.length; i++) ...[
          Row(children: [
            Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: colors[i].withAlpha(25), borderRadius: BorderRadius.circular(8)),
              child: Icon(icons[i], color: colors[i], size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildActiveShiftsBanner(),
              Text(methods[i], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text('${_getPaymentCount(methods[i])} transactions', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ])),
            Text(_getPaymentTotal(methods[i]).toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          if (i < methods.length - 1) const Divider(height: 20),
        ],
        const Divider(height: 24, thickness: 2),
        _buildReportRow('TOTAL', _totalNetSales.toStringAsFixed(2), isBold: true, fontSize: 18, valueColor: Colors.purple[800]),
      ])));
  }

  Widget _buildVoidSummaryCard() {
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        _buildReportRow('Voided Transactions', '$_totalVoidedCount', valueColor: Colors.red),
        _buildReportRow('Voided Amount', _totalVoidedAmount.toStringAsFixed(2), valueColor: Colors.red, isBold: true),
        _buildReportRow('Refunded Transactions', '$_totalRefundedCount', valueColor: Colors.orange),
        _buildReportRow('Refunded Amount', _totalRefundedAmount.toStringAsFixed(2), valueColor: Colors.orange, isBold: true),
        if (_voidedTransactions.isNotEmpty) ...[
          const Divider(),
          ..._voidedTransactions.map((t) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const Icon(Icons.cancel, color: Colors.red, size: 16), const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildActiveShiftsBanner(),
                Text(t.id, style: const TextStyle(fontSize: 12)),
                Text(t.voidReason, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ])),
              Text(t.total.toStringAsFixed(2), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
            ]))),
        ],
      ])));
  }

  Widget _buildCashCountCard() {
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        // 🆕 Read-only banner
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            border: Border.all(color: Colors.purple.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.lock_outline, size: 16, color: Colors.purple.shade700),
            const SizedBox(width: 8),
            Expanded(child: Text(
              "Beginning Cash is set during Beginning Cash Encoding at log-in. Only Ending Cash is editable here.",
              style: TextStyle(fontSize: 11, color: Colors.purple.shade700),
            )),
          ]),
        ),
        Row(children: [
          const Expanded(child: Text('Beginning Cash', style: TextStyle(fontWeight: FontWeight.w500))),
          SizedBox(width: 150, child: TextField(
            controller: _beginningCashController, readOnly: true, keyboardType: TextInputType.number,
            textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            decoration: InputDecoration(prefixText: 'P ', filled: true, fillColor: Colors.grey.shade100, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            onChanged: (_) => setState(() {}))),
        ]),
        const SizedBox(height: 12),
        if (_cashDeclared) _buildReportRow('Add: Cash Sales', '+${_getPaymentTotal('Cash').toStringAsFixed(2)}', valueColor: Colors.green),
        const Divider(),
        _buildReportRow('Expected Cash', _cashDeclared ? _expectedCash.toStringAsFixed(2) : '🔒 Count cash first', isBold: true, fontSize: 16, valueColor: _cashDeclared ? null : Colors.grey),
        // Toggle: Single field OR Denomination breakdown
        Row(children: [
          Icon(Icons.calculate, size: 18, color: Colors.purple[700]),
          const SizedBox(width: 8),
          const Expanded(child: Text('Count by Denomination?', style: TextStyle(fontWeight: FontWeight.w500))),
          Switch(
            value: _useDenominations,
            onChanged: null,  // 🔒 Locked
            activeColor: Colors.purple[700],
          ),
        ]),
        const Divider(),
        // Ending Cash Input — Single OR Denomination
        if (!_useDenominations) Row(children: [
          const Expanded(child: Text('Ending Cash (Actual)', style: TextStyle(fontWeight: FontWeight.w500))),
          SizedBox(width: 130, child: TextField(
            controller: _endingCashController, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            decoration: InputDecoration(
              prefixText: '₱ ', isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            onChanged: (_) => setState(() {}),
          )),
        ]),
        if (_useDenominations) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text('BILLS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue[800], letterSpacing: 1.5))),
          ..._buildZDenomRows([1000, 500, 200, 100, 50, 20]),
          Padding(padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text('COINS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[800], letterSpacing: 1.5))),
          ..._buildZDenomRows([10, 5, 1, 0.25, 0.10, 0.05]),
          const Divider(),
          Row(children: [
            const Expanded(child: Text('TOTAL COUNTED:', style: TextStyle(fontWeight: FontWeight.bold))),
            Text('₱${_totalCounted.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green[700])),
          ]),
        ]),
        const SizedBox(height: 12),
        if (_endingCashController.text.isNotEmpty)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _overShort == 0 ? Colors.green[50] : _overShort > 0 ? Colors.blue[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _overShort == 0 ? Colors.green : _overShort > 0 ? Colors.blue : Colors.red, width: 0.5)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_overShort == 0 ? '✅ BALANCED' : _overShort > 0 ? '📈 OVER' : '📉 SHORT',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                  color: _overShort == 0 ? Colors.green[800] : _overShort > 0 ? Colors.blue[800] : Colors.red[800])),
              Text(_overShort.abs().toStringAsFixed(2),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20,
                  color: _overShort == 0 ? Colors.green[800] : _overShort > 0 ? Colors.blue[800] : Colors.red[800])),
            ])),
      ])));
  }

  List<Widget> _buildZDenomRows(List<double> denoms) {
    return denoms.map((d) {
      final qty = int.tryParse(_denomCtrls[d]?.text.trim() ?? '') ?? 0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(width: 56, padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: d >= 50 ? Colors.blue[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(6)),
            child: Text(DenominationRecord.labelFor(d), textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: d >= 50 ? Colors.blue[800] : Colors.orange[800]))),
          const SizedBox(width: 8),
          const Text('×', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          SizedBox(width: 60, child: TextField(
            controller: _denomCtrls[d], readOnly: _cashDeclared, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0', isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            ),
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(width: 6),
          const Text('=', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Expanded(child: Text('₱${(d * qty).toStringAsFixed(2)}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: qty > 0 ? Colors.green[700] : Colors.grey))),
        ]),
      );
    }).toList();
  }

  Widget _buildTransactionList() {
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Expanded(flex: 3, child: Text('Transaction ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            Expanded(flex: 2, child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
          ])),
        const SizedBox(height: 4),
        if (_todayTransactions.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Text('No transactions today', style: TextStyle(color: Colors.grey)))
        else
          ..._todayTransactions.map((t) => Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              color: t.status == 'voided' ? Colors.red[50] : t.status == 'refunded' ? Colors.orange[50] : null),
            child: Row(children: [
              Expanded(flex: 3, child: Row(children: [
                if (t.status == 'voided') const Icon(Icons.cancel, color: Colors.red, size: 14),
                if (t.status == 'refunded') const Icon(Icons.undo, color: Colors.orange, size: 14),
                if (t.status == 'voided' || t.status == 'refunded') const SizedBox(width: 4),
                Flexible(child: Text(t.id, style: TextStyle(fontSize: 11,
                  decoration: (t.status == 'voided' || t.status == 'refunded') ? TextDecoration.lineThrough : null,
                  color: t.status == 'voided' ? Colors.red : t.status == 'refunded' ? Colors.orange : Colors.black87), overflow: TextOverflow.ellipsis)),
              ])),
              Expanded(flex: 2, child: Text('${t.dateTime.hour}:${t.dateTime.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _getPaymentColor(t.paymentMethod).withAlpha(20), borderRadius: BorderRadius.circular(4)),
                child: Text(t.paymentMethod, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _getPaymentColor(t.paymentMethod)), textAlign: TextAlign.center))),
              Expanded(flex: 2, child: Text(t.total.toStringAsFixed(2), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                decoration: (t.status == 'voided' || t.status == 'refunded') ? TextDecoration.lineThrough : null,
                color: t.status == 'voided' ? Colors.red : t.status == 'refunded' ? Colors.orange : Colors.black87), textAlign: TextAlign.right)),
            ]))),
      ])));
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 20, color: Colors.purple[700]), const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple[800])),
    ]);
  }

  Widget _buildReportRow(String label, String value, {bool isBold = false, Color? valueColor, double fontSize = 14}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, fontSize: fontSize)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize, color: valueColor ?? Colors.black87)),
      ]));
  }

  /// 🔒 BIR-grade blind cash declaration popup
  Future<void> _showCashDeclarationDialog() async {
    final tempCtrls = <double, TextEditingController>{};
    for (final d in DenominationRecord.phDenominations) {
      tempCtrls[d] = TextEditingController(text: _denomCtrls[d]?.text ?? '');
    }

    double computeTotal() {
      double total = 0;
      for (final d in DenominationRecord.phDenominations) {
        final qty = int.tryParse(tempCtrls[d]?.text.trim() ?? '') ?? 0;
        total += d * qty;
      }
      return total;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final total = computeTotal();
          return AlertDialog(
            title: Row(children: [
              Icon(Icons.account_balance_wallet, color: Colors.purple.shade700, size: 28),
              const SizedBox(width: 8),
              const Expanded(child: Text('Declare Cash Count')),
            ]),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text(
                        'Count physical cash by denomination.\nExpected amount revealed AFTER declaration.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...[1000.0, 500.0, 200.0, 100.0, 50.0, 20.0, 10.0, 5.0, 1.0, 0.25, 0.10, 0.05].map((d) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        SizedBox(width: 56, child: Text(d >= 1 ? "P${d.toInt()}" : "${d.toStringAsFixed(2)}c", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        const SizedBox(width: 8),
                        const Text('x', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(
                          controller: tempCtrls[d],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            isDense: true, hintText: '0',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        )),
                        const SizedBox(width: 8),
                        SizedBox(width: 70, child: Text(
                          'P${(d * (int.tryParse(tempCtrls[d]?.text.trim() ?? '') ?? 0)).toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        )),
                      ]),
                    )),
                    const Divider(thickness: 2),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL COUNTED:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('P${total.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.purple.shade800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ZReportHistoryScreen(branch: widget.branch)));
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('View Z Report History', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple.shade700,
                    side: BorderSide(color: Colors.purple.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.home, size: 18),
                  label: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: total == 0 ? null : () async {
                    // 1. Copy denoms from temp controllers to persistent controllers
                    for (final d in DenominationRecord.phDenominations) {
                      _denomCtrls[d]?.text = tempCtrls[d]?.text ?? '';
                    }
                    // 2. Build denomination map
                    final denomMap = <double, int>{};
                    for (final d in DenominationRecord.phDenominations) {
                      final qty = int.tryParse(tempCtrls[d]?.text.trim() ?? "") ?? 0;
                      if (qty > 0) denomMap[d] = qty;
                    }
                    // 3. AWAIT both saves (so writes complete before dialog closes)
                    await DailyLockService.markCashDeclared();
                    await DailyLockService.saveCashDeclaredDenominations(denomMap);
                    // 4. Set _cashDeclared = true BEFORE pop (so Patch B doesn't auto-exit)
                    if (mounted) setState(() { _cashDeclared = true; });
                    // 5. Close dialog (returns control to initState's await)
                    if (mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.save, size: 22),
                  label: const Text('Submit & Save Count',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
