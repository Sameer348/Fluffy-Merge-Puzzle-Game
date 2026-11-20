import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';

/// Wooden plank sign used for screen titles ("Collection", "So Fluffy!").
/// Warm wood gradient, darker border, plank grain lines, and cream text
/// with a brown outline.
class WoodSign extends StatelessWidget {
  const WoodSign({
    super.key,
    required this.text,
    this.fontSize = 26,
    this.icon,
  });

  final String text;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = AppText.display(fontSize).copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: fontSize * 0.02,
      height: 1.05,
    );
    return Semantics(
      header: true,
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: fontSize * 0.9,
          vertical: fontSize * 0.32,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(fontSize * 0.5),
          border: Border.all(color: AppColors.woodDark, width: 2.5),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.woodTop, AppColors.wood],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40975A2A),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _GrainPainter(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.panel, size: fontSize * 1.1),
                SizedBox(width: fontSize * 0.3),
              ],
              // Long titles / large text shrink rather than overflow.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Stack(
                    children: [
                      Text(
                        text,
                        maxLines: 1,
                        style: style.copyWith(
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = fontSize * 0.16
                            ..strokeJoin = StrokeJoin.round
                            ..color = AppColors.woodDark,
                        ),
                      ),
                      Text(
                        text,
                        maxLines: 1,
                        style: style.copyWith(color: AppColors.panel),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.woodDark.withValues(alpha: 0.18)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final f in const [0.18, 0.82]) {
      final y = size.height * f;
      canvas.drawLine(Offset(-6, y), Offset(size.width * 0.3, y), p);
      canvas.drawLine(
        Offset(size.width * 0.7, y),
        Offset(size.width + 6, y),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
