import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double? size;
  const AppLogo({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final s = size ?? (isTablet ? 1.3 : 1.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 16 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(10 * s),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0), Color(0xFFAB47BC)],
              ),
              borderRadius: BorderRadius.circular(14 * s),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(Icons.storefront, color: Colors.white, size: 30 * s),
          ),
          SizedBox(width: 12 * s),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: 'Flaviano', style: TextStyle(fontSize: 22 * s, fontWeight: FontWeight.bold, color: const Color(0xFF4A148C), letterSpacing: 0.5)),
                    TextSpan(text: 'POS', style: TextStyle(fontSize: 22 * s, fontWeight: FontWeight.w900, color: const Color(0xFF9C27B0), letterSpacing: 1)),
                  ],
                ),
              ),
              SizedBox(height: 2 * s),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 3 * s),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFCE93D8)]),
                  borderRadius: BorderRadius.circular(6 * s),
                ),
                child: Text('PRO', style: TextStyle(color: Colors.white, fontSize: 11 * s, fontWeight: FontWeight.bold, letterSpacing: 3)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
