// lib/services/shift_reopen_service.dart
// 🔓 BIR-grade manager-authorized shift reopen
import 'package:flutter/material.dart';
import '../models/cashier_session_model.dart';
import '../helpers/database_helper.dart';
import '../services/daily_lock_service.dart';
import '../services/audit_log_service.dart';

class ShiftReopenService {
  /// Reopen a closed shift session with Manager PIN + reason
  /// Returns true if reopen was authorized & applied
  static Future<bool> reopenWithManagerPin({
    required BuildContext context,
    required CashierSession existingSession,
  }) async {
    // 1. Manager PIN dialog
    final managerUsername = await ManagerPinDialog.verify(
      context,
      title: 'Reopen Shift Authorization',
      actionLabel: 'Approve reopen for ${existingSession.cashierName}',
    );
    if (managerUsername == null) return false;
    if (!context.mounted) return false;

    // 2. Reason dialog
    final reasonData = await _showReasonDialog(context);
    if (reasonData == null) return false;

    final reason = reasonData['reason'] ?? '';
    final remarks = reasonData['remarks'] ?? '';

    try {
      // 3. Update existing session — reopen
      final db = await DatabaseHelper().database;
      final nowIso = DateTime.now().toIso8601String();
      await DatabaseHelper().updateCashierSession(existingSession.id, {
        'status': 'open',
        'closedAt': null,
        'endingCashDeclared': 0,
        'systemExpectedCash': 0,
        'variance': 0,
        'varianceType': 'balanced',
      });

      // 4. Audit log
      await AuditLogService.write(
        action: 'REOPEN_SHIFT',
        userId: existingSession.cashierId,
        role: 'Cashier',
        sessionId: existingSession.id,
        performedBy: managerUsername,
        performedByRole: 'Manager',
        targetUserName: existingSession.cashierName,
        reason: reason,
        remarks: remarks,
      );

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Reopen failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
      return false;
    }
  }

  /// Show reason dropdown + remarks for shift reopen
  static Future<Map<String, String>?> _showReasonDialog(BuildContext context) async {
    String selectedReason = 'Cashier returned to complete shift';
    final remarksCtrl = TextEditingController();
    final reasons = [
      'Cashier returned to complete shift',
      'Wrong shift closed by mistake',
      'Additional transactions needed',
      'Variance correction required',
      'Other (specify in remarks)',
    ];

    return await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(children: [
            Icon(Icons.lock_open, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 8),
            const Expanded(child: Text('Reopen Reason')),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Why is shift being reopened?',
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
              child: const Text('Confirm Reopen'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show the dialog informing user that shift is already closed
  /// + offer Manager-PIN reopen
  /// Returns true if reopen was completed
  static Future<bool> showAlreadyClosedDialog({
    required BuildContext context,
    required CashierSession existingSession,
  }) async {
    final closedTime = existingSession.closedAt != null
        ? '${existingSession.closedAt!.hour.toString().padLeft(2, '0')}:${existingSession.closedAt!.minute.toString().padLeft(2, '0')}'
        : '—';
    final endingCash = existingSession.endingCashDeclared.toStringAsFixed(2);
    final varianceLabel = existingSession.varianceType.toUpperCase();

    bool reopenRequested = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.block, color: Colors.red[700], size: 28),
          const SizedBox(width: 8),
          const Expanded(child: Text('Shift Already Closed', style: TextStyle(fontSize: 16))),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: const Text(
                  'End Shift already completed for today. You cannot open a new shift without Manager authorization.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Last shift details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              _detailRow('Cashier', existingSession.cashierName),
              _detailRow('Closed at', closedTime),
              _detailRow('Ending cash', 'PHP $endingCash'),
              _detailRow('Variance', varianceLabel),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              reopenRequested = true;
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.lock_open, size: 18),
            label: const Text('Reopen (Manager PIN)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (!reopenRequested) return false;
    if (!context.mounted) return false;

    return await reopenWithManagerPin(
      context: context,
      existingSession: existingSession,
    );
  }

  static Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
