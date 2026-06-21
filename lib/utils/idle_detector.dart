import 'dart:async';
import 'package:flutter/material.dart';
import '../models/settings_model.dart';

class IdleDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onIdle;
  const IdleDetector({super.key, required this.child, required this.onIdle});

  @override
  State<IdleDetector> createState() => _IdleDetectorState();
}

class _IdleDetectorState extends State<IdleDetector> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    if (!AppSettings.autoLogout) return;
    final minutes = AppSettings.autoLogoutMinutes;
    _timer = Timer(Duration(minutes: minutes), () {
      widget.onIdle();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerUp: (_) => _resetTimer(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _resetTimer,
        child: widget.child,
      ),
    );
  }
}
