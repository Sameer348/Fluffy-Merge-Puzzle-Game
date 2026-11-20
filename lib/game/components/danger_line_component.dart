import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';

/// The dashed danger line near the jar's top, in world units.
///
/// Calm and faint while the jar has room. As [danger] (0..1) rises, a soft
/// red glow appears above the line and the line pulses faster and bolder,
/// so the warning reads by motion and thickness, not by color alone.
class DangerLineComponent extends Component {
  DangerLineComponent({required this.danger, this.reduceMotion = false})
    : super(priority: 5);

  /// Current danger level, 0 (safe) .. 1 (creatures at the line).
  final double Function() danger;
  final bool reduceMotion;

  static double get y =>
      GameConstants.worldHeight * GameConstants.dangerLineFraction;

  double _time = 0;

  static final Paint _line = Paint()
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  static final Paint _dot = Paint()..isAntiAlias = true;
  static final Paint _glow = Paint();

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) {
    final d = danger().clamp(0.0, 1.0);
    const w = GameConstants.worldWidth;
    final ly = y;

    // Pulse 0..1; speeds up with danger. Steady when reduced motion.
    final pulse = reduceMotion || d == 0
        ? 0.0
        : 0.5 + 0.5 * math.sin(_time * (4 + 8 * d));

    if (d > 0) {
      final glowH = 0.9;
      _glow.shader = Gradient.linear(Offset(0, ly - glowH), Offset(0, ly), [
        AppColors.danger.withValues(alpha: 0),
        AppColors.danger.withValues(alpha: 0.22 * d * (0.6 + 0.4 * pulse)),
      ]);
      canvas.drawRect(Rect.fromLTRB(0, ly - glowH, w, ly), _glow);
    }

    final alpha = 0.45 + 0.4 * d + 0.15 * pulse * d;
    _line
      ..color = AppColors.danger.withValues(alpha: alpha.clamp(0.0, 1.0))
      ..strokeWidth = 0.075 + 0.05 * d * (0.5 + 0.5 * pulse);
    const dash = 0.26, gap = 0.19, inset = 0.45;
    for (double x = inset; x < w - inset; x += dash + gap) {
      canvas.drawLine(
        Offset(x, ly),
        Offset(math.min(x + dash, w - inset), ly),
        _line,
      );
    }
    _dot.color = _line.color;
    final dotR = 0.09 + 0.04 * d;
    canvas.drawCircle(Offset(0.2, ly), dotR, _dot);
    canvas.drawCircle(Offset(w - 0.2, ly), dotR, _dot);
  }
}
