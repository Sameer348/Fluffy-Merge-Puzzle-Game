import 'package:flame/components.dart';

import '../../core/constants/game_constants.dart';

/// Pure helpers for placing the creature a merge produces.
abstract final class MergeMath {
  /// Keeps only part of the pair's momentum so merges feel soft, not
  /// explosive.
  static const double velocityKeep = 0.6;

  /// Midpoint of the two creatures, nudged so a creature of [newRadius]
  /// fits inside the walls and above the floor.
  static Vector2 position(Vector2 a, Vector2 b, double newRadius) {
    final mid = (a + b)..scale(0.5);
    mid.x = mid.x.clamp(newRadius, GameConstants.worldWidth - newRadius);
    if (mid.y > GameConstants.worldHeight - newRadius) {
      mid.y = GameConstants.worldHeight - newRadius;
    }
    return mid;
  }

  /// Momentum-weighted average velocity of the pair, softened.
  static Vector2 velocity(Vector2 va, double ma, Vector2 vb, double mb) {
    final total = ma + mb;
    if (total <= 0) return Vector2.zero();
    return (va * ma + vb * mb)..scale(velocityKeep / total);
  }
}
