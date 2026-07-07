import 'package:flutter/material.dart';

/// Rejected screen — placeholder.
/// TODO: Design this module inside.
class AdjustmentRejectedScreen extends StatelessWidget {
  const AdjustmentRejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xffef4444),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Rejected',
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
                color: const Color(0xffef4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cancel_rounded,
                size: 64,
                color: const Color(0xffef4444),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Rejected',
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
                color: const Color(0xffef4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '🚧 TODO: Design this module',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xffef4444),
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
