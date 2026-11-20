import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants/game_constants.dart';
import '../models/creature_spec.dart';
import '../rendering/creature_renderer.dart';
import '../systems/drop_geometry.dart';

/// The creature waiting at the top of the jar plus the aim guide.
///
/// The held creature glides toward the player's finger, pops in with a
/// bouncy scale after each drop, and a dashed guide line with a ghost
/// outline shows exactly where it will land.
class DropperComponent extends Component {
  DropperComponent({required this.landingFor, this.reduceMotion = false})
    : super(priority: 10);

  /// Asks the game where a creature of radius r dropped at x would rest.
  final double Function(double x, double r) landingFor;
  final bool reduceMotion;

  CreatureSpec? _held;

  /// Hidden while the player is picking a power-up target.
  bool hidden = false;
  double _aimX = GameConstants.worldWidth / 2;
  double _x = GameConstants.worldWidth / 2;
  double _sinceLoad = 99;
  double _time = 0;

  CreatureSpec? get held => _held;
  bool get isReady => _held != null;

  /// Current visual X of the held creature (this is where it drops).
  double get x => _x;

  static final Paint _guide = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 0.07;
  static final Paint _ghost = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.06;

  /// Places a new creature in the holder.
  void load(CreatureSpec spec) {
    _held = spec;
    _sinceLoad = 0;
    _aimX = DropGeometry.clampX(_aimX, spec.radius);
    _x = DropGeometry.clampX(_x, spec.radius);
  }

  /// Removes and returns the held creature (null if still cooling down).
  ///
  /// Snaps to the aim point first, so a quick tap drops exactly where the
  /// finger was even if the glide animation hadn't caught up yet.
  CreatureSpec? release() {
    final h = _held;
    _held = null;
    _x = _aimX;
    return h;
  }

  void aim(double worldX) {
    final r = _held?.radius ?? 0.5;
    _aimX = DropGeometry.clampX(worldX, r);
  }

  @override
  void update(double dt) {
    _time += dt;
    _sinceLoad += dt;
    if (reduceMotion) {
      _x = _aimX;
    } else {
      // Critically-damped-feeling follow; frame-rate independent.
      _x += (_aimX - _x) * (1 - math.exp(-28 * dt));
    }
  }

  @override
  void render(Canvas canvas) {
    final spec = _held;
    if (spec == null || hidden) return;
    final r = spec.radius;
    final holderY = GameConstants.holderY;

    // Pop-in: 0 → overshoot → 1.
    var pop = 1.0;
    if (!reduceMotion && _sinceLoad < 0.4) {
      final t = _sinceLoad / 0.4;
      pop = 1 + 0.25 * math.sin(t * math.pi) - (1 - t) * (1 - t) * 1.0;
      pop = pop.clamp(0.0, 1.3);
    }

    // Guide line + ghost landing outline (fade in after pop).
    final guideAlpha = (_sinceLoad / 0.3).clamp(0.0, 1.0);
    if (guideAlpha > 0) {
      final landY = landingFor(_x, r);
      final top = holderY + r;
      final bottom = landY - r;
      _guide.color = spec.shade.withValues(alpha: 0.45 * guideAlpha);
      const dash = 0.28, gap = 0.2;
      // Marching dashes for a subtle "alive" feel.
      final offset = reduceMotion ? 0.0 : (_time * 0.8) % (dash + gap);
      for (var y = top + offset; y < bottom; y += dash + gap) {
        canvas.drawLine(
          Offset(_x, y),
          Offset(_x, math.min(y + dash, bottom)),
          _guide,
        );
      }
      _ghost.color = spec.shade.withValues(alpha: 0.35 * guideAlpha);
      canvas.drawCircle(Offset(_x, landY), r * 0.93, _ghost);
    }

    // Held creature with a little idle sway.
    final sway = reduceMotion ? 0.0 : math.sin(_time * 3) * 0.04;
    canvas.save();
    canvas.translate(_x, holderY);
    canvas.rotate(sway);
    canvas.scale(pop);
    CreatureRenderer.paint(canvas, spec, r, shadow: false);
    canvas.restore();
  }
}
