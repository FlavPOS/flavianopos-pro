// lib/utils/approver_pin_dialog.dart
// Unified beautiful PIN dialog matching Verify User design
import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import 'receive_delivery_theme.dart';

Future<Map<String, String>?> showApproverPinDialog(BuildContext context, {
  Color themeColor = ReceiveDeliveryTheme.blueSubmitted,
  String title = 'Verify User',
  String subtitle = 'Enter your PIN to proceed',
  String actionLabel = 'Verify',
  IconData actionIcon = Icons.check_circle_outline,
}) async {
  final pinCtrl = TextEditingController();
  bool obscure = true;

  final result = await showDialog<Map<String, String>?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateD) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ═══ HEADER BANNER (colored) ═══
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.lock_outline, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
            ),

            // ═══ BODY ═══
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Person icon
                Container(
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.person_pin_circle, color: themeColor, size: 48),
                ),
                const SizedBox(height: 4),

                // Title + subtitle
                Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Only Supervisor, Manager, or Admin can proceed',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),

                const SizedBox(height: 20),

                // PIN input
                TextField(
                  controller: pinCtrl,
                  obscureText: obscure,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '* * * * * *',
                    hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 8),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: themeColor, width: 1.5)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: themeColor, width: 1.5)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: themeColor, width: 2)),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                        color: themeColor, size: 20),
                      onPressed: () => setStateD(() => obscure = !obscure)),
                  ),
                ),
                const SizedBox(height: 20),

                // ═══ ACTION ROW: Cancel + Verify (side by side) ═══
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[400]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: Icon(actionIcon, color: Colors.white, size: 20),
                      label: Text(actionLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final pin = pinCtrl.text.trim();
                        if (pin.isEmpty) return;
                        final users = await DatabaseHelper().getAllUsers();
                        Map<String, String>? matchedUser;
                        for (final u in users) {
                          final role = (u['role'] ?? '').toString().toLowerCase();
                          final userPin = (u['pin'] ?? '').toString();
                          final active = u['isActive'] == 1 || u['isActive'] == true;
                          final auth = role.contains('supervisor') || role.contains('manager') || role.contains('admin');
                          if (active && auth && userPin == pin) {
                            matchedUser = {
                              'name': (u['fullName'] ?? 'Unknown').toString(),
                              'role': (u['role'] ?? '').toString(),
                              'id': (u['id'] ?? '').toString(),
                            };
                            break;
                          }
                        }
                        if (matchedUser != null) {
                          Navigator.pop(ctx, matchedUser);
                        } else {
                          ReceiveDeliveryTheme.showError(ctx, 'Invalid PIN or insufficient role');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ],
        ),
      ),
    ),
  );
  return result;
}
