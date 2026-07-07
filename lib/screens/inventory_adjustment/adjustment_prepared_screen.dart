import 'package:flutter/material.dart';

/// Prepared Adjustment screen — placeholder.
/// TODO: Design this module inside.
class AdjustmentPreparedScreen extends StatelessWidget {
  const AdjustmentPreparedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xfff59e0b),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Prepared Adjustment',
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
                color: const Color(0xfff59e0b).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_rounded,
                size: 64,
                color: const Color(0xfff59e0b),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Prepared Adjustment',
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
                color: const Color(0xfff59e0b).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '🚧 TODO: Design this module',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xfff59e0b),
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
