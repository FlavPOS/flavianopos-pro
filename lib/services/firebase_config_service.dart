import 'package:shared_preferences/shared_preferences.dart';
import '../models/firebase_config_model.dart';

/// Firebase Config Service
/// Persists FirebaseConfig in SharedPreferences as JSON.
///
/// ═══════════════════════════════════════════════════════════
/// 🚧 DEVELOPMENT MODE — HARDCODED CONFIG
///
/// ⚠️ REMOVE BEFORE PRODUCTION LAUNCH!
/// Toggle _useHardcodedConfig = false for production release.
/// ═══════════════════════════════════════════════════════════
class FirebaseConfigService {
  static const String _kKey = 'firebaseConfigJson';
  static const String _kLockedKey = 'firebaseConfigLocked';

  // ═══════════════════════════════════════════════════════════
  // 🚧 HARDCODED CONFIG TOGGLE
  // Set to false before production launch!
  // ═══════════════════════════════════════════════════════════
  static const bool _useHardcodedConfig = true;

  static const Map<String, String> _hardcodedConfig = {
    'apiKey': 'AIzaSyBPCm3dadnbDLhzp79U8bHxhEEtLUL2tG0',
    'authDomain': 'sample-be44f.firebaseapp.com',
    'projectId': 'sample-be44f',
    'storageBucket': 'sample-be44f.firebasestorage.app',
    'messagingSenderId': '864778424112',
    'appId': '1:864778424112:web:dacaef8618e33f91afc2f5',
    'measurementId': 'G-VM86H77FR8',
    'databaseUrl': 'https://sample-be44f-default-rtdb.asia-southeast1.firebasedatabase.app',
    'companyCode': '101',
    'companyName': 'FLAV Test Company',
  };

  Future<FirebaseConfig?> load() async {
    // ═══ HARDCODED MODE ═══
    // Always returns hardcoded config (dev testing)
    if (_useHardcodedConfig) {
      final config = FirebaseConfig.fromMap(_hardcodedConfig);
      // Save to SharedPreferences so other services find it
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kKey) == null) {
        await save(config);
      }
      return config;
    }

    // ═══ PRODUCTION MODE ═══
    // Load from SharedPreferences (user-configured)
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return FirebaseConfig.fromJsonString(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(FirebaseConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc().toIso8601String();
    final existingRaw = prefs.getString(_kKey);
    String? existingSavedAt;
    if (existingRaw != null && existingRaw.isNotEmpty) {
      try {
        final existing = FirebaseConfig.fromJsonString(existingRaw);
        existingSavedAt = existing.savedAt;
      } catch (_) {}
    }
    final merged = config.copyWith(
      savedAt: existingSavedAt ?? now,
      updatedAt: now,
    );
    await prefs.setString(_kKey, merged.toJsonString());
  }

  Future<bool> exists() async {
    // In hardcoded mode, always exists
    if (_useHardcodedConfig) return true;

    final c = await load();
    return c != null && c.hasRequiredFields;
  }

  Future<bool> isLocked() async {
    // In hardcoded mode, always locked (no user changes allowed)
    if (_useHardcodedConfig) return true;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kLockedKey) == true) return true;
    final c = await load();
    return c?.isLocked == true;
  }

  /// Call after main setup (company / main branch / first admin) completes.
  Future<void> lock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLockedKey, true);
    final c = await load();
    if (c != null) {
      await prefs.setString(
        _kKey,
        c
            .copyWith(
                isLocked: true,
                updatedAt: DateTime.now().toUtc().toIso8601String())
            .toJsonString(),
      );
    }
  }

  /// Debug / reset only.
  /// In hardcoded mode, only clears saved config (hardcoded still active).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
    await prefs.remove(_kLockedKey);
  }

  /// Check if running in hardcoded/dev mode
  static bool get isHardcodedMode => _useHardcodedConfig;
}
