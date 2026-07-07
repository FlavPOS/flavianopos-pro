import 'package:flutter/material.dart';
import 'adjustment_theme.dart';

/// Premium Floating Action Button for adding products.
class AddProductFab extends StatefulWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;

  const AddProductFab({
    super.key,
    this.onPressed,
    this.icon = Icons.add_rounded,
    this.tooltip,
  });

  @override
  State<AddProductFab> createState() => _AddProductFabState();
}

class _AddProductFabState extends State<AddProductFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AdjTheme.animFast,
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fab = ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AdjTheme.shadowFab,
        ),
        child: Material(
          color: AdjTheme.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTapDown: (_) => _controller.reverse(),
            onTapUp: (_) => _controller.forward(),
            onTapCancel: () => _controller.forward(),
            onTap: widget.onPressed,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: fab,
      );
    }
    return fab;
  }
}
