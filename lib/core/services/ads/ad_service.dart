import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where a rewarded ad is offered. Every one is optional and the player
/// always sees what they get before choosing to watch.
enum RewardPlacement {
  /// Results screen: double the coins earned.
  doubleCoins('results_2x'),

  /// Game over: clear the top of the jar and keep playing (once per run).
  continueRun('continue'),

  /// Out of a power-up: get one free (once per power-up per run).
  freePowerUp('free_powerup');

  const RewardPlacement(this.id);
  final String id;
}

/// Ads behind an interface, so Google Mobile Ads / AppLovin / etc. can be
/// plugged in without touching screens.
///
/// Respectful-monetization rules this app follows:
/// * Rewarded ads are always optional.
/// * Interstitials only between runs, gated by [InterstitialPolicy], and
///   never after "Remove Ads".
/// * No ads mid-game, ever.
abstract interface class AdService {
  /// Whether a rewarded ad can be shown right now. Screens hide reward
  /// buttons when false rather than showing a dead button.
  bool get rewardedAvailable;

  /// Shows a rewarded ad. Resolves true only if the reward was earned.
  Future<bool> showRewarded(RewardPlacement placement);

  bool get interstitialAvailable;

  /// Shows an interstitial; resolves when it's closed (or immediately).
  Future<void> showInterstitial();

  /// A banner for the given width, or null. (The interface exists for
  /// future placements; the game currently shows no banners.)
  Widget? banner({required double width});
}

/// Release builds until a real ad network is integrated: no ads at all.
class NoAdService implements AdService {
  const NoAdService();

  @override
  bool get rewardedAvailable => false;

  @override
  Future<bool> showRewarded(RewardPlacement placement) async => false;

  @override
  bool get interstitialAvailable => false;

  @override
  Future<void> showInterstitial() async {}

  @override
  Widget? banner({required double width}) => null;
}

/// Debug builds: pretends to play ads (short delay) and grants rewards,
/// so every ad flow can be tried and tested end to end.
class DebugAdService implements AdService {
  DebugAdService({this.delay = const Duration(milliseconds: 1500)});

  final Duration delay;
  final List<String> shown = [];

  @override
  bool get rewardedAvailable => true;

  @override
  Future<bool> showRewarded(RewardPlacement placement) async {
    shown.add('rewarded:${placement.id}');
    await Future<void>.delayed(delay);
    return true;
  }

  @override
  bool get interstitialAvailable => true;

  @override
  Future<void> showInterstitial() async {
    shown.add('interstitial');
    await Future<void>.delayed(delay);
  }

  @override
  Widget? banner({required double width}) => null;
}

/// When an interstitial may appear. Pure rules, easy to test and tune:
/// * never if ads are removed;
/// * never in a player's first [graceGames] games ever;
/// * at most once every [everyGames] finished runs,
/// * and at least [minGap] apart.
class InterstitialPolicy {
  InterstitialPolicy({
    this.everyGames = 3,
    this.minGap = const Duration(minutes: 3),
    this.graceGames = 3,
  });

  final int everyGames;
  final Duration minGap;
  final int graceGames;

  int _runsSinceLast = 0;
  DateTime? _lastShown;

  /// Call after each finished run (game over, restart, quit to home).
  /// Returns true if an interstitial should be shown now.
  bool onRunFinished({
    required bool adsRemoved,
    required int lifetimeGames,
    required DateTime now,
  }) {
    _runsSinceLast++;
    if (adsRemoved || lifetimeGames <= graceGames) return false;
    if (_runsSinceLast < everyGames) return false;
    final last = _lastShown;
    if (last != null && now.difference(last) < minGap) return false;
    _runsSinceLast = 0;
    _lastShown = now;
    return true;
  }
}

final adServiceProvider = Provider<AdService>(
  (ref) => kDebugMode ? DebugAdService() : const NoAdService(),
);

final interstitialPolicyProvider = Provider<InterstitialPolicy>(
  (ref) => InterstitialPolicy(),
);
