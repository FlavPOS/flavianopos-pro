import 'package:flutter/material.dart';

/// Submitted screen — placeholder.
/// TODO: Design this module inside.
class AdjustmentSubmittedScreen extends StatelessWidget {
  const AdjustmentSubmittedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xff3b82f6),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Submitted',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xff3b82f6).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                size: 64,
                color: const Color(0xff3b82f6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Submitted',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coming soon — this module is under construction.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xff3b82f6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '🚧 TODO: Design this module',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xff3b82f6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
