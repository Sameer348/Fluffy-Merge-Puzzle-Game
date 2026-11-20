/// Gameplay tuning values that the UI also needs to know about
/// (e.g. the jar's aspect ratio for responsive layout).
abstract final class GameConstants {
  /// Physics world size inside the jar, in world units (meters).
  /// The jar always keeps this aspect ratio on every device, so the
  /// playfield is identical on phones and tablets.
  static const double worldWidth = 10;
  static const double worldHeight = 14;
  static double get jarAspect => worldWidth / worldHeight;

  /// Danger line distance from the top of the jar, as a fraction of height.
  static const double dangerLineFraction = 0.14;

  /// Height (world units from the jar top) where the next creature is held.
  static const double holderY = 1.05;

  /// Pause between a drop and the next creature appearing in the holder.
  static const double dropCooldown = 0.45;

  /// Downward acceleration in world units / s² (jar is 14 units tall).
  static const double gravity = 32;

  /// Highest level the spawner hands out (bigger ones only come from merges).
  static const int maxSpawnLevel = 5;

  /// Number of creature levels.
  static const int maxLevel = 12;
}
