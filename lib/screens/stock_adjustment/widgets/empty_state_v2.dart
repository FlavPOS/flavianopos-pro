import 'package:flutter/material.dart';
import 'adjustment_theme.dart';

/// Premium empty state with illustrated icon and arrow to FAB.
class EmptyStateV2 extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onAddPressed;

  const EmptyStateV2({
    super.key,
    this.title = 'No items to adjust yet',
    this.subtitle = 'Add products to adjust your inventory.\nTap the + button to get started.',
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdjTheme.s6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustrated icon container
            _buildIllustration(),
            const SizedBox(height: AdjTheme.s6),

            // Title
            Text(
              title,
              style: AdjTheme.titleCard,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AdjTheme.s2),

            // Subtitle
            Text(
              subtitle,
              style: AdjTheme.caption.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AdjTheme.s5),

            // Dashed arrow pointing down to FAB
            _buildDashedArrow(),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer circle background
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AdjTheme.primaryLight.withValues(alpha: 0.5),
            ),
          ),
          // Middle circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AdjTheme.primaryLight,
            ),
          ),
          // Icon
          Icon(
            Icons.inventory_2_rounded,
            size: 64,
            color: AdjTheme.primary.withValues(alpha: 0.7),
          ),
          // Sparkle top-right
          Positioned(
            top: 20,
            right: 30,
            child: Icon(
              Icons.auto_awesome,
              size: 20,
              color: AdjTheme.primary.withValues(alpha: 0.6),
            ),
          ),
          // Sparkle bottom-left
          Positioned(
            bottom: 30,
            left: 25,
            child: Icon(
              Icons.auto_awesome,
              size: 14,
              color: AdjTheme.primary.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedArrow() {
    return SizedBox(
      width: 80,
      height: 60,
      child: CustomPaint(
        painter: _DashedArrowPainter(),
      ),
    );
  }
}

/// Painter for the dashed curved arrow pointing to FAB.
class _DashedArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AdjTheme.primary.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw dashed curve
    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.2,
      size.width,
      size.height,
    );

    // Convert to dashed
    final metrics = path.computeMetrics().toList();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final extractPath = metric.extractPath(distance, distance + 5);
        canvas.drawPath(extractPath, paint);
        distance += 10;
      }
    }

    // Arrow head at the end
    final arrowPaint = Paint()
      ..color = AdjTheme.primary.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final arrowPath = Path();
    arrowPath.moveTo(size.width, size.height);
    arrowPath.lineTo(size.width - 8, size.height - 4);
    arrowPath.lineTo(size.width - 4, size.height - 8);
    arrowPath.close();
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
