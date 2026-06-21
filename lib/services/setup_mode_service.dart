import 'package:shared_preferences/shared_preferences.dart';

/// Step 1 — Setup Mode Service
/// Stores and reads the user's chosen setup mode ("solo" | "multiple").
/// This does NOT touch SQLite. It only uses SharedPreferences.
class SetupModeService {
  static const String _kSetupMode = 'setupMode';
  static const String _kSetupModeSelectedAt = 'setupModeSelectedAt';

  static const String modeSolo = 'solo';
  static const String modeMultiple = 'multiple';

  /// Returns "solo", "multiple", or null if not yet selected.
  Future<String?> getSetupMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSetupMode);
  }

  /// Saves the chosen setup mode and the selection timestamp.
  Future<void> setSetupMode(String mode) async {
    if (mode != modeSolo && mode != modeMultiple) {
      throw ArgumentError('Invalid setup mode: $mode');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSetupMode, mode);
    await prefs.setString(
      _kSetupModeSelectedAt,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// True if user has already chosen Solo or Multiple.
  Future<bool> isSetupModeSelected() async {
    final mode = await getSetupMode();
    return mode == modeSolo || mode == modeMultiple;
  }

  /// Debug / reset use only. NOT exposed in UI.
  Future<void> clearSetupMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSetupMode);
    await prefs.remove(_kSetupModeSelectedAt);
  }

  /// Optional: read when the mode was selected.
  Future<DateTime?> getSetupModeSelectedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSetupModeSelectedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
