import 'package:flutter/material.dart';

class InboundHubScreen extends StatelessWidget {
  final String branch;
  final String userName;

  const InboundHubScreen({
    super.key,
    required this.branch,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF22C55E),
        foregroundColor: Colors.white,
        title: const Text(
          'Inbound Transfer',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction_rounded, size: 80, color: Color(0xFF22C55E)),
            SizedBox(height: 16),
            Text(
              'Inbound Transfer',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Inbound receive workflow coming in Phase 6.\nWill support full receipt, partial receipt, variance capture, and auto post-back.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
