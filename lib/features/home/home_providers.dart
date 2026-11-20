import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/save_controller.dart';

/// Numbers shown in the home screen header.
class PlayerSummary {
  const PlayerSummary({required this.bestScore, required this.coins});
  final int bestScore;
  final int coins;

  @override
  bool operator ==(Object other) =>
      other is PlayerSummary &&
      other.bestScore == bestScore &&
      other.coins == coins;

  @override
  int get hashCode => Object.hash(bestScore, coins);
}

/// Best score and coins, straight from the save. Rebuilds only when one of
/// those two changes.
final playerSummaryProvider = Provider<PlayerSummary>(
  (ref) => ref.watch(
    saveProvider.select(
      (s) => PlayerSummary(bestScore: s.bestScore, coins: s.coins),
    ),
  ),
);
