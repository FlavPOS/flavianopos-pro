import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Step 3 — Device ID Service
/// Generates and persists a stable device ID used for sync identification.
/// One device = one ID, kept across app restarts.
class DeviceIdService {
  static const String _kKey = 'deviceId';

  Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final fresh = const Uuid().v4();
    await prefs.setString(_kKey, fresh);
    return fresh;
  }

  Future<String?> get() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
