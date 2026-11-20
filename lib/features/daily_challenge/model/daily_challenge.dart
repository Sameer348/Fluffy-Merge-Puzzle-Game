import 'package:flutter/foundation.dart';

import '../../../core/utils/clock.dart';
import '../../../game/models/creature_spec.dart';
import '../../../game/models/power_up.dart';

/// What a daily challenge measures.
enum ChallengeKind {
  /// Best score in a single run today.
  score(cumulative: false),

  /// Highest creature level created today.
  level(cumulative: false),

  /// Merges added up across all of today's runs.
  merges(cumulative: true),

  /// Best combo today.
  combo(cumulative: false),

  /// Most drops in a single run today ("survive N drops").
  drops(cumulative: false);

  const ChallengeKind({required this.cumulative});

  /// True: today's runs add up. False: the best single run counts.
  final bool cumulative;
}

/// The numbers from a run (finished or in progress) that challenges read.
@immutable
class RunSnapshot {
  const RunSnapshot({
    this.score = 0,
    this.highestLevel = 0,
    this.merges = 0,
    this.bestCombo = 0,
    this.drops = 0,
  });

  final int score;
  final int highestLevel;
  final int merges;
  final int bestCombo;
  final int drops;

  int valueFor(ChallengeKind k) => switch (k) {
    ChallengeKind.score => score,
    ChallengeKind.level => highestLevel,
    ChallengeKind.merges => merges,
    ChallengeKind.combo => bestCombo,
    ChallengeKind.drops => drops,
  };
}

/// One day's challenge.
@immutable
class DailyChallenge {
  const DailyChallenge({
    required this.date,
    required this.kind,
    required this.target,
    required this.coins,
    required this.powerUp,
  });

  /// [dayKey] this challenge belongs to.
  final String date;
  final ChallengeKind kind;
  final int target;
  final int coins;

  /// Bonus power-up (one) granted with the coins.
  final PowerUp powerUp;

  /// Stable id stored with progress, so a changed challenge pool in a later
  /// update never applies yesterday's progress to a different challenge.
  String get id => '$date:${kind.name}:$target';

  String get title => switch (kind) {
    ChallengeKind.score => 'Reach ${_fmt(target)} Points',
    ChallengeKind.level => 'Create a ${CreatureCatalog.byLevel(target).name}',
    ChallengeKind.merges => 'Make $target Merges',
    ChallengeKind.combo => 'Hit a ${target}x Combo',
    ChallengeKind.drops => 'Survive $target Drops',
  };

  String get detail => switch (kind) {
    ChallengeKind.score => 'Score it in a single run.',
    ChallengeKind.level => 'Merge your way up to Lv. $target.',
    ChallengeKind.merges => 'All of today\'s runs count.',
    ChallengeKind.combo => 'Chain merges quickly in one go.',
    ChallengeKind.drops => 'Drop that many puffs in one run.',
  };

  /// Today's progress after combining the stored value from earlier runs
  /// ([before]) with the current run ([run]). Never above [target].
  int combine(int before, RunSnapshot run) {
    final v = run.valueFor(kind);
    final next = kind.cumulative ? before + v : (v > before ? v : before);
    return next.clamp(0, target);
  }

  /// Picks the challenge for a calendar day. Everyone gets the same one on
  /// the same date; consecutive days rotate through kinds, and the target
  /// difficulty varies too.
  factory DailyChallenge.forDay(DateTime day) {
    final n = daysBetween(DateTime(2026), day);
    // Knuth multiplicative hash: well-spread, stable across platforms.
    final h = (n * 2654435761) & 0x7fffffff;
    final kind =
        _kindOrder[(n % _kindOrder.length + _kindOrder.length) %
            _kindOrder.length];
    final tier = (h >> 8) % 3;
    final (target, coins) = _tiers[kind]![tier];
    return DailyChallenge(
      date: dayKey(day),
      kind: kind,
      target: target,
      coins: coins,
      powerUp: PowerUp.values[(h >> 4) % PowerUp.values.length],
    );
  }

  /// A fixed, shuffled kind order so neighbouring days always differ.
  static const _kindOrder = [
    ChallengeKind.score,
    ChallengeKind.merges,
    ChallengeKind.level,
    ChallengeKind.drops,
    ChallengeKind.combo,
  ];

  /// (target, coin reward) per difficulty tier.
  static const Map<ChallengeKind, List<(int, int)>> _tiers = {
    ChallengeKind.score: [(3000, 120), (5000, 200), (8000, 300)],
    ChallengeKind.level: [(7, 120), (8, 200), (9, 300)],
    ChallengeKind.merges: [(25, 100), (40, 160), (60, 240)],
    ChallengeKind.combo: [(4, 120), (5, 200), (6, 300)],
    ChallengeKind.drops: [(60, 100), (80, 160), (100, 240)],
  };

  static String _fmt(int n) {
    final s = '$n';
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}
