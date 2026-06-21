import 'package:flutter/services.dart';
import '../models/settings_model.dart';

class SoundHelper {
  static Future<void> click() async {
    if (AppSettings.soundEffects) {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();
    }
  }

  static Future<void> success() async {
    if (AppSettings.soundEffects) {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.mediumImpact();
    }
  }

  static Future<void> error() async {
    if (AppSettings.soundEffects) {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    }
  }
}
