import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import 'pressable_scale.dart';

/// Colour sets for glossy candy buttons.
enum CandyColor {
  pink(AppColors.candyPinkTop, AppColors.candyPink, AppColors.candyPinkLip),
  green(AppColors.candyGreenTop, AppColors.candyGreen, AppColors.candyGreenLip),
  blue(AppColors.candyBlueTop, AppColors.candyBlue, AppColors.candyBlueLip),
  yellow(
    AppColors.candyYellowTop,
    AppColors.candyYellow,
    AppColors.candyYellowLip,
  ),
  purple(
    AppColors.candyPurpleTop,
    AppColors.candyPurple,
    AppColors.candyPurpleLip,
  );

  const CandyColor(this.top, this.base, this.lip);
  final Color top;
  final Color base;
  final Color lip;
}

/// Glossy "candy" pill button: vertical gradient, a darker bottom lip,
/// a white gloss highlight across the top, and bold outlined text.
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.onTap,
    this.candy = CandyColor.pink,
    this.icon,
    this.height = 56,
    this.fontSize = 20,
    this.darkText = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final CandyColor candy;
  final IconData? icon;
  final double height;
  final double fontSize;

  /// Dark brown text (for light candies like yellow).
  final bool darkText;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final lipH = height * 0.09;
    final radius = BorderRadius.circular(height / 2);
    final textColor = darkText ? AppColors.textDark : AppColors.white;
    final outline = darkText
        ? null
        : (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fontSize * 0.14
            ..strokeJoin = StrokeJoin.round
            ..color = candy.lip);

    Widget text(String t) {
      final style = AppText.display(
        fontSize,
        color: textColor,
      ).copyWith(fontWeight: FontWeight.w700, letterSpacing: fontSize * 0.02);
      return Stack(
        children: [
          if (outline != null)
            Text(
              t,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(foreground: outline),
            ),
          Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ],
      );
    }

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            color: textColor,
            size: fontSize * 1.25,
            shadows: [
              if (!darkText)
                Shadow(
                  color: candy.lip,
                  blurRadius: 0,
                  offset: const Offset(0, 1.5),
                ),
            ],
          ),
          SizedBox(width: fontSize * 0.35),
        ],
        // Long labels / large text shrink rather than truncate.
        Flexible(
          child: FittedBox(fit: BoxFit.scaleDown, child: text(label)),
        ),
      ],
    );

    return PressableScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: height,
        padding: EdgeInsets.only(bottom: lipH),
        decoration: BoxDecoration(
          color: candy.lip,
          borderRadius: radius,
          border: Border.all(color: AppColors.white, width: height * 0.045),
          boxShadow: [
            BoxShadow(
              color: candy.lip.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [candy.top, candy.base],
              ),
            ),
            child: Stack(
              children: [
                // Gloss highlight across the upper half.
                Positioned(
                  left: height * 0.3,
                  right: height * 0.3,
                  top: height * 0.06,
                  height: height * 0.32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.white.withValues(alpha: 0.55),
                          AppColors.white.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: height * 0.35),
                  child: Center(child: content),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
