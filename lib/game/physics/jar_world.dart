import 'package:flame_forge2d/flame_forge2d.dart';

import '../../core/constants/game_constants.dart';
import 'physics_config.dart';

/// Something that wants to know when it bumps into something hard enough.
abstract interface class ImpactListener {
  /// [speed] is the approach speed in m/s along the contact normal.
  void onImpact(double speed);
}

/// Receives begin/end touch events between two bodies' user data
/// (e.g. two creatures). Called after each physics step, never during it.
abstract interface class TouchListener {
  void onTouchBegin(Object a, Object b);
  void onTouchEnd(Object a, Object b);
}

/// Forge2D world with a fixed time step.
///
/// Flame calls [update] with the frame's variable dt; we accumulate it and
/// advance Box2D in exact [PhysicsConfig.fixedStep] increments, dispatching
/// contact events after *each* step (Box2D only keeps the latest step's
/// events). Hit events (impact speed) are routed to [ImpactListener]s,
/// which flame_forge2d doesn't do by itself.
class JarWorld extends Forge2DWorld {
  JarWorld()
    : super(
        gravity: Vector2(0, GameConstants.gravity),
        definition: WorldDef(
          gravity: Vector2(0, GameConstants.gravity),
          hitEventThreshold: PhysicsConfig.hitThreshold,
          restitutionThreshold: PhysicsConfig.restitutionThreshold,
          maximumLinearSpeed: PhysicsConfig.maxLinearSpeed,
        ),
      );

  /// Gets creature-vs-creature touch events (set by the game).
  TouchListener? touchListener;

  double _accumulator = 0;
  int _steps = 0;

  /// Physics steps taken since the world started (for tests/diagnostics).
  int get stepCount => _steps;

  bool _disposed = false;

  @override
  void update(double dt) {
    if (_disposed) return;
    _accumulator += dt;
    var n = 0;
    while (_accumulator >= PhysicsConfig.fixedStep &&
        n < PhysicsConfig.maxStepsPerFrame) {
      step();
      _accumulator -= PhysicsConfig.fixedStep;
      n++;
    }
    if (n == PhysicsConfig.maxStepsPerFrame) _accumulator = 0;
  }

  /// Advances exactly one fixed step and dispatches its events.
  void step() {
    physicsWorld.step(
      PhysicsConfig.fixedStep,
      subStepCount: PhysicsConfig.subSteps,
    );
    _steps++;
    final events = physicsWorld.contactEvents;
    contactEventsDispatcher.dispatch(events, physicsWorld.sensorEvents);
    final listener = touchListener;
    if (listener != null) {
      for (final e in events.begin) {
        _route(e.shapeA, e.shapeB, listener.onTouchBegin);
      }
      for (final e in events.end) {
        // Shapes of destroyed bodies are invalid here; their pairs are
        // dropped explicitly when the creature is removed.
        _route(e.shapeA, e.shapeB, listener.onTouchEnd);
      }
    }
    for (final hit in events.hit) {
      if (!hit.shapeA.isValid || !hit.shapeB.isValid) continue;
      final a = hit.shapeA.body.userData;
      final b = hit.shapeB.body.userData;
      if (a is ImpactListener) a.onImpact(hit.approachSpeed);
      if (b is ImpactListener) b.onImpact(hit.approachSpeed);
    }
  }

  static void _route(Shape a, Shape b, void Function(Object a, Object b) fn) {
    if (!a.isValid || !b.isValid) return;
    final ua = a.body.userData, ub = b.body.userData;
    if (ua != null && ub != null) fn(ua, ub);
  }

  /// Frees the native Box2D world. Box2D allows a limited number of
  /// simultaneous worlds and they are not garbage collected, so the game
  /// calls this when a run's screen is disposed.
  void disposePhysics() {
    if (_disposed) return;
    _disposed = true;
    final w = physicsWorld;
    if (w.isValid) w.destroy();
  }
}
