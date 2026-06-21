import 'package:shared_preferences/shared_preferences.dart';
import '../models/firebase_config_model.dart';

/// Step 2 — Firebase Config Service
/// Persists FirebaseConfig in SharedPreferences as JSON.
/// No Firebase SDK calls here. Step 3 will read this and initialize Firebase.
class FirebaseConfigService {
  static const String _kKey = 'firebaseConfigJson';
  static const String _kLockedKey = 'firebaseConfigLocked';

  Future<FirebaseConfig?> load() async {
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
    final existing = await load();
    final merged = config.copyWith(
      savedAt: existing?.savedAt ?? now,
      updatedAt: now,
    );
    await prefs.setString(_kKey, merged.toJsonString());
  }

  Future<bool> exists() async {
    final c = await load();
    return c != null && c.hasRequiredFields;
  }

  Future<bool> isLocked() async {
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
        c.copyWith(isLocked: true, updatedAt: DateTime.now().toUtc().toIso8601String()).toJsonString(),
      );
    }
  }

  /// Debug / reset only.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
    await prefs.remove(_kLockedKey);
  }
}
