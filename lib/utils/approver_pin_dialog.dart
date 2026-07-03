// lib/utils/approver_pin_dialog.dart
// Unified PIN dialog for Receive Delivery approval actions
import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import 'receive_delivery_theme.dart';

Future<bool> showApproverPinDialog(BuildContext context, {
  Color themeColor = ReceiveDeliveryTheme.blueSubmitted,
  String title = 'Approver PIN Required',
  String subtitle = 'Only Supervisor, Manager, or Admin can proceed.',
}) async {
  final pinCtrl = TextEditingController();
  bool obscure = true;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateD) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ReceiveDeliveryTheme.radiusLarge)),
        title: Row(children: [
          Icon(Icons.lock_outline, color: themeColor, size: 24),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: ReceiveDeliveryTheme.titleLarge)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: ReceiveDeliveryTheme.caption),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              obscureText: obscure,
              keyboardType: TextInputType.number,
              autofocus: true,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Enter PIN',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(ReceiveDeliveryTheme.radiusSmall)),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setStateD(() => obscure = !obscure),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              if (pin.isEmpty) return;
              final users = await DatabaseHelper().getAllUsers();
              final valid = users.any((u) {
                final role = (u['role'] ?? '').toString().toLowerCase();
                final userPin = (u['pin'] ?? '').toString();
                final active = u['isActive'] == 1 || u['isActive'] == true;
                final auth = role.contains('supervisor') || role.contains('manager') || role.contains('admin');
                return active && auth && userPin == pin;
              });
              if (valid) {
                Navigator.pop(ctx, true);
              } else {
                ReceiveDeliveryTheme.showError(ctx, 'Invalid PIN or insufficient role');
              }
            },
            style: ReceiveDeliveryTheme.primaryButton(themeColor),
            child: const Text('Verify'),
          ),
        ],
      ),
    ),
  );
  return result == true;
}
