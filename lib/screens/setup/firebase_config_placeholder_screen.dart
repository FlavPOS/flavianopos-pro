import 'package:flutter/material.dart';
import 'firebase_config_screen.dart';

/// Step 2 — The Step 1 placeholder is now a thin re-export wrapper that
/// forwards to the real FirebaseConfigScreen.
///
/// We keep this file so main.dart and any older imports continue to work
/// without breaking — Rule #1: do not delete existing code.
class FirebaseConfigPlaceholderScreen extends StatelessWidget {
  const FirebaseConfigPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) => const FirebaseConfigScreen();
}
