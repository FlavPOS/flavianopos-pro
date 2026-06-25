// lib/services/audit_log_service.dart
// 🔒 BIR-grade audit logging for session events
import '../helpers/database_helper.dart';
import '../helpers/sync_bridge.dart';
import '../models/sync_queue_model.dart';
import '../services/device_assignment_service.dart';

class AuditLogService {
  /// Write a session audit event to local DB + Firebase
  static Future<void> write({
    required String action,
    required String userId,
    String role = '',
    String sessionId = '',
    String performedBy = '',
    String performedByRole = '',
    String targetUserName = '',
    String reason = '',
    String remarks = '',
    String oldValue = '',
    String newValue = '',
  }) async {
    try {
      final assign = await DeviceAssignmentService().read();
      final branchName = assign['branchName'] ?? '';
      final branchId = assign['branchId'] ?? '';
      final deviceId = assign['deviceId'] ?? '';
      final auditId = 'AUDIT-${DateTime.now().millisecondsSinceEpoch}';
      final timestamp = DateTime.now().toUtc().toIso8601String();

      final record = {
        'id': auditId,
        'action': action,
        'userId': userId,
        'role': role,
        'sessionId': sessionId,
        'performedBy': performedBy.isEmpty ? userId : performedBy,
        'performedByRole': performedByRole.isEmpty ? role : performedByRole,
        'targetUserName': targetUserName,
        'reason': reason,
        'remarks': remarks,
        'oldValue': oldValue,
        'newValue': newValue,
        'branch': branchName,
        'branchId': branchId,
        'deviceId': deviceId,
        'timestamp': timestamp,
        'synced': 0,
      };

      // Save to local
      final db = await DatabaseHelper().database;
      await db.insert('session_audit_log', record);

      // Sync to Firebase
      try {
        await SyncBridge.enqueueAuditTrail(record, op: SyncOp.create);
      } catch (_) {}
    } catch (_) {
      // Audit logging must NEVER throw — silent fail
    }
  }
}
