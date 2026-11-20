import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import 'pressable_scale.dart';

/// Cream "toy box" tile: soft beige card with a tan lip, a colourful icon
/// and a brown label (Collection / Shop / Settings / Daily).
class TileButton extends StatelessWidget {
  const TileButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.height = 96,
    this.badge = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final double height;

  /// Shows a red "!" bubble (e.g. a reward is waiting).
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height * 0.24);
    return PressableScale(
      onTap: onTap,
      semanticLabel: badge ? '$label, reward waiting' : label,
      child: Stack(
        // Pass the row's tight width straight to the tile; a loose Stack
        // would let each tile shrink to its label.
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          _tile(radius),
          if (badge)
            Positioned(
              right: -height * 0.06,
              top: -height * 0.06,
              child: Container(
                width: height * 0.28,
                height: height * 0.28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
                child: Text(
                  '!',
                  style: AppText.display(height * 0.17, color: AppColors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(BorderRadius radius) {
    return Container(
      height: height,
      padding: EdgeInsets.only(bottom: height * 0.06),
      decoration: BoxDecoration(
        color: AppColors.panelBorder,
        borderRadius: radius,
        border: Border.all(color: AppColors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33975A2A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF2), AppColors.panel],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: height * 0.42,
              shadows: [
                Shadow(
                  color: Color.lerp(
                    color,
                    AppColors.textDark,
                    0.5,
                  )!.withValues(alpha: 0.35),
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            SizedBox(height: height * 0.04),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppText.display(
                    height * 0.15,
                    color: AppColors.woodDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
