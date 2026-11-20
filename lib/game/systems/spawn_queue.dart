import 'dart:math' as math;

import '../../core/constants/game_constants.dart';

/// Decides which creature level comes next.
///
/// Weighted towards small creatures; never hands out more than
/// [GameConstants.maxSpawnLevel]. The very first creature is always a
/// Tiny Puff so a new run starts gently. Pass a [seed] for reproducible
/// sequences (tests, daily challenge).
class SpawnQueue {
  SpawnQueue({int? seed}) : _rng = math.Random(seed);

  /// Relative odds for levels 1..5.
  static const List<int> weights = [34, 28, 20, 12, 6];

  final math.Random _rng;
  int _next = 1;

  /// The level that [take] will return next (shown in the "NEXT" bubble).
  int get peek => _next;

  /// Returns the next level and rolls a new one behind it.
  int take() {
    final v = _next;
    _next = _roll();
    return v;
  }

  int _roll() {
    final n = math.min(GameConstants.maxSpawnLevel, weights.length);
    var total = 0;
    for (var i = 0; i < n; i++) {
      total += weights[i];
    }
    var pick = _rng.nextInt(total);
    for (var i = 0; i < n; i++) {
      pick -= weights[i];
      if (pick < 0) return i + 1;
    }
    return 1;
  }
}
