import 'package:flutter/foundation.dart';

import '../../../core/utils/clock.dart';
import '../../../data/local/save_data.dart';
import '../../../game/models/power_up.dart';

/// Reward for one day of the 7-day streak.
@immutable
class StreakReward {
  const StreakReward(this.coins, [this.powerUps = const {}]);

  final int coins;
  final Map<PowerUp, int> powerUps;

  bool get isGift => powerUps.isNotEmpty;
}

/// Where the player stands in the 7-day login streak today.
@immutable
class StreakStatus {
  const StreakStatus({
    required this.dayToClaim,
    required this.claimedToday,
    required this.daysDone,
  });

  /// 1..7: the streak day today's claim counts as (or was claimed as).
  final int dayToClaim;
  final bool claimedToday;

  /// How many of the 7 tiles show a check mark.
  final int daysDone;
}

/// 7-day streak rules:
/// * Claim once per calendar day.
/// * Claiming the day after your last claim continues the streak; missing
///   a day starts over at Day 1.
/// * After Day 7 (the gift) the cycle restarts at Day 1.
abstract final class Streak {
  static const List<StreakReward> rewards = [
    StreakReward(50),
    StreakReward(75),
    StreakReward(100),
    StreakReward(125),
    StreakReward(150),
    StreakReward(200),
    StreakReward(300, {PowerUp.pop: 1, PowerUp.grow: 1}),
  ];

  static StreakStatus status(StreakData s, DateTime now) {
    final last = parseDayKey(s.lastClaimDate);
    final gap = last == null ? null : daysBetween(last, now);
    final dayInCycle = s.count <= 0 ? 0 : ((s.count - 1) % 7) + 1;

    if (gap == 0) {
      return StreakStatus(
        dayToClaim: dayInCycle,
        claimedToday: true,
        daysDone: dayInCycle,
      );
    }
    final continues = gap == 1 && s.count > 0;
    final next = continues ? (dayInCycle % 7) + 1 : 1;
    return StreakStatus(
      dayToClaim: next,
      claimedToday: false,
      daysDone: next - 1,
    );
  }

  /// The streak after claiming today. Same object if already claimed.
  static StreakData claim(StreakData s, DateTime now) {
    final st = status(s, now);
    if (st.claimedToday) return s;
    final last = parseDayKey(s.lastClaimDate);
    final continues = last != null && daysBetween(last, now) == 1;
    return StreakData(
      count: continues ? s.count + 1 : 1,
      lastClaimDate: dayKey(now),
    );
  }
}
