import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ads behind an interface, so Google Mobile Ads / AppLovin / etc. can be
/// plugged in later (Phase 16) without touching screens.
///
/// Monetization rules this app follows: rewarded ads are always optional
/// (2× reward, extra power-up, continue), and interstitials are only shown
/// between runs at reasonable intervals — never mid-game.
abstract interface class AdService {
  /// Whether a rewarded ad can be shown right now. Screens hide reward
  /// buttons when this is false rather than showing a dead button.
  bool get rewardedAvailable;

  /// Shows a rewarded ad. Resolves true only if the player earned the
  /// reward (watched to the end).
  Future<bool> showRewarded({required String placement});
}

/// Release builds until a real provider is integrated: no ads at all.
class NoAdService implements AdService {
  const NoAdService();

  @override
  bool get rewardedAvailable => false;

  @override
  Future<bool> showRewarded({required String placement}) async => false;
}

/// Debug builds: pretends to play an ad (short delay) and grants the
/// reward, so reward flows can be tried and tested end to end.
class DebugAdService implements AdService {
  DebugAdService({this.delay = const Duration(milliseconds: 1500)});

  final Duration delay;
  final List<String> shown = [];

  @override
  bool get rewardedAvailable => true;

  @override
  Future<bool> showRewarded({required String placement}) async {
    shown.add(placement);
    await Future<void>.delayed(delay);
    return true;
  }
}

final adServiceProvider = Provider<AdService>(
  (ref) => kDebugMode ? DebugAdService() : const NoAdService(),
);
