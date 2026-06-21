import 'package:flutter/material.dart';

class AppLogo extends StatefulWidget {
  final double size;
  final bool showText;
  final bool compact;

  const AppLogo({
    super.key,
    this.size = 1.0,
    this.showText = true,
    this.compact = false,
  });

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 16 * s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28 * s),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Color(0xFFFAF5FF),
              Color(0xFFF3E5F5),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A1B9A).withValues(alpha: 0.4),
              blurRadius: 32 * s,
              offset: Offset(0, 12 * s),
            ),
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.2),
              blurRadius: 24 * s,
              offset: Offset(0, -4 * s),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFE1BEE7),
            width: 2 * s,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 💎 PREMIUM CIRCULAR BADGE
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                Container(
                  width: 76 * s,
                  height: 76 * s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      colors: [
                        Color(0xFF7B1FA2),
                        Color(0xFFAB47BC),
                        Color(0xFFFFD700),
                        Color(0xFFAB47BC),
                        Color(0xFF7B1FA2),
                      ],
                    ),
                  ),
                ),
                // Main badge
                Container(
                  width: 70 * s,
                  height: 70 * s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.3),
                      radius: 1.3,
                      colors: [
                        Color(0xFFAB47BC),
                        Color(0xFF7B1FA2),
                        Color(0xFF4A148C),
                        Color(0xFF311B92),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7B1FA2).withValues(alpha: 0.8),
                        blurRadius: 24 * s,
                        offset: Offset(0, 6 * s),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white,
                      width: 3 * s,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Sparkles
                      Positioned(
                        top: 10 * s,
                        right: 12 * s,
                        child: Icon(Icons.auto_awesome,
                          color: Colors.amber.shade300,
                          size: 10 * s,
                        ),
                      ),
                      Positioned(
                        bottom: 14 * s,
                        left: 10 * s,
                        child: Icon(Icons.star,
                          color: Colors.amber.shade200,
                          size: 8 * s,
                        ),
                      ),
                      Positioned(
                        top: 20 * s,
                        left: 14 * s,
                        child: Icon(Icons.circle,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 4 * s,
                        ),
                      ),
                      // Main icon
                      Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 36 * s,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 8 * s,
                            offset: Offset(0, 3 * s),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Shine sweep
                ClipOval(
                  child: SizedBox(
                    width: 70 * s,
                    height: 70 * s,
                    child: Transform.translate(
                      offset: Offset(_shimmer.value * 70 * s, 0),
                      child: Container(
                        width: 30 * s,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.3),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.showText) ...[
              SizedBox(width: 16 * s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand name with premium gradient
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF311B92),
                        Color(0xFF7B1FA2),
                        Color(0xFFAB47BC),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      'FlavianoPOS',
                      style: TextStyle(
                        fontSize: 26 * s,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                  SizedBox(height: 6 * s),
                  // GOLD PRO Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14 * s,
                      vertical: 5 * s,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20 * s),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFE082),
                          Color(0xFFFFD700),
                          Color(0xFFFFA000),
                          Color(0xFFFF6F00),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF8F00).withValues(alpha: 0.6),
                          blurRadius: 12 * s,
                          offset: Offset(0, 4 * s),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white,
                        width: 2 * s,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                          color: Colors.white,
                          size: 12 * s,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        SizedBox(width: 4 * s),
                        Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 12 * s,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 4 * s),
                        Icon(Icons.star_rounded,
                          color: Colors.white,
                          size: 12 * s,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!widget.compact) ...[
                    SizedBox(height: 5 * s),
                    Text(
                      'Retail Management System',
                      style: TextStyle(
                        fontSize: 9 * s,
                        color: const Color(0xFF6A1B9A),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
