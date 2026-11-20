import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../models/creature_spec.dart';
import '../physics/jar_world.dart';
import '../physics/physics_config.dart';
import '../rendering/creature_renderer.dart';
import '../systems/drop_geometry.dart';
import '../systems/merge_detector.dart';

/// One creature in the jar: a dynamic Box2D circle plus procedural life
/// (breathing, blinking, expressions, squash-and-stretch on impact).
///
/// Rendering notes:
/// * Squash/stretch is applied along *screen* axes (gravity direction),
///   anchored at the creature's base, so it always reads as "landing".
/// * The face doesn't spin with the body. A circle looks identical at any
///   angle, so only the face shows rotation; we map the body angle to a
///   gentle rock (±0.4 rad) so rolling reads as a cute wobble and resting
///   puffs never end up upside down.
class CreatureComponent extends BodyComponent
    implements ImpactListener, MergeCandidate {
  CreatureComponent({
    required this.id,
    required this.spec,
    required Vector2 position,
    Vector2? velocity,
    this.reduceMotion = false,
    this.onMounted,
    this.onRemoved,
    this.fromMerge = false,
    int seed = 0,
  }) : _spawnPosition = position.clone(),
       _spawnVelocity = velocity?.clone() ?? Vector2.zero(),
       _rng = math.Random(seed),
       super(renderBody: false) {
    _time = _rng.nextDouble() * 10;
    _nextBlink = 1.5 + _rng.nextDouble() * 3;
    if (fromMerge) {
      _hasLanded = true;
      _popAge = 0;
      _setExpression(CreatureExpression.excited, 0.7);
    }
  }

  /// Born from a merge: starts "landed", pops in, looks excited.
  final bool fromMerge;

  /// Unique per run, increasing in spawn order.
  @override
  final int id;

  final CreatureSpec spec;
  final bool reduceMotion;

  /// Called when the creature leaves the jar for any reason, so the game
  /// can drop it from its lists and the merge detector.
  final void Function(CreatureComponent)? onRemoved;

  /// Called once the body exists and the creature is in the world.
  final void Function(CreatureComponent)? onMounted;

  @override
  int get level => spec.level;

  @override
  bool claimedForMerge = false;

  @override
  bool get canMerge => !claimedForMerge && isMounted && !isRemoving;
  final Vector2 _spawnPosition;
  final Vector2 _spawnVelocity;
  final math.Random _rng;

  CreatureExpression expression = CreatureExpression.surprised;

  /// Face shown when nothing special is happening. The game switches this
  /// to [CreatureExpression.worried] when the jar is nearly full.
  CreatureExpression idleExpression = CreatureExpression.happy;

  /// Pulsing glow showing it can be picked (POP / GROW targeting).
  bool highlighted = false;

  static final Paint _glow = Paint()..isAntiAlias = true;

  /// Seconds since this creature appeared.
  double get age => _sinceSpawn;

  double get radius => spec.radius;

  /// Physics collision radius.
  double get bodyRadius => spec.radius * PhysicsConfig.collisionScale;

  double get x => body.position.x;
  double get y => body.position.y;

  /// Current circle for the drop guide.
  BoardCircle get restCircle => (x: x, y: y, r: bodyRadius);

  /// True until the creature first hits something after being dropped.
  bool get isFalling => !_hasLanded;

  bool get isSleeping => !body.isAwake;

  bool _hasLanded = false;
  double _time = 0;
  double _sinceSpawn = 0;
  double _impactAge = 99;
  double _impactStrength = 0;
  double _exprHold = 0;
  double _nextBlink = 3;
  double _blinkFor = 99;
  double _popAge = 99;

  static const _popDuration = 0.42;

  /// Merge pop keyframes: 1.0 → 1.25 → 0.85 → 1.0 (smoothstep between).
  static double popScale(double t) {
    double ease(double x) => x * x * (3 - 2 * x);
    double lerp(double a, double b, double x) => a + (b - a) * ease(x);
    if (t <= 0 || t >= 1) return 1;
    if (t < 0.3) return lerp(1.0, 1.25, t / 0.3);
    if (t < 0.65) return lerp(1.25, 0.85, (t - 0.3) / 0.35);
    return lerp(0.85, 1.0, (t - 0.65) / 0.35);
  }

  static const _blinkDuration = 0.16;

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: _spawnPosition,
        linearVelocity: _spawnVelocity,
        linearDamping: PhysicsConfig.linearDamping,
        angularDamping: PhysicsConfig.angularDamping,
        userData: this,
      ),
    );
    body.createShape(
      Circle(radius: bodyRadius),
      ShapeDef(
        density: PhysicsConfig.density,
        material: SurfaceMaterial(
          friction: PhysicsConfig.friction,
          restitution: PhysicsConfig.restitution,
          rollingResistance: PhysicsConfig.rollingResistance,
        ),
        enableContactEvents: true,
        enableHitEvents: true,
        userData: this,
      ),
    );
    return body;
  }

  @override
  void onImpact(double speed) {
    if (!_hasLanded) _hasLanded = true;
    // 1.5 m/s → barely; ~10 m/s → full squash.
    final s = ((speed - PhysicsConfig.hitThreshold) / 8.5).clamp(0.0, 1.0);
    if (s <= 0) return;
    // Don't let a tiny bump cut short a big wobble that's still playing.
    if (_impactAge < 0.25 && s < _impactStrength) return;
    _impactStrength = s;
    _impactAge = 0;
    if (s > 0.25) _setExpression(CreatureExpression.squished, 0.3 + 0.2 * s);
  }

  /// Happy-excited reaction (e.g. when a matching partner is found).
  void celebrate([double hold = 0.6]) =>
      _setExpression(CreatureExpression.excited, hold);

  /// Shows [e] for [hold] seconds (ignored while still falling, so the
  /// surprised drop face isn't interrupted).
  void react(CreatureExpression e, double hold) {
    if (_hasLanded) _setExpression(e, hold);
  }

  @override
  void onMount() {
    super.onMount();
    onMounted?.call(this);
  }

  @override
  void onRemove() {
    onRemoved?.call(this);
    super.onRemove();
  }

  void _setExpression(CreatureExpression e, double hold) {
    expression = e;
    _exprHold = hold;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _sinceSpawn += dt;
    _impactAge += dt;
    _popAge += dt;

    // Safety net: a creature dropped onto a slow-moving pile may never
    // produce a hit event above the threshold.
    if (!_hasLanded && _sinceSpawn > 1.5) _hasLanded = true;

    if (_exprHold > 0) {
      _exprHold -= dt;
    } else if (_hasLanded) {
      expression = idleExpression;
    }

    _blinkFor += dt;
    _nextBlink -= dt;
    if (_nextBlink <= 0) {
      _blinkFor = 0;
      _nextBlink = 2.2 + _rng.nextDouble() * 3.5;
    }
  }

  @override
  void render(Canvas canvas) {
    final r = radius;
    var sx = 1.0, sy = 1.0;
    var blink = 0.0;
    var faceAngle = 0.0;

    if (!reduceMotion) {
      final breath = math.sin(_time * 2.4);
      sy = 1 + 0.025 * breath;
      sx = 1 - 0.018 * breath;

      // Stretch slightly while falling fast.
      if (!_hasLanded) {
        final v = body.linearVelocity.y.clamp(
          0.0,
          PhysicsConfig.maxLinearSpeed,
        );
        final s = v / PhysicsConfig.maxLinearSpeed * 0.12;
        sy += s;
        sx -= s * 0.7;
      }

      // Impact wobble: squash, overshoot, settle.
      if (_impactAge < 0.6) {
        final w =
            _impactStrength *
            math.exp(-7 * _impactAge) *
            math.cos(_impactAge * 22);
        sy *= 1 - 0.22 * w;
        sx *= 1 + 0.17 * w;
      }

      if (_blinkFor < _blinkDuration) {
        blink = math.sin(_blinkFor / _blinkDuration * math.pi);
      }
      faceAngle = 0.4 * math.sin(body.angle);
    }

    // The canvas arrives rotated by body.angle (BodyComponent.renderTree).
    // Undo it so squash and the shadow use screen axes, then apply the
    // gentle face rock.
    canvas.save();
    canvas.rotate(-body.angle);

    if (highlighted) {
      final pulse = reduceMotion ? 0.5 : 0.5 + 0.5 * math.sin(_time * 6);
      // Soft halo plus a bold pulsing gold ring: readable on cream glass.
      _glow
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFE680)
            .withValues(alpha: 0.35 + 0.25 * pulse);
      canvas.drawCircle(Offset.zero, r * (1.18 + 0.06 * pulse), _glow);
      _glow
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * (0.09 + 0.03 * pulse)
        ..color = const Color(0xFFF2A51A)
            .withValues(alpha: 0.75 + 0.25 * pulse);
      canvas.drawCircle(Offset.zero, r * (1.08 + 0.05 * pulse), _glow);
      _glow.style = PaintingStyle.fill;
    }

    // Merge pop: uniform scale around the center.
    if (!reduceMotion && _popAge < _popDuration) {
      final p = popScale(_popAge / _popDuration);
      canvas.scale(p);
    }

    // Anchor squash at the base so the creature stays planted.
    final base = r * 0.93;
    canvas.translate(0, base * (1 - sy));
    canvas.scale(sx, sy);
    canvas.rotate(faceAngle);
    CreatureRenderer.paint(
      canvas,
      spec,
      r,
      expression: expression,
      blink: blink,
    );
    canvas.restore();
  }
}
