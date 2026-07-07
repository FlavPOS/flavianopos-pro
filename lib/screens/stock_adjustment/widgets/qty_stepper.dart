import 'package:flutter/material.dart';
import 'adjustment_theme.dart';

/// Large touch-friendly quantity stepper.
/// [-] N [+] with buttons sized for warehouse gloves.
class QtyStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final Color? accentColor;

  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99999,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AdjTheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: AdjTheme.card,
        borderRadius: BorderRadius.circular(AdjTheme.radiusCard),
        border: Border.all(color: AdjTheme.divider, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            color: accent,
            enabled: value > min,
            onTap: () => onChanged((value - 1).clamp(min, max)),
          ),
          // Value display
          SizedBox(
            width: 72,
            child: Center(
              child: Text(
                '$value',
                style: TextStyle(
                  fontFamily: AdjTheme.fontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AdjTheme.textPrimary,
                ),
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            color: accent,
            enabled: value < max,
            onTap: () => onChanged((value + 1).clamp(min, max)),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AdjTheme.radiusCard),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 24,
            color: enabled ? color : AdjTheme.textDisabled,
          ),
        ),
      ),
    );
  }
}
