// lib/screens/cashier_lock/cash_adjustment_screen.dart
// Re-Declare cash for closed shifts (Manager only)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/cashier_session_model.dart';
import '../../models/denomination_model.dart';
import '../../models/user_model.dart';
import '../../services/cashier_session_service.dart';

class CashAdjustmentScreen extends StatefulWidget {
  final CashierSession session;
  const CashAdjustmentScreen({super.key, required this.session});

  @override
  State<CashAdjustmentScreen> createState() => _CashAdjustmentScreenState();
}

class _CashAdjustmentScreenState extends State<CashAdjustmentScreen> {
  // Step 1: Manager Authentication
  bool _authenticated = false;
  String _managerName = '';
  final _pinCtrl = TextEditingController();

  // Step 2: Re-Declare
  final Map<double, TextEditingController> _qtyCtrls = {};
  final _reasonCtrl = TextEditingController();
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    for (final d in DenominationRecord.phDenominations) {
      _qtyCtrls[d] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _reasonCtrl.dispose();
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _newTotal {
    double total = 0;
    for (final entry in _qtyCtrls.entries) {
      final qty = int.tryParse(entry.value.text.trim()) ?? 0;
      total += entry.key * qty;
    }
    return total;
  }

  double get _newVariance => _newTotal - widget.session.systemExpectedCash;

  Map<double, int> get _denominationsMap {
    final map = <double, int>{};
    for (final entry in _qtyCtrls.entries) {
      final qty = int.tryParse(entry.value.text.trim()) ?? 0;
      if (qty > 0) map[entry.key] = qty;
    }
    return map;
  }

  void _authenticate() {
    if (_pinCtrl.text.trim().isEmpty) {
      _snack('Enter Manager PIN', Colors.orange);
      return;
    }
    final mgr = AppUser.allUsers.where((u) =>
      (u.role == 'Admin' || u.role == 'Manager') &&
      u.pin == _pinCtrl.text.trim()
    ).firstOrNull;
    if (mgr == null) {
      _snack('Invalid Manager PIN', Colors.red);
      _pinCtrl.clear();
      return;
    }
    setState(() {
      _authenticated = true;
      _managerName = mgr.name;
    });
    _snack('Authenticated as ${mgr.name}', Colors.green);
  }

  Future<void> _submitAdjustment() async {
    if (_newTotal == 0) {
      _snack('Please enter the new cash count', Colors.orange);
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      _snack('Please provide reason for adjustment', Colors.orange);
      return;
    }

    setState(() => _processing = true);

    try {
      await CashierSessionService.adjustSession(
        sessionId: widget.session.id,
        originalDeclared: widget.session.endingCashDeclared,
        originalVariance: widget.session.variance,
        newDeclared: _newTotal,
        newVariance: _newVariance,
        adjustedBy: _managerName,
        reason: _reasonCtrl.text.trim(),
        newDenominations: _denominationsMap,
      );

      if (mounted) {
        _snack('Adjustment saved! Voucher updated.', Colors.green);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context, true);
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
      content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Re-Declare Cash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        backgroundColor: Colors.deepOrange[700],
        foregroundColor: Colors.white,
      ),
      body: _authenticated ? _adjustmentForm() : _authForm(),
    );
  }

  Widget _authForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 30),
        Icon(Icons.lock, size: 80, color: Colors.deepOrange[700]),
        const SizedBox(height: 16),
        const Text('Manager Authentication Required',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Only Admin or Manager can re-declare cash for closed shifts.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            border: Border.all(color: Colors.amber[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.info_outline, color: Colors.amber[800], size: 18),
              const SizedBox(width: 8),
              Text('Shift Info', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[900])),
            ]),
            const SizedBox(height: 8),
            Text('Cashier: ${widget.session.cashierName}', style: const TextStyle(fontSize: 12)),
            Text('Shift: ${widget.session.shiftId}', style: const TextStyle(fontSize: 11)),
            Text('Current Variance: ₱${widget.session.variance.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[700])),
          ]),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Manager PIN',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onSubmitted: (_) => _authenticate(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _authenticate,
            icon: const Icon(Icons.verified_user),
            label: const Text('Authenticate', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _adjustmentForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Manager badge
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.green[50], border: Border.all(color: Colors.green[200]!), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.verified_user, color: Colors.green[700], size: 18),
            const SizedBox(width: 8),
            Text('Authenticated: $_managerName', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800])),
          ]),
        ),
        const SizedBox(height: 16),

        // Original vs New comparison
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Original Declaration', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _row('Declared:', '₱${widget.session.endingCashDeclared.toStringAsFixed(2)}', Colors.blue[700]!),
            _row('Variance:', '₱${widget.session.variance.toStringAsFixed(2)}', Colors.red[700]!),
            const Divider(),
            const Text('New Declaration', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _row('New Counted:', '₱${_newTotal.toStringAsFixed(2)}', Colors.green[700]!),
            _row('New Variance:', '₱${_newVariance.toStringAsFixed(2)}',
              _newVariance == 0 ? Colors.green[700]! : Colors.orange[700]!),
          ]),
        ),
        const SizedBox(height: 16),

        // Denomination input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.calculate, color: Colors.green[700], size: 18),
              const SizedBox(width: 8),
              const Text('New Cash Count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text('₱${_newTotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
            ]),
            const Divider(),
            ..._buildDenomRows(DenominationRecord.phDenominations),
          ]),
        ),
        const SizedBox(height: 16),

        // Reason
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: const [
              Icon(Icons.edit_note, color: Colors.purple, size: 18),
              SizedBox(width: 8),
              Text('Reason for Adjustment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'e.g., Found ₱500 in cash drawer during investigation...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _processing ? null : _submitAdjustment,
            icon: _processing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save),
            label: Text(_processing ? 'Saving...' : 'Save Adjustment',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _buildDenomRows(List<double> denoms) {
    return denoms.map((d) {
      final qty = int.tryParse(_qtyCtrls[d]?.text.trim() ?? '') ?? 0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(width: 60, padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: d >= 50 ? Colors.blue[50] : Colors.orange[50], borderRadius: BorderRadius.circular(6)),
            child: Text(DenominationRecord.labelFor(d), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          const SizedBox(width: 8),
          const Text('×'),
          const SizedBox(width: 8),
          SizedBox(width: 60, child: TextField(
            controller: _qtyCtrls[d], keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 6)),
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(width: 8),
          const Text('='),
          const SizedBox(width: 8),
          Expanded(child: Text('₱${(d * qty).toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
      );
    }).toList();
  }

  Widget _row(String label, String value, Color color) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 12)),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}
