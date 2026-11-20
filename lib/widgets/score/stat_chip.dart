import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// White pill with an icon and a number that counts up when it changes.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.semanticLabel,
    this.height = 40,
  });

  final IconData icon;
  final Color iconColor;
  final int value;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semanticLabel: $value',
      excludeSemantics: true,
      child: Container(
        height: height,
        padding: EdgeInsets.only(left: height * 0.14, right: height * 0.4),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: height * 0.72,
              height: height * 0.72,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: height * 0.48),
            ),
            SizedBox(width: height * 0.18),
            AnimatedCounter(value: value, style: AppText.display(height * 0.5)),
          ],
        ),
      ),
    );
  }
}

/// Number that tweens from its previous value to the new one.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    required this.style,
    this.duration = AppDurations.slow,
  });

  final int value;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      curve: AppCurves.soft,
      builder: (_, v, _) => Text(formatNumber(v.round()), style: style),
    );
  }
}

/// 12345 → "12,345".
String formatNumber(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
