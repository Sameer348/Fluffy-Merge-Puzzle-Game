import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/merge_event.dart';

/// What a single merge earned.
@immutable
class ScoreAward {
  const ScoreAward({
    required this.points,
    required this.combo,
    required this.multiplier,
    required this.coins,
    required this.label,
    required this.event,
  });

  final int points;

  /// 1 for a lone merge, 2 for the second merge inside the window, …
  final int combo;
  final int multiplier;
  final int coins;

  /// Floating text headline ("MERGE!", "COMBO x2!", …).
  final String label;
  final MergeEvent event;
}

/// Turns [MergeEvent]s into score, combo and coins.
///
/// Rules:
/// * Base points grow with level: 5·L·(L+1) → 10, 30, 60, 100, 150, …
///   (a Tiny Puff merge is +10; big merges are worth much more).
/// * A merge within [comboWindow] seconds of the previous one continues the
///   combo; each step doubles the multiplier (×1, ×2, ×4, ×8 …, capped at
///   ×[maxMultiplier]). So four quick Tiny merges give +10, +20, +40, +80.
/// * Coins: merges from level 4 up pay (level − 3); combos of 3+ add one;
///   a Rainbow clear pays [rainbowClearCoins].
///
/// Pure logic plus [ValueNotifier]s for the HUD; no Flame or physics.
class ScoreSystem {
  ScoreSystem({this.bestAtStart = 0});

  static const double comboWindow = 1.1;
  static const int maxMultiplier = 16;
  static const int rainbowClearPoints = 2000;
  static const int rainbowClearCoins = 25;

  /// Best score before this run (for "NEW BEST!").
  final int bestAtStart;

  final ValueNotifier<int> score = ValueNotifier(0);
  final ValueNotifier<int> coins = ValueNotifier(0);

  /// Current combo count; drops back to 0 when the window expires.
  final ValueNotifier<int> combo = ValueNotifier(0);

  /// Highest combo reached this run (daily challenges, results screen).
  int bestCombo = 0;

  double _lastMergeTime = double.negativeInfinity;
  bool _announcedBest = false;

  static int basePoints(int level) => 5 * level * (level + 1);

  static int multiplierFor(int combo) =>
      math.min(1 << (combo - 1).clamp(0, 30), maxMultiplier);

  static String labelFor(int combo, {bool rainbow = false}) {
    if (rainbow) return 'RAINBOW BURST!';
    return switch (combo) {
      <= 1 => 'MERGE!',
      2 => 'COMBO x2!',
      3 => 'COMBO x3!',
      4 => 'AMAZING!',
      _ => 'SUPER MERGE!',
    };
  }

  static int coinsFor(int level, int combo, {bool rainbow = false}) {
    if (rainbow) return rainbowClearCoins;
    return math.max(0, level - 3) + (combo >= 3 ? 1 : 0);
  }

  /// Scores one merge.
  ScoreAward onMerge(MergeEvent e) {
    final next = e.time - _lastMergeTime <= comboWindow ? combo.value + 1 : 1;
    _lastMergeTime = e.time;
    combo.value = next;
    if (next > bestCombo) bestCombo = next;

    final mult = multiplierFor(next);
    final base = e.isMaxClear ? rainbowClearPoints : basePoints(e.fromLevel);
    final points = base * mult;
    final earned = coinsFor(e.fromLevel, next, rainbow: e.isMaxClear);
    score.value += points;
    if (earned > 0) coins.value += earned;

    return ScoreAward(
      points: points,
      combo: next,
      multiplier: mult,
      coins: earned,
      label: labelFor(next, rainbow: e.isMaxClear),
      event: e,
    );
  }

  /// Call every frame with the game clock: ends a combo whose window has
  /// passed (so the HUD can stop showing it).
  void tick(double now) {
    if (combo.value > 0 && now - _lastMergeTime > comboWindow) {
      combo.value = 0;
    }
  }

  /// True exactly once: the first time this run beats a previous best.
  bool takeNewBest() {
    if (_announcedBest || bestAtStart <= 0 || score.value <= bestAtStart) {
      return false;
    }
    return _announcedBest = true;
  }

  void dispose() {
    score.dispose();
    coins.dispose();
    combo.dispose();
  }
}
