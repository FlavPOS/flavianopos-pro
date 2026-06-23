// lib/screens/cashier_lock/beginning_cash_screen.dart

import 'package:flutter/material.dart';
import '../../services/daily_lock_service.dart';
import 'package:flutter/services.dart';
import '../../services/cashier_session_service.dart';
import '../../models/cashier_session_model.dart';

class BeginningCashScreen extends StatefulWidget {
  final String cashierId;
  final String cashierName;
  final String branch;
  const BeginningCashScreen({
    super.key,
    required this.cashierId,
    required this.cashierName,
    required this.branch,
  });

  @override
  State<BeginningCashScreen> createState() => _BeginningCashScreenState();
}

class _BeginningCashScreenState extends State<BeginningCashScreen> {
  final _amountCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  String _source = 'Vault';
  bool _processing = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? -1;
    if (amount < 0) {
      _snack('Please enter a valid amount', Colors.red);
      return;
    }

    setState(() => _processing = true);
    try {
      final session = await CashierSessionService.openSession(
        cashierId: widget.cashierId,
        cashierName: widget.cashierName,
        branch: widget.branch,
        beginningCash: amount,
        source: _source,
        remarks: _remarksCtrl.text.trim(),
      );

      if (mounted) {
        _snack('Shift opened! Beginning cash: ₱${amount.toStringAsFixed(2)}', Colors.green);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context, session);
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: DailyLockService.isLocked(),
      builder: (context, snap) {
        if (snap.data == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final override = await DailyLockService.showLockDialog(context, action: "open new shift");
            if (!override && context.mounted) Navigator.pop(context);
          });
          return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock_outline, size: 64, color: Colors.orange.shade700), const SizedBox(height: 16), const Text("End-of-Day Lock Active", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(DailyLockService.unlockMessage(), style: const TextStyle(fontSize: 14, color: Colors.black54))]))));
        }
        return _originalBuild(context);
      },
    );
  }

  Widget _originalBuild(BuildContext context) {
    final timeOfDay = DateTime.now().hour;
    String greeting;
    if (timeOfDay < 12) {
      greeting = 'Good morning';
    } else if (timeOfDay < 18) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return WillPopScope(
      onWillPop: () async => false,  // Cannot back out!
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Logo / Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[700]!, Colors.green[400]!],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet, size: 60, color: Colors.white),
                ).animate(),
                const SizedBox(height: 24),

                // Greeting
                Text(
                  '$greeting,',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                Text(
                  widget.cashierName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Branch: ${widget.branch}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please declare your beginning cash to start your shift',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Source dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.source, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Source of Cash', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            DropdownButton<String>(
                              value: _source,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 'Vault', child: Text('🏦 Vault')),
                                DropdownMenuItem(value: 'Previous Turnover', child: Text('🔄 Previous Cash Turnover')),
                              ],
                              onChanged: (v) => setState(() => _source = v ?? 'Vault'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Amount input
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_money, color: Colors.green[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Beginning Cash Amount', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            TextField(
                              controller: _amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                prefixText: '₱ ',
                                prefixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                border: InputBorder.none,
                              ),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Remarks
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
                  ),
                  child: TextField(
                    controller: _remarksCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Remarks (optional)',
                      hintText: 'Add notes about this opening...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _processing ? null : _submit,
                    icon: _processing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_open, size: 24),
                    label: Text(
                      _processing ? 'Opening...' : 'Confirm & Start Shift',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Warning note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange[800], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You cannot process sales until beginning cash is declared.',
                          style: TextStyle(fontSize: 11, color: Colors.orange[900], fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Extension for animation (minimal, no extra package)
extension on Widget {
  Widget animate() => this;
}
