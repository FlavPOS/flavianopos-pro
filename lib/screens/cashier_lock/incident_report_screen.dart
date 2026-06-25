// lib/screens/cashier_lock/incident_report_screen.dart
// Incident Report screen for cash variance > ₱50

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/cashier_session_model.dart';
import '../../models/user_model.dart';
import '../../services/cashier_session_service.dart';

class IncidentReportScreen extends StatefulWidget {
  final CashierSession session;
  final double totalCounted;
  final double systemExpected;
  final double variance;
  final Map<double, int> denominations;

  const IncidentReportScreen({
    super.key,
    required this.session,
    required this.totalCounted,
    required this.systemExpected,
    required this.variance,
    required this.denominations,
  });

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  String _selectedReason = 'Customer overcharged';
  final _remarksCtrl = TextEditingController();
  bool _processing = false;

  static const List<String> _reasons = [
    'Customer overcharged',
    'Customer undercharged',
    'Wrong change given',
    'Lost/Stolen money',
    'Cash deposit not recorded',
    'Refund not in system',
    'Counterfeit bill received',
    'Cash drawer accidentally opened',
    'System error / miscalculation',
    'Other (specify in remarks)',
  ];

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  String get _varianceTypeLabel => widget.variance > 0 ? 'OVER' : 'SHORT';

  Future<void> _submit() async {
    if (_remarksCtrl.text.trim().length < 50) {
      _snack('Please provide detailed explanation (min 50 characters)', Colors.orange);
      return;
    }


    setState(() => _processing = true);

    try {
      // Save denominations
      await CashierSessionService.saveEndingDenominations(
        sessionId: widget.session.id,
        denominations: widget.denominations,
      );

      // Create Incident Report
      await CashierSessionService.createIncidentReport(
        sessionId: widget.session.id,
        cashierId: widget.session.cashierId,
        cashierName: widget.session.cashierName,
        branch: widget.session.branch,
        variance: widget.variance,
        reason: _selectedReason,
        remarks: _remarksCtrl.text.trim(),
        createdBy: widget.session.cashierName,
      );

      // Close the session
      await CashierSessionService.closeSession(
        sessionId: widget.session.id,
        endingCash: widget.totalCounted,
        systemExpected: widget.systemExpected,
        variance: widget.variance,
      );

      if (mounted) {
        Navigator.pop(context, {
          'success': true,
          'irFiled': true,
          'totalCounted': widget.totalCounted,
          'variance': widget.variance,
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _snack('🔒 Cannot exit. File IR or use Re-Declare to recount.', Colors.red);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const Padding(padding: EdgeInsets.all(14), child: Icon(Icons.lock_outline, color: Colors.white)),
          title: const Text('Incident Report — Cash Variance',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          backgroundColor: Colors.red[800],
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // IR Header
              _headerCard(),
              const SizedBox(height: 16),

              // Variance Details
              _varianceCard(),
              const SizedBox(height: 16),

              // Reason Dropdown
              _reasonCard(),
              const SizedBox(height: 16),

              // Remarks
              _remarksCard(),
              const SizedBox(height: 16),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _submit,
                  icon: _processing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file, size: 24),
                  label: Text(
                    _processing ? 'Filing IR...' : 'Submit IR & End Shift',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Warning
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber[800], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This IR will be reviewed by management. Please provide accurate details.',
                        style: TextStyle(fontSize: 11, color: Colors.amber[900], fontWeight: FontWeight.w500),
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

  Widget _headerCard() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}';
    final timeStr = '${now.hour.toString().padLeft(2, "0")}${now.minute.toString().padLeft(2, "0")}${now.second.toString().padLeft(2, "0")}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.red[800]!, Colors.red[500]!]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'IR-$dateStr-$timeStr',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.2),
            )),
          ]),
          const Divider(color: Colors.white24, height: 16),
          _infoRow(Icons.person, 'Cashier', widget.session.cashierName),
          _infoRow(Icons.business, 'Branch', widget.session.branch),
          _infoRow(Icons.receipt, 'Shift ID', widget.session.shiftId.length > 30
            ? '...${widget.session.shiftId.substring(widget.session.shiftId.length - 28)}'
            : widget.session.shiftId),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _varianceCard() {
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
          Row(children: [
            Icon(Icons.attach_money, color: Colors.orange[800], size: 18),
            const SizedBox(width: 8),
            const Text('Variance Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
          const Divider(height: 16),
          _row('Expected:', '₱${widget.systemExpected.toStringAsFixed(2)}', Colors.blue[700]!),
          const SizedBox(height: 4),
          _row('Actual:', '₱${widget.totalCounted.toStringAsFixed(2)}', Colors.green[700]!),
          const Divider(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.variance > 0 ? Colors.orange[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.variance > 0 ? Colors.orange[200]! : Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  widget.variance > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  color: widget.variance > 0 ? Colors.orange[800] : Colors.red[800],
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Variance ($_varianceTypeLabel)', style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: widget.variance > 0 ? Colors.orange[900] : Colors.red[900],
                      )),
                      Text(
                        '${widget.variance > 0 ? "+" : ""}₱${widget.variance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: widget.variance > 0 ? Colors.orange[800] : Colors.red[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _reasonCard() {
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
          Row(children: [
            Icon(Icons.notes, color: Colors.blue[700], size: 18),
            const SizedBox(width: 8),
            const Text('Reason for Variance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              value: _selectedReason,
              isExpanded: true,
              underline: const SizedBox(),
              items: _reasons.map((r) => DropdownMenuItem(
                value: r,
                child: Text(r, style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: (v) => setState(() => _selectedReason = v ?? _reasons.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _remarksCard() {
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
          Row(children: [
            Icon(Icons.edit_note, color: Colors.purple[700], size: 18),
            const SizedBox(width: 8),
            const Text('Your Detailed Explanation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _remarksCtrl,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Provide detailed explanation of what happened...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }

}
