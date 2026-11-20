import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/progress_repository.dart';

/// Numbers shown in the home screen header.
class PlayerSummary {
  const PlayerSummary({required this.bestScore, required this.coins});
  final int bestScore;
  final int coins;
}

/// Read-only snapshot for the menu. The home screen invalidates it when a
/// pushed route (a run, the shop) returns.
final playerSummaryProvider = Provider<PlayerSummary>((ref) {
  final repo = ref.watch(progressRepositoryProvider);
  return PlayerSummary(bestScore: repo.bestScore, coins: repo.coins);
});
