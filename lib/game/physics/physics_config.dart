/// Physics tuning in one place. World units are meters (the jar is
/// 10 × 14 m), which keeps creatures (0.4–2.2 m) in Box2D's sweet spot.
abstract final class PhysicsConfig {
  /// Fixed simulation step. 120 Hz means exactly 2 steps per 60 Hz frame
  /// and 1 per 120 Hz frame, so motion is smooth on ProMotion displays and
  /// identical inputs always give identical results.
  static const double fixedStep = 1 / 120;

  /// Box2D v3 solver sub-steps per step (2 × 120 Hz ≈ the recommended
  /// 4 × 60 Hz in cost and stability).
  static const int subSteps = 2;

  /// Upper bound on steps per frame, so a slow frame can't trigger an
  /// ever-growing catch-up ("spiral of death"). Leftover time is dropped.
  static const int maxStepsPerFrame = 6;

  /// Speed cap in m/s. Together with the fixed step this bounds travel per
  /// step to 0.25 m, well under the smallest creature radius (0.42 m), so
  /// creature-vs-creature tunneling can't happen; walls additionally use
  /// Box2D's continuous collision.
  static const double maxLinearSpeed = 30;

  // Creature material: soft, slightly bouncy, settles quickly.
  static const double density = 1;
  static const double friction = 0.45;
  static const double restitution = 0.12;
  static const double rollingResistance = 0.06;
  static const double linearDamping = 0.08;
  static const double angularDamping = 1.6;

  /// Collision radius relative to the drawn radius (the fluffy scallops
  /// stick out a little, so touching looks like touching).
  static const double collisionScale = 0.95;

  /// Initial downward speed of a dropped creature (m/s) so the release
  /// feels responsive rather than floaty.
  static const double dropSpeed = 3;

  /// Impacts slower than this (m/s) produce no hit event (no squash/sound).
  static const double hitThreshold = 1.5;

  /// Below this speed Box2D treats collisions as inelastic (no bounce),
  /// which stops piles from jittering forever.
  static const double restitutionThreshold = 1.2;

  /// Two Rainbow Puffs merging pop in a burst that gently pushes
  /// neighbours outward (Box2D explosion; impulse scales with each shape's
  /// perimeter, so small puffs fly a bit more than big ones).
  /// Full strength within [clearBurstRadius], fading to zero over a further
  /// [clearBurstFalloff] meters.
  static const double clearBurstRadius = 2.5;
  static const double clearBurstFalloff = 1.5;
  static const double clearBurstImpulse = 0.6;

  /// Jar walls: corner radius and how far walls extend above the opening.
  static const double cornerRadius = 0.6;
  static const int cornerSegments = 6;
  static const double wallTop = -6;
  static const double wallFriction = 0.35;
}
