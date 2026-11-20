import 'package:flutter/foundation.dart';

/// Everything the results screen (and analytics, daily challenges,
/// achievements) needs to know about a finished run.
@immutable
class RunResult {
  const RunResult({
    required this.score,
    required this.bestScore,
    required this.isNewBest,
    required this.highestLevel,
    required this.coinsEarned,
    required this.merges,
    required this.drops,
    required this.bestCombo,
    required this.seconds,
    this.interstitialDue = false,
  });

  final int score;

  /// Best score *after* this run was recorded.
  final int bestScore;
  final bool isNewBest;
  final int highestLevel;
  final int coinsEarned;
  final int merges;
  final int drops;
  final int bestCombo;

  /// Game-time length of the run.
  final double seconds;

  /// An interstitial is due (per InterstitialPolicy); shown when the player
  /// leaves the results screen, never before they've seen their score.
  final bool interstitialDue;

  @override
  String toString() =>
      'RunResult(score: $score, best: $bestScore${isNewBest ? ' NEW' : ''}, '
      'L$highestLevel, coins: $coinsEarned, merges: $merges, drops: $drops, '
      'combo: $bestCombo, ${seconds.toStringAsFixed(0)}s)';
}
