// lib/screens/cashier_lock/cash_declaration_screen.dart
import '../../models/sync_queue_model.dart';
import '../../helpers/sync_bridge.dart';
import '../../services/daily_lock_service.dart';
import '../../helpers/database_helper.dart';
// End-of-shift cash declaration with denomination breakdown

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/cashier_session_model.dart';
import '../../models/denomination_model.dart';
import '../../services/cashier_session_service.dart';
import '../../models/user_model.dart';
import '../../utils/cash_variance_voucher_pdf.dart';

class CashDeclarationScreen extends StatefulWidget {
  final CashierSession session;
  final double systemExpectedCash;
  // Sales breakdown from current session
  final double cashSales;
  final double gcashSales;
  final double mayaSales;
  final double cardSales;
  final double totalRefunds;
  final double totalVoids;
  final double totalDiscounts;
  final double totalExchanges;
  final int transactionCount;

  const CashDeclarationScreen({
    super.key,
    required this.session,
    required this.systemExpectedCash,
    this.cashSales = 0,
    this.gcashSales = 0,
    this.mayaSales = 0,
    this.cardSales = 0,
    this.totalRefunds = 0,
    this.totalVoids = 0,
    this.totalDiscounts = 0,
    this.totalExchanges = 0,
    this.transactionCount = 0,
  });

  @override
  State<CashDeclarationScreen> createState() => _CashDeclarationScreenState();
}

class _CashDeclarationScreenState extends State<CashDeclarationScreen> {
  // Map denomination -> quantity controller
  final Map<double, TextEditingController> _qtyCtrls = {};
  bool _processing = false;
  bool _isDeclared = false;

  @override
  void initState() {
    super.initState();
    for (final d in DenominationRecord.phDenominations) {
      _qtyCtrls[d] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalCounted {
    double total = 0;
    for (final entry in _qtyCtrls.entries) {
      final qty = int.tryParse(entry.value.text.trim()) ?? 0;
      total += entry.key * qty;
    }
    return total;
  }

  double get _variance => _totalCounted - widget.systemExpectedCash;
  bool get _requiresIR => CashierSessionService.requiresIR(_variance);

  Map<double, int> get _denominationsMap {
    final map = <double, int>{};
    for (final entry in _qtyCtrls.entries) {
      final qty = int.tryParse(entry.value.text.trim()) ?? 0;
      if (qty > 0) map[entry.key] = qty;
    }
    return map;
  }

  Future<void> _submit() async {
    // 🔒 STRICT SECURITY: Require session owner's PIN before ending shift
    final pin = await _askCashierPin();
    if (pin == null) return; // User cancelled

    // Find session owner (must match exactly by cashierId or cashierName)
    final sessionOwner = AppUser.allUsers.where((u) =>
      u.username == widget.session.cashierId ||
      u.name == widget.session.cashierName ||
      u.id == widget.session.cashierId
    ).firstOrNull;

    if (sessionOwner == null) {
      _snack('🚫 Session owner not found. Cannot verify identity.', Colors.red);
      return;
    }

    // Verify PIN matches the session owner SPECIFICALLY
    if (sessionOwner.pin != pin) {
      _snack('🚫 Wrong PIN. Only ${widget.session.cashierName} can end this shift.', Colors.red);
      return;
    }

    if (_totalCounted == 0) {
      _snack('Please enter at least one denomination', Colors.orange);
      return;
    }

    // 🔒 BIR Blind Entry — First tap REVEALS variance, doesnt close session
    if (!_isDeclared) {
      setState(() => _isDeclared = true);
      _snack("🔓 Variance revealed. Review and confirm to end shift.", Colors.blue);
      return;
    }

    setState(() => _processing = true);

    try {
      if (!mounted) return;
      // ═══ ALWAYS GENERATE VOUCHER PDF (BALANCED OR VARIANCE) ═══
      await CashVarianceVoucherPDF.generate(
        context: context,
        session: widget.session,
        totalCounted: _totalCounted,
        systemExpected: widget.systemExpectedCash,
        variance: _variance,
        denominations: _denominationsMap,
      );

      // Small delay so user can save/share the PDF
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // After voucher generated, proceed based on variance
      if (_requiresIR) {
        // Variance > ₱50 → Need IR
        Navigator.pop(context, {
          'requireIR': true,
          'totalCounted': _totalCounted,
          'variance': _variance,
          'denominations': _denominationsMap,
        });
        return;
      }

      // Variance ≤ ₱50 → Close session directly
      await CashierSessionService.saveEndingDenominations(
        sessionId: widget.session.id,
        denominations: _denominationsMap,
      );

      await CashierSessionService.closeSession(
        sessionId: widget.session.id,
        endingCash: _totalCounted,
        systemExpected: widget.systemExpectedCash,
        variance: _variance,
      );

      if (mounted) {
        Navigator.pop(context, {
          'success': true,
          'totalCounted': _totalCounted,
          'variance': _variance,
          'denominations': _denominationsMap,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        _snack('Error: $e', Colors.red);
      }
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<String?> _askCashierPin() async {
    final pinCtrl = TextEditingController();
    bool obscure = true;
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.lock, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Expanded(child: Text('Confirm Identity', style: TextStyle(fontSize: 16))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cashier: ${widget.session.cashierName}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter your PIN to end this shift',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                obscureText: obscure,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Your PIN',
                  hintText: '••••••',
                  prefixIcon: const Icon(Icons.password),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setS(() => obscure = !obscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.red[700], size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Only YOU can end your own shift',
                        style: TextStyle(fontSize: 11, color: Colors.red[900], fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Confirm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, pinCtrl.text.trim()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return WillPopScope(
      onWillPop: () async {
        if (_isDeclared) {
          _snack("🔒 Cannot exit. Use Re-Declare or Submit & End Shift.", Colors.red);
          return false;
        }
        final exit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exit Cash Declaration?'),
            content: const Text('You must declare your cash to end your shift. Are you sure you want to exit?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Exit', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        return exit ?? false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          leading: _isDeclared ? const Padding(padding: EdgeInsets.all(14), child: Icon(Icons.lock_outline, color: Colors.white)) : null,
          title: const Text('End of Shift — Cash Declaration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: Colors.orange[800],
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shift info card
              _shiftInfoCard(),
              const SizedBox(height: 16),

              // Sales summary card
              if (_isDeclared) _salesSummaryCard(),
              const SizedBox(height: 16),

              // Denomination breakdown
              _denominationCard(),
              const SizedBox(height: 16),

              // Variance check
              if (_isDeclared) _varianceCard(),
              const SizedBox(height: 24),

              // Submit button
              // 🔄 Re-Declare button (Phase 2 only)
              if (_isDeclared) ...[
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _processing ? null : _reDeclareWithManagerPin,
                    icon: const Icon(Icons.refresh, size: 22),
                    label: const Text('🔄 Re-Declare Cash (Manager PIN)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange[800],
                      side: BorderSide(color: Colors.orange[800]!, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _submit,
                  icon: _processing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(!_isDeclared ? Icons.lock_outline : (_requiresIR ? Icons.warning : Icons.check), size: 24),
                  label: Text(
                    _processing
                      ? 'Processing...'
                      : !_isDeclared ? "🔒 Submit & Reveal Variance" : _requiresIR /* IR flow */
                        ? 'Continue to Incident Report'
                        : 'Submit & End Shift',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_isDeclared ? Colors.purple[700] : (_requiresIR ? Colors.red[700] : Colors.green[700]),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shiftInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue[700]!, Colors.blue[400]!]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.session.cashierName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  widget.session.shiftId.length > 20
                    ? '...${widget.session.shiftId.substring(widget.session.shiftId.length - 18)}'
                    : widget.session.shiftId,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.business, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text('Branch: ${widget.session.branch}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              const Spacer(),
              const Icon(Icons.access_time, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                'Opened: ${widget.session.openedAt.hour.toString().padLeft(2, "0")}:${widget.session.openedAt.minute.toString().padLeft(2, "0")}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _salesSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.purple[700], size: 18),
              const SizedBox(width: 8),
              const Text('Shift Sales Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${widget.transactionCount} txns',
                  style: TextStyle(fontSize: 11, color: Colors.purple[700], fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          _row('Beginning Cash', widget.session.beginningCash, color: Colors.blue[700]!),
          const Divider(height: 12),
          const Text('Payment Methods:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          _row('💵 Cash Sales', widget.cashSales, color: Colors.green[700]!),
          _row('📱 GCash', widget.gcashSales, color: Colors.blue[600]!),
          _row('💳 Maya', widget.mayaSales, color: Colors.green[600]!),
          _row('💳 Card', widget.cardSales, color: Colors.indigo[600]!),
          const Divider(height: 12),
          const Text('Deductions:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          _row('Refunds', widget.totalRefunds, color: Colors.red[700]!, isDeduction: true),
          _row('Voids', widget.totalVoids, color: Colors.orange[700]!, isDeduction: true),
          _row('Discounts', widget.totalDiscounts, color: Colors.purple[700]!, isDeduction: true),
          if (widget.totalExchanges > 0) _row('Exchanges', widget.totalExchanges, color: Colors.teal[700]!, isDeduction: true),
          const Divider(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate, color: Colors.amber[800], size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'System Expected Cash:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '₱${widget.systemExpectedCash.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber[900]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double value, {required Color color, bool isDeduction = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(
            isDeduction ? '(₱${value.toStringAsFixed(2)})' : '₱${value.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  Widget _denominationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: Colors.green[700], size: 18),
              const SizedBox(width: 8),
              const Text('Physical Cash Count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text(
                'Total: ₱${_totalCounted.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green[700]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Enter physical count for each denomination', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 8),
          const Divider(),
          // Bills section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('BILLS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[800], letterSpacing: 1.5)),
          ),
          ..._buildDenominationRows([1000, 500, 200, 100, 50, 20]),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('COINS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[800], letterSpacing: 1.5)),
          ),
          ..._buildDenominationRows([10, 5, 1, 0.25, 0.10, 0.05]),
        ],
      ),
    );
  }

  List<Widget> _buildDenominationRows(List<double> denoms) {
    return denoms.map((denom) {
      final qty = int.tryParse(_qtyCtrls[denom]?.text.trim() ?? '') ?? 0;
      final lineTotal = denom * qty;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // Denomination label
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: denom >= 50 ? Colors.blue[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                DenominationRecord.labelFor(denom),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: denom >= 50 ? Colors.blue[800] : Colors.orange[800],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            const Text('×', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            // Quantity input
            SizedBox(
              width: 70,
              child: TextField(
                controller: _qtyCtrls[denom],
                readOnly: _isDeclared,
                enabled: !_isDeclared,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '0',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            const Text('=', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '₱${lineTotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: qty > 0 ? Colors.green[700] : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _varianceCard() {
    final color = _variance == 0
      ? Colors.green
      : (_requiresIR ? Colors.red : Colors.orange);
    final icon = _variance == 0
      ? Icons.check_circle
      : (_requiresIR ? Icons.warning : Icons.info);
    final status = _variance == 0
      ? 'BALANCED ✓'
      : (_variance > 0 ? 'OVER (+₱${_variance.abs().toStringAsFixed(2)})' : 'SHORT (-₱${_variance.abs().toStringAsFixed(2)})');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color[700]!, color[400]!]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Text('Variance Check', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  status,
                  style: TextStyle(color: color[800], fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 10),
          Row(children: [
            const Expanded(child: Text('Physical Count:', style: TextStyle(color: Colors.white, fontSize: 12))),
            Text('₱${_totalCounted.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Expanded(child: Text('System Expected:', style: TextStyle(color: Colors.white, fontSize: 12))),
            Text('₱${widget.systemExpectedCash.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 6),
          Container(height: 1, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 6),
          Row(children: [
            const Expanded(child: Text('Variance:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
            Text(
              _variance == 0 ? '₱0.00' : '${_variance > 0 ? "+" : "-"}₱${_variance.abs().toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ]),
          if (_requiresIR) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Variance exceeds ₱50 threshold. Incident Report (IR) required.',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 🔄 Re-Declare Cash — Manager PIN + Reason + Audit Log
  Future<void> _reDeclareWithManagerPin() async {
    // 1. Verify Manager PIN
    final managerUsername = await ManagerPinDialog.verify(
      context,
      title: "Re-Declare Cash Authorization",
      actionLabel: "Approve Re-Declare for ${widget.session.cashierName}",
    );
    if (managerUsername == null) return;
    if (!mounted) return;

    // 2. Ask for reason
    final reasonData = await _showReasonDialog();
    if (reasonData == null) return;
    final reason = reasonData['reason'] ?? '';
    final remarks = reasonData['remarks'] ?? '';

    // 3. Log to incident_reports (audit trail)
    try {
      final db = await DatabaseHelper().database;
      final irId = 'IR-RE-${DateTime.now().millisecondsSinceEpoch}';
      await db.insert('incident_reports', {
        'id': irId,
        'irNumber': irId,
        'sessionId': widget.session.id,
        'cashierId': widget.session.cashierId,
        'cashierName': widget.session.cashierName,
        'branch': widget.session.branch,
        'variance': _variance,
        'varianceType': _variance > 0 ? 'over' : (_variance < 0 ? 'short' : 'balanced'),
        'reason': 'Re-Declare: $reason',
        'remarks': remarks,
        'createdBy': managerUsername,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'status': 'authorized',
      });
      // 🌐 Sync audit trail to Firebase
      try {
        await SyncBridge.enqueueAuditTrail({
          'id': 'AUDIT-RE-${DateTime.now().millisecondsSinceEpoch}',
          'action': 'RE_DECLARE_CASH',
          'sessionId': widget.session.id,
          'entityType': 'cashier_session',
          'entityId': widget.session.id,
          'performedBy': managerUsername,
          'performedByRole': 'Manager',
          'targetUserName': widget.session.cashierName,
          'reason': reason,
          'remarks': remarks,
          'oldValue': _variance.toStringAsFixed(2),
          'newValue': '',
          'branch': widget.session.branch,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'pinVerified': true,
        }, op: SyncOp.create);
      } catch (_) {}
    } catch (e) {
      _snack('⚠️ Audit log failed: $e', Colors.orange);
    }

    // 4. Reset to Phase 1: clear all denominations + unlock
    setState(() {
      _isDeclared = false;
      for (final ctrl in _qtyCtrls.values) {
        ctrl.text = '';
      }
    });
    _snack('�� Re-Declare authorized by $managerUsername. Please count again.', Colors.blue);
  }

  /// 📝 Reason dialog for Re-Declare
  Future<Map<String, String>?> _showReasonDialog() async {
    String selectedReason = 'Cashier typed wrong quantity';
    final remarksCtrl = TextEditingController();
    final reasons = [
      'Cashier typed wrong quantity',
      'Drawer counted twice (duplicate)',
      'Forgot to count coins',
      'Mixed up beginning float',
      'Other (specify in remarks)',
    ];

    return await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(children: [
            Icon(Icons.edit_note, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 8),
            const Expanded(child: Text('Re-Declare Reason')),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Why is Re-Declare needed?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...reasons.map((r) => RadioListTile<String>(
                  title: Text(r, style: const TextStyle(fontSize: 13)),
                  value: r,
                  groupValue: selectedReason,
                  onChanged: (v) => setDialogState(() => selectedReason = v ?? selectedReason),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )),
                const SizedBox(height: 8),
                TextField(
                  controller: remarksCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Additional remarks (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, {
                'reason': selectedReason,
                'remarks': remarksCtrl.text.trim(),
              }),
              child: const Text('Confirm & Re-Declare'),
            ),
          ],
        ),
      ),
    );
  }
}
