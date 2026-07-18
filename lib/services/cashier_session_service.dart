// lib/services/cashier_session_service.dart
import '../models/sync_queue_model.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/sync_bridge.dart';

import '../helpers/database_helper.dart';
import '../models/cashier_session_model.dart';
import '../models/denomination_model.dart';
import '../models/incident_report_model.dart';

class CashierSessionService {
  /// Get active session for cashier, or null if none
  static Future<CashierSession?> getActiveSession(String cashierId) async {
    final row = await DatabaseHelper().getActiveSession(cashierId);
    return row != null ? CashierSession.fromMap(row) : null;
  }

  /// Open a new session (Beginning Cash)
  static Future<CashierSession> openSession({
    required String cashierId,
    required String cashierName,
    required String branch,
    required double beginningCash,
    required String source,
    String remarks = '',
  }) async {
    final now = DateTime.now();
    final shiftId = CashierSession.generateShiftId(cashierId);
    final session = CashierSession(
      id: 'SES-${now.millisecondsSinceEpoch}',
      shiftId: shiftId,
      cashierId: cashierId,
      cashierName: cashierName,
      branch: branch,
      beginningCash: beginningCash,
      beginningSource: source,
      beginningRemarks: remarks,
      status: 'open',
      openedAt: now,
    );
    await DatabaseHelper().insertCashierSession(session.toMap());
    return session;
  }

  /// Save beginning denomination breakdown
  static Future<void> saveBeginningDenominations({
    required String sessionId,
    required Map<double, int> denominations,
  }) async {
    final now = DateTime.now();
    final records = denominations.entries.where((e) => e.value > 0).map((e) => DenominationRecord(
      sessionId: sessionId, type: 'beginning',
      denomination: e.key, quantity: e.value,
      total: e.key * e.value, createdAt: now,
    ).toMap()).toList();
    if (records.isNotEmpty) {
      await DatabaseHelper().insertDenominationBatch(records);
    }
  }

  /// Save ending denomination breakdown
  static Future<void> saveEndingDenominations({
    required String sessionId,
    required Map<double, int> denominations,
  }) async {
    final now = DateTime.now();
    final records = denominations.entries.where((e) => e.value > 0).map((e) => DenominationRecord(
      sessionId: sessionId, type: 'ending',
      denomination: e.key, quantity: e.value,
      total: e.key * e.value, createdAt: now,
    ).toMap()).toList();
    if (records.isNotEmpty) {
      await DatabaseHelper().insertDenominationBatch(records);
    }
  }

  /// Update session sales totals during shift
  static Future<void> updateSessionTotals(String sessionId, Map<String, dynamic> totals) async {
    await DatabaseHelper().updateCashierSession(sessionId, totals);
  }

  /// Close the session (after declaration)
  static Future<void> closeSession({
    required String sessionId,
    required double endingCash,
    required double systemExpected,
    required double variance,
  }) async {
    // v153: Expire all active held transactions for this shift before closing
    try {
      final expiredCount = await DatabaseHelper().expireHeldTransactionsForShift(sessionId);
      if (expiredCount > 0) {
        // Log for audit trail
        // ignore: avoid_print
        print('[v153] Expired ' + expiredCount.toString() + ' held transactions for shift ' + sessionId);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[v153] Failed to expire held transactions: ' + e.toString());
    }

        final varianceType = variance == 0 ? 'balanced' : (variance > 0 ? 'over' : 'short');
    await DatabaseHelper().updateCashierSession(sessionId, {
      'endingCashDeclared': endingCash,
      'systemExpectedCash': systemExpected,
      'variance': variance,
      'varianceType': varianceType,
      'status': 'closed',
      'closedAt': DateTime.now().toIso8601String(),
    });

    // 🌐 Sync to Firebase (multi-store)
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query('cashier_sessions', where: 'id = ?', whereArgs: [sessionId], limit: 1);
      if (rows.isNotEmpty) {
        final updated = CashierSession.fromMap(rows.first);
        await SyncBridge.enqueueCashierSession(updated, op: SyncOp.update);
      }
    } catch (e) {
      // Sync failure shouldn't break shift close
    }
  }

  /// Save Incident Report
  static Future<IncidentReport> createIncidentReport({
    required String sessionId,
    required String cashierId,
    required String cashierName,
    required String branch,
    required double variance,
    required String reason,
    String remarks = '',
    String createdBy = '',
  }) async {
    final now = DateTime.now();
    final ir = IncidentReport(
      id: 'IR-${now.millisecondsSinceEpoch}',
      irNumber: IncidentReport.generateIRNumber(),
      sessionId: sessionId,
      cashierId: cashierId,
      cashierName: cashierName,
      branch: branch,
      variance: variance,
      varianceType: variance > 0 ? 'over' : 'short',
      reason: reason,
      remarks: remarks,
      createdBy: createdBy,
      createdAt: now,
    );
    await DatabaseHelper().insertIncidentReport(ir.toMap());
    try { await SyncBridge.enqueueIncidentReport(ir, op: SyncOp.create); } catch (_) {}
    return ir;
  }

  /// Check if IR is required (variance > ₱50)
  static bool requiresIR(double variance) => variance.abs() > 50;

  /// Adjust a closed session — used when variance was wrongly declared and cash was found
  static Future<void> adjustSession({
    required String sessionId,
    required double originalDeclared,
    required double originalVariance,
    required double newDeclared,
    required double newVariance,
    required String adjustedBy,
    required String reason,
    required Map<double, int> newDenominations,
  }) async {
    final now = DateTime.now();
    final newVarianceType = newVariance == 0 ? 'balanced' : (newVariance > 0 ? 'over' : 'short');

    // Delete old ending denominations
    final db = await DatabaseHelper().database;
    await db.delete('denomination_records', where: 'sessionId = ? AND type = ?', whereArgs: [sessionId, 'ending']);

    // Save new ending denominations
    await saveEndingDenominations(sessionId: sessionId, denominations: newDenominations);

    // Update session with adjustment data
    await DatabaseHelper().updateCashierSession(sessionId, {
      'endingCashDeclared': newDeclared,
      'variance': newVariance,
      'varianceType': newVarianceType,
      'originalDeclared': originalDeclared,
      'originalVariance': originalVariance,
      'adjustedBy': adjustedBy,
      'adjustedAt': now.toIso8601String(),
      'adjustmentReason': reason,
      'wasAdjusted': 1,
    });

    // RE-DECLARE FIREBASE SYNC — push updated session + IR to cloud
    try {
    
    // DEBUG SYNC TRACE — verify setup mode + Firebase config
    try {
      final prefs2 = await SharedPreferences.getInstance();
      final mode = prefs2.getString("setupMode") ?? "NULL";
      final hasFbCfg = prefs2.getString("firebaseConfigJson") != null;
      debugPrint("=== RE-DECLARE SYNC TRACE ===");
      debugPrint("setupMode = $mode");
      debugPrint("hasFirebaseConfig = $hasFbCfg");
      debugPrint("sessionId = $sessionId");
      debugPrint("============================");
    } catch (e) {
      debugPrint("Debug trace error: $e");
    }
      final sessionRow = await DatabaseHelper().getSessionById(sessionId);
      if (sessionRow != null) {
        final updatedSession = CashierSession.fromMap(sessionRow);
        await SyncBridge.enqueueCashierSession(updatedSession, op: SyncOp.update);
        if (kDebugMode) debugPrint("Re-Declare synced session to Firebase: $sessionId");
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Re-Declare session sync failed: $e");
    }

    // Also update related IR if exists (variance changed)
    try {
      final irRow = await DatabaseHelper().getIncidentReportBySession(sessionId);
      if (irRow != null) {
        final updatedIRMap = Map<String, dynamic>.from(irRow);
        updatedIRMap['variance'] = newVariance;
        updatedIRMap['varianceType'] = newVarianceType;
        final existingRemarks = (updatedIRMap['remarks'] ?? '').toString();
        updatedIRMap['remarks'] = existingRemarks.isEmpty
            ? "Re-Declared by $adjustedBy: $reason"
            : "$existingRemarks\n[Re-Declared by $adjustedBy: $reason]";
        await DatabaseHelper().insertIncidentReport(updatedIRMap);
        final updatedIR = IncidentReport.fromMap(updatedIRMap);
        await SyncBridge.enqueueIncidentReport(updatedIR, op: SyncOp.update);
        if (kDebugMode) debugPrint("Re-Declare synced IR to Firebase: ${updatedIR.id}");
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Re-Declare IR sync failed: $e");
    }
  }

  /// Get ALL active (open) sessions across all cashiers
  static Future<List<CashierSession>> getAllActiveShifts() async {
    final rows = await DatabaseHelper().getAllSessions(status: 'open');
    return rows.map((r) => CashierSession.fromMap(r)).toList();
  }
}
