// lib/widgets/pos_background.dart
// 3D ANIMATED DOT MATRIX - Vercel/Linear/Apple Style

import 'package:flutter/material.dart';
import 'dart:math' as math;

class POSBackground extends StatefulWidget {
  final Widget child;
  const POSBackground({super.key, required this.child});

  @override
  State<POSBackground> createState() => _POSBackgroundState();
}

class _POSBackgroundState extends State<POSBackground>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _colorController;
  late AnimationController _parallaxController;

  @override
  void initState() {
    super.initState();

    // 3D wave motion (15s slow natural)
    _waveController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    // Color cycle (25s)
    _colorController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat();

    // Parallax (20s)
    _parallaxController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _colorController.dispose();
    _parallaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ═══ LAYER 1: DARK BASE GRADIENT ═══
        AnimatedBuilder(
          animation: _colorController,
          builder: (context, child) {
            final t = _colorController.value;
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    math.sin(t * 2 * math.pi) * 0.3,
                    math.cos(t * 2 * math.pi) * 0.3,
                  ),
                  radius: 1.8,
                  colors: [
                    Color.lerp(
                      const Color(0xFF1E1B4B),
                      const Color(0xFF312E81),
                      math.sin(t * math.pi),
                    )!,
                    const Color(0xFF0F172A),
                    const Color(0xFF030712),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            );
          },
        ),

        // ═══ LAYER 2: COLORFUL AMBIENT BLOBS (animated) ═══
        AnimatedBuilder(
          animation: _colorController,
          builder: (context, child) {
            final t = _colorController.value * 2 * math.pi;
            return Stack(
              children: [
                _buildColorBlob(
                  alignment: Alignment(math.sin(t) * 0.6, math.cos(t) * 0.6),
                  size: 500,
                  color: const Color(0xFF6366F1),
                  opacity: 0.4,
                ),
                _buildColorBlob(
                  alignment: Alignment(math.cos(t * 1.3) * 0.7, math.sin(t * 1.3) * 0.7),
                  size: 450,
                  color: const Color(0xFFEC4899),
                  opacity: 0.3,
                ),
                _buildColorBlob(
                  alignment: Alignment(math.sin(t * 0.8) * 0.8, math.cos(t * 0.8) * 0.5),
                  size: 400,
                  color: const Color(0xFF10B981),
                  opacity: 0.25,
                ),
                _buildColorBlob(
                  alignment: Alignment(math.cos(t * 1.7) * 0.5, math.sin(t * 1.7) * 0.7),
                  size: 380,
                  color: const Color(0xFFF59E0B),
                  opacity: 0.2,
                ),
              ],
            );
          },
        ),

        // ═══ LAYER 3: 3D ANIMATED DOT MATRIX ═══
        AnimatedBuilder(
          animation: Listenable.merge([_waveController, _parallaxController]),
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: _DotMatrixPainter(
                waveProgress: _waveController.value,
                parallaxProgress: _parallaxController.value,
                colorProgress: _colorController.value,
              ),
            );
          },
        ),

        // ═══ LAYER 4: SUBTLE OVERLAY ═══
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0),
                radius: 0.8,
                colors: [
                  const Color(0xFF0F172A).withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ═══ LAYER 5: YOUR CONTENT ═══
        widget.child,
      ],
    );
  }

  Widget _buildColorBlob({
    required Alignment alignment,
    required double size,
    required Color color,
    required double opacity,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: opacity * 0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

class _DotMatrixPainter extends CustomPainter {
  final double waveProgress;
  final double parallaxProgress;
  final double colorProgress;

  _DotMatrixPainter({
    required this.waveProgress,
    required this.parallaxProgress,
    required this.colorProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 32.0;
    const double baseRadius = 1.4;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final waveTime = waveProgress * 2 * math.pi;
    final parallaxX = math.sin(parallaxProgress * 2 * math.pi) * 5;
    final parallaxY = math.cos(parallaxProgress * 2 * math.pi) * 5;

    // Color palette for dots (cycles based on position + time)
    final colorPalette = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF10B981), // Emerald
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
      const Color(0xFFFFFFFF), // White
    ];

    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        // Distance from center for 3D wave effect
        final dx = (x - centerX) / size.width;
        final dy = (y - centerY) / size.height;
        final distance = math.sqrt(dx * dx + dy * dy);

        // 3D wave effect (dots appear to ripple)
        final wave = math.sin(distance * 8 - waveTime) * 0.5 + 0.5;

        // Z-depth simulation (closer = brighter + bigger)
        final depth = 0.4 + wave * 0.6;

        // Pick color based on position + time
        final colorIndex = ((x + y) * 0.02 + colorProgress * 5).toInt() % colorPalette.length;
        final color = colorPalette[colorIndex];

        // Vary opacity by wave + distance from center
        final centerFade = (1.0 - distance * 0.5).clamp(0.3, 1.0);
        final opacity = (0.15 + wave * 0.5) * centerFade;

        // Vary size by wave (3D illusion!)
        final radius = baseRadius * depth;

        // Draw the dot
        final paint = Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          Offset(x + parallaxX, y + parallaxY),
          radius,
          paint,
        );

        // Glow for bigger dots (3D depth feel)
        if (wave > 0.7) {
          final glowPaint = Paint()
            ..color = color.withValues(alpha: opacity * 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.drawCircle(
            Offset(x + parallaxX, y + parallaxY),
            radius * 2.5,
            glowPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotMatrixPainter oldDelegate) => true;
}
