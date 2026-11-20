import 'dart:math' as math;

import '../../core/constants/game_constants.dart';

/// A resting circle in world units.
typedef BoardCircle = ({double x, double y, double r});

/// Pure geometry for straight-down drops in the jar.
///
/// Used to draw the aim guide (where will it land?). In Phase 3 it also
/// decides where a dropped creature comes to rest; Phase 4 hands resting
/// over to the physics engine and keeps this only for the guide.
abstract final class DropGeometry {
  /// Keeps a circle of radius [r] inside the jar walls.
  static double clampX(double x, double r) =>
      x.clamp(r, GameConstants.worldWidth - r).toDouble();

  /// Center Y where a circle of radius [r] falling straight down at [x]
  /// first touches the floor or one of [circles].
  static double landingY(double x, double r, Iterable<BoardCircle> circles) {
    var best = GameConstants.worldHeight - r; // floor
    for (final c in circles) {
      final reach = r + c.r;
      final dx = (x - c.x).abs();
      if (dx >= reach) continue;
      final contact = c.y - math.sqrt(reach * reach - dx * dx);
      if (contact < best) best = contact;
    }
    return best;
  }
}
