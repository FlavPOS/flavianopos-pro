import 'firebase_realtime_service.dart';

class CompanyLookupService {
  Future<Map<String, dynamic>?> fetchCompanyProfile(String companyCode) async {
    final db = FirebaseRealtimeService.instance.db;
    if (db == null) throw Exception('Firebase not initialized.');
    final snap = await db.ref('companies/$companyCode/profile').get()
        .timeout(const Duration(seconds: 12));
    if (!snap.exists || snap.value == null) return null;
    return _asMap(snap.value);
  }

  Future<List<Map<String, dynamic>>> fetchBranches(String companyCode) async {
    final db = FirebaseRealtimeService.instance.db;
    if (db == null) throw Exception('Firebase not initialized.');
    final snap = await db.ref('companies/$companyCode/branches').get()
        .timeout(const Duration(seconds: 12));
    if (!snap.exists || snap.value == null) return [];
    final out = <Map<String, dynamic>>[];
    final raw = snap.value;
    if (raw is Map) {
      raw.forEach((k, v) {
        final m = _asMap(v);
        if (m != null) out.add(m);
      });
    }
    out.sort((a, b) => (a['branchName'] ?? '').toString()
        .compareTo((b['branchName'] ?? '').toString()));
    return out;
  }

  Future<List<Map<String, dynamic>>> fetchUsersInBranch(
      String companyCode, String branchId) async {
    final db = FirebaseRealtimeService.instance.db;
    if (db == null) throw Exception('Firebase not initialized.');
    final snap = await db
        .ref('companies/$companyCode/usersByBranch/$branchId').get()
        .timeout(const Duration(seconds: 12));
    if (!snap.exists || snap.value == null) return [];
    final out = <Map<String, dynamic>>[];
    final raw = snap.value;
    if (raw is Map) {
      raw.forEach((k, v) {
        final m = _asMap(v);
        if (m != null) out.add(m);
      });
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> fetchAllUsers(String companyCode) async {
    final db = FirebaseRealtimeService.instance.db;
    if (db == null) throw Exception('Firebase not initialized.');
    final snap = await db.ref('companies/$companyCode/users').get()
        .timeout(const Duration(seconds: 12));
    if (!snap.exists || snap.value == null) return [];
    final out = <Map<String, dynamic>>[];
    final raw = snap.value;
    if (raw is Map) {
      raw.forEach((k, v) {
        final m = _asMap(v);
        if (m != null) out.add(m);
      });
    }
    return out;
  }

  Future<void> registerDevice({
    required String companyCode,
    required String deviceId,
    required String branchId,
    required String branchName,
    required String role,
    String userId = '',
    String username = '',
  }) async {
    final db = FirebaseRealtimeService.instance.db;
    if (db == null) throw Exception('Firebase not initialized.');
    final now = DateTime.now().toUtc().toIso8601String();
    await db.ref('companies/$companyCode/devices/$deviceId').update({
      'deviceId': deviceId,
      'branchId': branchId,
      'branchName': branchName,
      'role': role,
      'registeredAt': now,
      'lastSeenAt': now,
      'registeredByUserId': userId,
      'registeredByUsername': username,
      'platform': 'flutter',
      'app': 'FlavianoPOS-Pro',
    });
  }

  Future<void> writeBranch({
    required String companyCode,
    required String branchId,
    required Map<String, dynamic> payload,
  }) async {
    final db = FirebaseRealtimeService.instance.db;
    if (db == null) throw Exception('Firebase not initialized.');
    await db.ref('companies/$companyCode/branches/$branchId').set(payload);
  }

  Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map) {
      return v.map((k, vv) => MapEntry(k.toString(), vv));
    }
    return null;
  }
}
