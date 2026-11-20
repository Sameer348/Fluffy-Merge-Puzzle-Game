import 'package:flutter/material.dart';

import '../core/constants/app_sizes.dart';
import '../features/achievements/achievements_screen.dart';
import '../features/collection/collection_screen.dart';
import '../features/daily_challenge/daily_challenge_screen.dart';
import '../features/game_over/results_screen.dart';
import '../features/gameplay/gameplay_screen.dart';
import '../features/home/home_screen.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shop/shop_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/tutorial/tutorial_screen.dart';
import '../game/models/run_result.dart';

/// Route names. Plain Navigator 2-free routing keeps dependencies minimal;
/// every screen is reachable by name.
abstract final class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const game = '/game';
  static const tutorial = '/tutorial';
  static const daily = '/daily';
  static const collection = '/collection';
  static const shop = '/shop';
  static const settings = '/settings';
  static const leaderboard = '/leaderboard';
  static const achievements = '/achievements';

  /// Needs a [RunResult] as the route argument.
  static const results = '/results';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      splash => const SplashScreen(),
      home => const HomeScreen(),
      game => const GameplayScreen(),
      tutorial => const TutorialScreen(),
      daily => const DailyChallengeScreen(),
      collection => const CollectionScreen(),
      shop => const ShopScreen(),
      AppRoutes.settings => const SettingsScreen(),
      leaderboard => const LeaderboardScreen(),
      achievements => const AchievementsScreen(),
      results when settings.arguments is RunResult => ResultsScreen(
        result: settings.arguments! as RunResult,
      ),
      _ => const HomeScreen(),
    };
    return _SoftPageRoute(page: page, settings: settings);
  }
}

/// Gentle fade + slight scale-up transition (0.96 → 1.0), matching the
/// app's soft, toy-like motion language.
class _SoftPageRoute<T> extends PageRouteBuilder<T> {
  _SoftPageRoute({required Widget page, super.settings})
    : super(
        transitionDuration: AppDurations.page,
        reverseTransitionDuration: AppDurations.normal,
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: AppCurves.soft,
          );
          final reduceMotion = MediaQuery.disableAnimationsOf(context);
          if (reduceMotion) {
            return FadeTransition(opacity: curved, child: child);
          }
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
}
