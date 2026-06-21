import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/firebase_config_model.dart';

/// Step 3 — Firebase Realtime Service
/// Initializes Firebase dynamically from a manually-encoded FirebaseConfig.
/// Provides a safe wrapper around FirebaseDatabase calls.
///
/// IMPORTANT:
/// - No hardcoded config.
/// - Uses a NAMED Firebase app ("flavianopos") so we don't collide with any
///   default app the host platform may register.
/// - Solo Store mode never calls this service.
class FirebaseRealtimeService {
  FirebaseRealtimeService._();
  static final FirebaseRealtimeService instance = FirebaseRealtimeService._();

  static const String _appName = 'flavianopos';

  FirebaseApp? _app;
  FirebaseDatabase? _db;
  FirebaseConfig? _activeConfig;

  bool get isInitialized => _app != null && _db != null;
  FirebaseConfig? get activeConfig => _activeConfig;
  FirebaseDatabase? get db => _db;

  /// Initialize Firebase dynamically using the manual config.
  /// Safe to call multiple times — will reuse the named app if already up.
  Future<void> initializeFromManualConfig(FirebaseConfig cfg) async {
    if (!cfg.hasRequiredFields) {
      throw FirebaseInitException(
        'Firebase config is incomplete. Please fill the required fields.',
      );
    }

    final options = FirebaseOptions(
      apiKey: cfg.apiKey.trim(),
      appId: cfg.appId.trim(),
      messagingSenderId: cfg.messagingSenderId.trim(),
      projectId: cfg.projectId.trim(),
      databaseURL: cfg.databaseUrl.trim(),
      authDomain:
          cfg.authDomain.trim().isEmpty ? null : cfg.authDomain.trim(),
      storageBucket:
          cfg.storageBucket.trim().isEmpty ? null : cfg.storageBucket.trim(),
      measurementId: cfg.measurementId.trim().isEmpty
          ? null
          : cfg.measurementId.trim(),
    );

    try {
      // Reuse the named app if it already exists (avoids duplicate app errors).
      try {
        _app = Firebase.app(_appName);
      } catch (_) {
        _app = await Firebase.initializeApp(name: _appName, options: options);
      }

      _db = FirebaseDatabase.instanceFor(
        app: _app!,
        databaseURL: cfg.databaseUrl.trim(),
      );

      _activeConfig = cfg;
    } on FirebaseException catch (e) {
      throw FirebaseInitException(_humanizeFirebaseError(e));
    } catch (e) {
      throw FirebaseInitException('Firebase initialization failed: $e');
    }
  }

  /// Round-trip connection test.
  /// Writes to companies/{companyCode}/connectionTests/{deviceId} then reads it back.
  Future<ConnectionTestResult> testConnection({
    required String deviceId,
  }) async {
    if (!isInitialized || _activeConfig == null) {
      return ConnectionTestResult.failure(
        'Firebase is not initialized. Save and apply config first.',
      );
    }

    final cfg = _activeConfig!;
    final path =
        'companies/${cfg.companyCode.trim()}/connectionTests/$deviceId';
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'deviceId': deviceId,
      'companyCode': cfg.companyCode.trim(),
      'projectId': cfg.projectId.trim(),
      'testedAt': now,
      'app': 'FlavianoPOS-Pro',
      'platform': 'flutter',
      'note': 'Step 3 connection test',
    };

    try {
      final ref = _db!.ref(path);
      await ref.set(payload).timeout(const Duration(seconds: 12));
      final snap = await ref.get().timeout(const Duration(seconds: 12));
      if (!snap.exists) {
        return ConnectionTestResult.failure(
          'Write succeeded but read returned empty. Check database rules.',
        );
      }
      return ConnectionTestResult.success(path: path, testedAt: now);
    } on FirebaseException catch (e) {
      return ConnectionTestResult.failure(_humanizeFirebaseError(e));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('TimeoutException')) {
        return ConnectionTestResult.failure(
          'Connection timed out. Check internet or databaseURL.',
        );
      }
      return ConnectionTestResult.failure('Test failed: $msg');
    }
  }

  String _humanizeFirebaseError(FirebaseException e) {
    final code = (e.code).toLowerCase();
    if (code.contains('permission')) {
      return 'Permission denied. Update Realtime Database rules to allow this path.';
    }
    if (code.contains('network') || code.contains('unavailable')) {
      return 'Network error. Check your internet connection.';
    }
    if (code.contains('invalid') || code.contains('argument')) {
      return 'Invalid Firebase config. Double-check API Key, App ID, or databaseURL.';
    }
    if (code.contains('not-found') || code.contains('not_found')) {
      return 'Project or database not found. Check projectId and databaseURL.';
    }
    return 'Firebase error (${e.code}): ${e.message ?? "unknown"}';
  }

  /// Tear down (debug / reset only).
  Future<void> dispose() async {
    try {
      await _app?.delete();
    } catch (_) {}
    _app = null;
    _db = null;
    _activeConfig = null;
  }
}

class FirebaseInitException implements Exception {
  final String message;
  FirebaseInitException(this.message);
  @override
  String toString() => message;
}

class ConnectionTestResult {
  final bool success;
  final String? error;
  final String? path;
  final String? testedAt;

  const ConnectionTestResult._(
      {required this.success, this.error, this.path, this.testedAt});

  factory ConnectionTestResult.success(
          {required String path, required String testedAt}) =>
      ConnectionTestResult._(success: true, path: path, testedAt: testedAt);

  factory ConnectionTestResult.failure(String error) =>
      ConnectionTestResult._(success: false, error: error);
}
