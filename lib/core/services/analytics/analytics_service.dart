import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_service.dart' show runningInTest;

/// Every event the game reports. Names follow the common snake_case
/// convention (Firebase, Amplitude, etc. all accept them as-is).
enum AnalyticsEvent {
  gameStarted('game_started'),
  gameOver('game_over'),
  mergeCreated('merge_created'),
  comboCreated('combo_created'),
  powerUpUsed('powerup_used'),
  dailyChallengeStarted('daily_challenge_started'),
  dailyChallengeCompleted('daily_challenge_completed'),
  rewardedAdWatched('rewarded_ad_watched'),
  purchaseStarted('purchase_started'),
  purchaseCompleted('purchase_completed');

  const AnalyticsEvent(this.name);
  final String name;
}

/// Analytics behind an interface so no provider is hard-coded. A Firebase
/// or Amplitude adapter only has to implement [log].
abstract interface class AnalyticsService {
  void log(AnalyticsEvent event, [Map<String, Object> params = const {}]);
}

/// Release builds until a provider is chosen: nothing is collected (keeps
/// the Settings → Privacy statement true).
class NoAnalytics implements AnalyticsService {
  const NoAnalytics();

  @override
  void log(AnalyticsEvent event, [Map<String, Object> params = const {}]) {}
}

/// Debug builds and tests: keeps events in memory (and prints the rare,
/// interesting ones) so they can be inspected and asserted on.
class DebugAnalytics implements AnalyticsService {
  DebugAnalytics({this.verbose = false});

  final bool verbose;
  final List<(AnalyticsEvent, Map<String, Object>)> events = [];

  @override
  void log(AnalyticsEvent event, [Map<String, Object> params = const {}]) {
    events.add((event, params));
    if (events.length > 500) events.removeAt(0);
    final chatty = event == AnalyticsEvent.mergeCreated;
    if (verbose || (!chatty && kDebugMode && !runningInTest)) {
      debugPrint('analytics: ${event.name} $params');
    }
  }

  List<Map<String, Object>> of(AnalyticsEvent e) => [
    for (final (ev, p) in events)
      if (ev == e) p,
  ];
}

final analyticsProvider = Provider<AnalyticsService>(
  (ref) => kReleaseMode ? const NoAnalytics() : DebugAnalytics(),
);
