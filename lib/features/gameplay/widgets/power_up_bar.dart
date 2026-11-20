import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../game/models/power_up.dart';
import '../../../widgets/buttons/pressable_scale.dart';

/// Row of glossy round power-up buttons with purple count badges and
/// outlined labels (Sweep · Pop · Grow · Shake).
///
/// Empty power-ups are dimmed but stay tappable (the screen explains how to
/// earn more). The one currently being aimed ([active]) glows.
class PowerUpBar extends StatelessWidget {
  const PowerUpBar({
    super.key,
    required this.r,
    required this.counts,
    required this.onUse,
    this.active,
  });

  final Responsive r;
  final Map<PowerUp, int> counts;
  final void Function(PowerUp) onUse;
  final PowerUp? active;

  @override
  Widget build(BuildContext context) {
    final d = r.s(r.isCompact ? 54 : 62);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final p in PowerUp.values)
          _PowerUpButton(
            kind: p,
            size: d,
            count: counts[p] ?? 0,
            active: active == p,
            onTap: () => onUse(p),
          ),
      ],
    );
  }
}

class _PowerUpButton extends StatelessWidget {
  const _PowerUpButton({
    required this.kind,
    required this.size,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final PowerUp kind;
  final double size;
  final int count;
  final bool active;
  final VoidCallback? onTap;

  /// Glossy disc colours (top, bottom).

  @override
  Widget build(BuildContext context) {
    final label = kind.label;
    final (top, bottom) = powerUpColors[kind]!;
    final labelStyle = AppText.display(
      size * 0.26,
      color: AppColors.white,
    ).copyWith(fontWeight: FontWeight.w700);
    final empty = count <= 0;
    return PressableScale(
      onTap: onTap,
      semanticLabel: active
          ? '$label, selected, $count left'
          : '$label, $count left',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: empty ? 0.5 : 1,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          scale: active ? 1.12 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size * 1.12,
                height: size * 1.05,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.white,
                          width: size * 0.06,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [top, bottom],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: bottom.withValues(alpha: 0.45),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                          if (active)
                            const BoxShadow(
                              color: Color(0xCCFFE680),
                              blurRadius: 18,
                              spreadRadius: 6,
                            ),
                        ],
                      ),
                      child: CustomPaint(painter: PowerUpIconPainter(kind)),
                    ),
                    // Gloss.
                    Positioned(
                      top: size * 0.1,
                      child: Container(
                        width: size * 0.55,
                        height: size * 0.22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(size),
                          color: AppColors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    // Count badge.
                    Positioned(
                      right: 0,
                      bottom: size * 0.02,
                      child: Container(
                        width: size * 0.38,
                        height: size * 0.38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.candyPurple,
                          border: Border.all(color: AppColors.white, width: 2),
                        ),
                        child: Text(
                          '$count',
                          style: AppText.display(
                            size * 0.22,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                children: [
                  Text(
                    label,
                    style: labelStyle.copyWith(
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = size * 0.06
                        ..strokeJoin = StrokeJoin.round
                        ..color = AppColors.woodDark,
                    ),
                  ),
                  Text(label, style: labelStyle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glossy disc colours (top, bottom) per power-up.
const Map<PowerUp, (Color, Color)> powerUpColors = {
  PowerUp.sweep: (Color(0xFFFFE07A), Color(0xFFF6A93B)),
  PowerUp.pop: (Color(0xFF8FB4FF), Color(0xFF3F5FD6)),
  PowerUp.grow: (Color(0xFF9EEB8A), Color(0xFF3DB54A)),
  PowerUp.shake: (Color(0xFFC9A8FF), Color(0xFF7B4FE0)),
};

/// A small glossy power-up disc (e.g. reward rows, shop), same art as the
/// gameplay buttons.
class PowerUpIcon extends StatelessWidget {
  const PowerUpIcon({super.key, required this.kind, required this.size});

  final PowerUp kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = powerUpColors[kind]!;
    return Semantics(
      label: kind.label,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: size * 0.07),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ),
        ),
        child: CustomPaint(painter: PowerUpIconPainter(kind)),
      ),
    );
  }
}

/// Vector icons: broom, bomb, up-arrow, swirl.
class PowerUpIconPainter extends CustomPainter {
  const PowerUpIconPainter(this.kind);
  final PowerUp kind;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final u = s.width;
    final p = Paint()..isAntiAlias = true;
    switch (kind) {
      case PowerUp.sweep:
        // Handle.
        p
          ..color = const Color(0xFF9A5424)
          ..strokeWidth = u * 0.07
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          c + Offset(u * 0.2, -u * 0.26),
          c + Offset(-u * 0.04, u * 0.04),
          p,
        );
        // Bristles.
        final head = Path()
          ..moveTo(c.dx - u * 0.1, c.dy - u * 0.02)
          ..lineTo(c.dx + u * 0.06, c.dy + u * 0.12)
          ..lineTo(c.dx - u * 0.12, c.dy + u * 0.3)
          ..lineTo(c.dx - u * 0.3, c.dy + u * 0.14)
          ..close();
        p.color = const Color(0xFFFFF1B8);
        canvas.drawPath(head, p);
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.03
          ..color = const Color(0xFFC98E52);
        canvas.drawPath(head, p);
      case PowerUp.pop:
        p.color = const Color(0xFF26304F);
        canvas.drawCircle(c + Offset(0, u * 0.05), u * 0.24, p);
        p.color = const Color(0x66FFFFFF);
        canvas.drawCircle(c + Offset(-u * 0.08, -u * 0.03), u * 0.06, p);
        p.color = const Color(0xFF26304F);
        canvas.drawRect(
          Rect.fromCenter(
            center: c + Offset(u * 0.12, -u * 0.17),
            width: u * 0.12,
            height: u * 0.1,
          ),
          p,
        );
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.035
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFC98E52);
        final fuse = Path()
          ..moveTo(c.dx + u * 0.15, c.dy - u * 0.22)
          ..quadraticBezierTo(
            c.dx + u * 0.22,
            c.dy - u * 0.34,
            c.dx + u * 0.3,
            c.dy - u * 0.28,
          );
        canvas.drawPath(fuse, p);
        p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFD166);
        canvas.drawCircle(c + Offset(u * 0.31, -u * 0.29), u * 0.05, p);
      case PowerUp.grow:
        final arrow = Path()
          ..moveTo(c.dx, c.dy - u * 0.3)
          ..lineTo(c.dx + u * 0.26, c.dy - u * 0.02)
          ..lineTo(c.dx + u * 0.1, c.dy - u * 0.02)
          ..lineTo(c.dx + u * 0.1, c.dy + u * 0.28)
          ..lineTo(c.dx - u * 0.1, c.dy + u * 0.28)
          ..lineTo(c.dx - u * 0.1, c.dy - u * 0.02)
          ..lineTo(c.dx - u * 0.26, c.dy - u * 0.02)
          ..close();
        p.color = AppColors.white;
        canvas.drawPath(arrow, p);
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.03
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF2B8A36);
        canvas.drawPath(arrow, p);
      case PowerUp.shake:
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.08
          ..strokeCap = StrokeCap.round;
        const colors = [
          Color(0xFFFF8FA3),
          Color(0xFFFFD166),
          Color(0xFF8FD3C7),
          Color(0xFF8EC5FF),
        ];
        for (var i = 0; i < 4; i++) {
          p.color = colors[i];
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: u * 0.23),
            i * math.pi / 2 + 0.2,
            math.pi / 2 - 0.4,
            false,
            p,
          );
        }
        p
          ..style = PaintingStyle.fill
          ..color = AppColors.white;
        canvas.drawCircle(c, u * 0.07, p);
    }
  }

  @override
  bool shouldRepaint(PowerUpIconPainter old) => old.kind != kind;
}
