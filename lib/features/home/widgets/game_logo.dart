import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';

/// Storybook wordmark: bubbly "Fluffy" in white and "Merge" in gold, both
/// with a thick purple outline and a soft drop, plus a little gold crown
/// perched on the "F".
class GameLogo extends StatelessWidget {
  const GameLogo({super.key, required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Fluffy Merge',
      excludeSemantics: true,
      child: Transform.rotate(
        angle: -0.04,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LogoWord(
                  'Fluffy',
                  size: fontSize,
                  colors: const [Color(0xFFFFFFFF), Color(0xFFF1E6FF)],
                ),
                Transform.translate(
                  offset: Offset(fontSize * 0.25, -fontSize * 0.2),
                  child: _LogoWord(
                    'Merge',
                    size: fontSize * 1.05,
                    colors: const [AppColors.logoGoldTop, AppColors.logoGold],
                  ),
                ),
              ],
            ),
            Positioned(
              left: -fontSize * 0.12,
              top: -fontSize * 0.5,
              child: Transform.rotate(
                angle: -0.35,
                child: CustomPaint(
                  size: Size(fontSize * 0.75, fontSize * 0.55),
                  painter: CrownPainter(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoWord extends StatelessWidget {
  const _LogoWord(this.text, {required this.size, required this.colors});

  final String text;
  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final base = AppText.display(size).copyWith(
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: size * 0.01,
    );
    return Stack(
      children: [
        // White halo + soft shadow behind the purple outline.
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.34
              ..strokeJoin = StrokeJoin.round
              ..color = AppColors.white,
            shadows: const [
              Shadow(
                color: Color(0x556E3AA7),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
        ),
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.2
              ..strokeJoin = StrokeJoin.round
              ..color = AppColors.logoPurple,
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(r),
          child: Text(text, style: base.copyWith(color: AppColors.white)),
        ),
      ],
    );
  }
}

/// Small rounded gold crown with three gems.
class CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final crown = Path()
      ..moveTo(w * 0.08, h * 0.9)
      ..lineTo(w * 0.02, h * 0.3)
      ..lineTo(w * 0.3, h * 0.55)
      ..lineTo(w * 0.5, h * 0.12)
      ..lineTo(w * 0.7, h * 0.55)
      ..lineTo(w * 0.98, h * 0.3)
      ..lineTo(w * 0.92, h * 0.9)
      ..close();
    canvas.drawPath(
      crown,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.logoGoldTop, AppColors.logoGold],
        ).createShader(Offset.zero & s),
    );
    canvas.drawPath(
      crown,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, w * 0.06)
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFD48A12),
    );
    final gem = Paint();
    for (final (x, y, c) in const [
      (0.02, 0.3, Color(0xFFFF6FA8)),
      (0.5, 0.12, Color(0xFF7FC8FF)),
      (0.98, 0.3, Color(0xFFFF6FA8)),
    ]) {
      gem.color = c;
      canvas.drawCircle(Offset(w * x, h * y), w * 0.08, gem);
    }
    gem.color = const Color(0xFFFF6FA8);
    canvas.drawCircle(Offset(w * 0.5, h * 0.7), w * 0.07, gem);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
