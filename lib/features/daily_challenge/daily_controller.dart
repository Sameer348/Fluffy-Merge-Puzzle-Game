import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/clock.dart';
import '../../data/local/save_data.dart';
import '../../data/repositories/save_controller.dart';
import 'model/daily_challenge.dart';
import 'model/streak.dart';

/// Everything the Daily Challenge screen shows, computed from the save.
class DailyView {
  const DailyView({
    required this.challenge,
    required this.progress,
    required this.completed,
    required this.claimed,
    required this.streak,
    required this.timeLeft,
  });

  final DailyChallenge challenge;
  final int progress;
  final bool completed;
  final bool claimed;
  final StreakStatus streak;
  final Duration timeLeft;

  /// Something is waiting to be collected (drives the home badge).
  bool get hasReward => (completed && !claimed) || !streak.claimedToday;
}

/// Daily challenge + streak rules on top of [SaveController].
class DailyController {
  DailyController(this._ref);

  final Ref _ref;

  DateTime get _now => _ref.read(clockProvider)();
  SaveController get _save => _ref.read(saveProvider.notifier);
  SaveData get _data => _ref.read(saveProvider);

  DailyChallenge today() => DailyChallenge.forDay(_now);

  /// Stored progress for [c], or a blank one if the save holds another
  /// day's (or another challenge's) progress.
  DailyProgress progressFor(DailyChallenge c) {
    final d = _data.daily;
    return d.challengeId == c.id
        ? d
        : DailyProgress(date: c.date, challengeId: c.id);
  }

  DailyView view() {
    final now = _now;
    final c = DailyChallenge.forDay(now);
    final p = progressFor(c);
    return DailyView(
      challenge: c,
      progress: p.progress,
      completed: p.completed,
      claimed: p.claimed,
      streak: Streak.status(_data.streak, now),
      timeLeft: untilMidnight(now),
    );
  }

  /// Applies a run to [c]'s progress. [baseline] is the stored progress
  /// when the run started, so calling this repeatedly during one run
  /// (live checks, app backgrounded, run end) never double-counts.
  ///
  /// With [persistProgress] false (live checks every merge) it only writes
  /// when the challenge completes. Returns true on the call that completes
  /// it.
  bool applyRun(
    DailyChallenge c,
    int baseline,
    RunSnapshot run, {
    bool persistProgress = true,
  }) {
    final stored = progressFor(c);
    if (stored.completed) return false;
    final progress = c.combine(baseline, run);
    final completed = progress >= c.target;
    if (!completed && (!persistProgress || progress == stored.progress)) {
      return false;
    }
    _save.setDaily(
      DailyProgress(
        date: c.date,
        challengeId: c.id,
        progress: progress,
        completed: completed,
      ),
    );
    return completed;
  }

  /// Grants today's challenge reward once. Returns false if not completed
  /// or already claimed.
  bool claimChallenge() {
    final c = today();
    final p = progressFor(c);
    if (!p.completed || p.claimed) return false;
    _save
      ..addCoins(c.coins)
      ..addPowerUp(c.powerUp)
      ..setDaily(
        DailyProgress(
          date: p.date,
          challengeId: p.challengeId,
          progress: p.progress,
          completed: true,
          claimed: true,
        ),
      );
    return true;
  }

  /// Claims today's streak reward. Returns it, or null if already claimed.
  StreakReward? claimStreak() {
    final now = _now;
    final status = Streak.status(_data.streak, now);
    if (status.claimedToday) return null;
    final reward = Streak.rewards[status.dayToClaim - 1];
    _save
      ..setStreak(Streak.claim(_data.streak, now))
      ..addCoins(reward.coins);
    for (final e in reward.powerUps.entries) {
      _save.addPowerUp(e.key, e.value);
    }
    return reward;
  }
}

final dailyControllerProvider = Provider<DailyController>(DailyController.new);

/// Recomputes whenever the save's daily/streak data changes.
final dailyViewProvider = Provider<DailyView>((ref) {
  ref.watch(saveProvider.select((s) => (s.daily, s.streak)));
  return ref.read(dailyControllerProvider).view();
});
