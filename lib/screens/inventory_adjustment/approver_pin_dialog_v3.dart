import 'package:flutter/material.dart';
import '../../models/user_model.dart';

class ApproverPinResult {
  final String userName;
  final String userPin;
  final String userRole;
  const ApproverPinResult({
    required this.userName,
    required this.userPin,
    required this.userRole,
  });
}

class ApproverPinDialog {
  static Future<ApproverPinResult?> show({
    required BuildContext context,
    required String title,
    required Color headerColor,
    List<String> allowedRoles = const ['Supervisor', 'Manager', 'Admin'],
    String? subtitle,
  }) async {
    final pinCtrl = TextEditingController();
    String? errorMsg;

    return showDialog<ApproverPinResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setD) {
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.security_rounded,
                          color: Colors.white, size: 30),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Allowed roles: ${allowedRoles.join(", ")}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: pinCtrl,
                        obscureText: true,
                        maxLength: 6,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          errorText: errorMsg,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: headerColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              final pin = pinCtrl.text.trim();
                              if (pin.isEmpty) {
                                setD(() => errorMsg = 'Enter PIN');
                                return;
                              }
                              final user = AppUser.allUsers.where((u) =>
                                  u.pin == pin &&
                                  allowedRoles.contains(u.role)
                              ).firstOrNull;
                              if (user == null) {
                                setD(() => errorMsg = 'Invalid PIN or role');
                                return;
                              }
                              Navigator.pop(
                                  ctx,
                                  ApproverPinResult(
                                    userName: user.name,
                                    userPin: user.pin,
                                    userRole: user.role,
                                  ));
                            },
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}
