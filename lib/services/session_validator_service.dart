// lib/services/session_validator_service.dart
// 🔒 BIR-grade session validation
import '../helpers/database_helper.dart';
import '../models/cashier_session_model.dart';
import '../models/user_model.dart';
import '../services/audit_log_service.dart';

/// Result of session validation checks
class SessionValidationResult {
  final bool allowed;
  final bool requiresOverride;
  final bool canResume;
  final String reason;
  final String action;
  final CashierSession? existingSession;
  final List<CashierSession> activeSessions;

  SessionValidationResult({
    this.allowed = false,
    this.requiresOverride = false,
    this.canResume = false,
    this.reason = '',
    this.action = '',
    this.existingSession,
    this.activeSessions = const [],
  });

  factory SessionValidationResult.allowed() =>
      SessionValidationResult(allowed: true);

  factory SessionValidationResult.blocked({
    required String reason,
    String action = 'blocked',
    List<CashierSession>? activeSessions,
  }) =>
      SessionValidationResult(
        reason: reason,
        action: action,
        activeSessions: activeSessions ?? const [],
      );

  factory SessionValidationResult.requiresOverride({
    required String reason,
    required String action,
    CashierSession? existingSession,
  }) =>
      SessionValidationResult(
        requiresOverride: true,
        reason: reason,
        action: action,
        existingSession: existingSession,
      );

  factory SessionValidationResult.resumable({
    required CashierSession existingSession,
  }) =>
      SessionValidationResult(
        canResume: true,
        existingSession: existingSession,
      );
}

class SessionValidator {
  /// CHECK 1: Can user transact?
  /// Returns true if allowed, false otherwise (logs to audit)
  static Future<bool> canTransact(AppUser user) async {
    // Role permission check
    if (user.role == 'Cashier') return true;
    
    if (['Admin', 'Manager', 'Supervisor'].contains(user.role)) {
      if (!user.allowPosTransaction) {
        await AuditLogService.write(
          action: 'UNAUTHORIZED_TRANSACTION_ATTEMPT',
          userId: user.id,
          role: user.role,
          reason: 'Role does not have allowPosTransaction permission',
        );
        return false;
      }
    } else {
      return false; // Unknown role
    }

    // Active session check
    final active = await getActiveSessionsForUser(user.id);
    if (active.isEmpty) {
      await AuditLogService.write(
        action: 'FORCE_BEGINNING_CASH',
        userId: user.id,
        role: user.role,
        reason: 'No active cashier session — must declare Beginning Cash',
      );
      return false;
    }

    return true;
  }

  /// CHECK 2: Get all ACTIVE cashier sessions (open or declared)
  static Future<List<CashierSession>> getAllActiveSessions() async {
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'cashier_sessions',
        where: "status IN (?, ?)",
        whereArgs: ['open', 'declared'],
      );
      return rows.map((r) => CashierSession.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// CHECK 3: Get active sessions for a specific user
  static Future<List<CashierSession>> getActiveSessionsForUser(
      String userId) async {
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'cashier_sessions',
        where: "cashierId = ? AND status IN (?, ?)",
        whereArgs: [userId, 'open', 'declared'],
      );
      return rows.map((r) => CashierSession.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// CHECK 4: Get closed sessions for user today
  static Future<List<CashierSession>> getClosedSessionsToday(
      String userId) async {
    try {
      final db = await DatabaseHelper().database;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await db.query(
        'cashier_sessions',
        where: "cashierId = ? AND status = ? AND date(openedAt) = ?",
        whereArgs: [userId, 'closed', today],
      );
      return rows.map((r) => CashierSession.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// CHECK 5: Can manager generate Z Report?
  static Future<SessionValidationResult> canGenerateZReport() async {
    final activeSessions = await getAllActiveSessions();
    if (activeSessions.isNotEmpty) {
      await AuditLogService.write(
        action: 'BLOCK_Z_REPORT_ACTIVE_CASHIER',
        userId: 'SYSTEM',
        role: 'SYSTEM',
        reason: 'Active cashier sessions exist',
        remarks: 'Active count: ${activeSessions.length}',
      );
      return SessionValidationResult.blocked(
        reason: 'Cannot generate Z Report. ${activeSessions.length} cashier(s) still active.',
        action: 'active_sessions_must_close',
        activeSessions: activeSessions,
      );
    }
    return SessionValidationResult.allowed();
  }

  /// CHECK 6: Can user open new shift?
  static Future<SessionValidationResult> canOpenShift(String userId) async {
    // Check existing active session
    final activeSessions = await getActiveSessionsForUser(userId);
    if (activeSessions.isNotEmpty) {
      return SessionValidationResult.resumable(
        existingSession: activeSessions.first,
      );
    }

    // Check closed session today
    final closedToday = await getClosedSessionsToday(userId);
    if (closedToday.isNotEmpty) {
      await AuditLogService.write(
        action: 'BLOCK_SECOND_SHIFT',
        userId: userId,
        role: '',
        reason: 'End Shift already completed for today',
      );
      return SessionValidationResult.requiresOverride(
        reason: 'End Shift already completed for today',
        action: 'manager_pin_required',
        existingSession: closedToday.first,
      );
    }

    return SessionValidationResult.allowed();
  }
}
