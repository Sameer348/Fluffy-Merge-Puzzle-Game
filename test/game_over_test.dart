import 'package:fluffy_merge/app/app.dart';
import 'package:fluffy_merge/data/local/preferences_provider.dart';
import 'package:fluffy_merge/data/local/save_keys.dart';
import 'package:fluffy_merge/features/game_over/results_screen.dart';
import 'package:fluffy_merge/features/gameplay/gameplay_screen.dart';
import 'package:fluffy_merge/features/home/home_screen.dart';
import 'package:fluffy_merge/game/fluffy_game.dart';
import 'package:fluffy_merge/game/models/run_result.dart';
import 'package:fluffy_merge/game/systems/overflow_timer.dart';
import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/save_reader.dart';

/// Fills the jar past the danger line. Merges are disabled (claims are
/// released, so the creatures still count as settled), and Lv. 6 puffs are
/// stacked in a non-overlapping grid that reaches above the jar.
void _overfill(FluffyGame game) {
  game.onMergeDetected = (pair) {
    pair.a.claimedForMerge = false;
    pair.b.claimedForMerge = false;
  };
  for (var row = 0; row < 9; row++) {
    for (var col = 0; col < 4; col++) {
      game.spawnCreature(6, Vector2(1.3 + col * 2.45, 12.8 - row * 2.3));
    }
  }
}

Future<void> _untilFound(WidgetTester tester, Finder f) async {
  for (var i = 0; i < 200 && f.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(f, findsWidgets);
}

void main() {
  group('OverflowTimer', () {
    test('fires once after the limit of continuous overflow', () {
      final t = OverflowTimer(limit: 2);
      var fired = 0;
      for (var i = 0; i < 119; i++) {
        if (t.update(1 / 60, overLine: true)) fired++;
      }
      expect(fired, 0, reason: 'just under 2 s');
      expect(t.secondsLeft, 1);
      expect(t.isWarning, isTrue);
      for (var i = 0; i < 10; i++) {
        if (t.update(1 / 60, overLine: true)) fired++;
      }
      expect(fired, 1);
      expect(t.hasFired, isTrue);
      expect(t.update(1, overLine: true), isFalse, reason: 'only once');
    });

    test('a short bounce over the line drains away', () {
      final t = OverflowTimer(limit: 2, recoverRate: 2);
      t.update(0.8, overLine: true);
      expect(t.progress, closeTo(0.4, 1e-9));
      t.update(0.3, overLine: false);
      expect(t.progress, closeTo(0.1, 1e-9));
      t.update(1, overLine: false);
      expect(t.progress, 0);
      expect(t.isWarning, isFalse);
    });
  });

  group('Game over in the jar', () {
    testWithGame<FluffyGame>(
      'overfilled jar: countdown, slow-mo, one game-over call',
      () => FluffyGame(seed: 4),
      (game) async {
        try {
          await game.ready();
          var calls = 0;
          game.addGameOverListener(() => calls++);
          _overfill(game);
          await game.ready();

          var sawCountdown = false;
          var overAt = -1.0;
          for (var t = 0.0; t < 12 && calls == 0; t += 1 / 60) {
            game.update(1 / 60);
            await game.ready();
            if (game.overflowCountdown.value != null) sawCountdown = true;
            if (game.isGameOver && overAt < 0) overAt = t;
          }
          expect(sawCountdown, isTrue);
          expect(game.isGameOver, isTrue);
          expect(calls, 1);
          expect(game.inputLocked, isTrue);
          expect(game.drop(), isFalse);
          // Nothing more after it fired.
          for (var i = 0; i < 120; i++) {
            game.update(1 / 60);
          }
          expect(calls, 1);
        } finally {
          game.disposeSession();
        }
      },
    );
  });

  group('Screens', () {
    late SharedPreferences prefs;

    Future<void> advance(WidgetTester tester, [int ms = 600]) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> boot(
      WidgetTester tester, {
      Map<String, Object> saved = const {},
    }) async {
      SharedPreferences.setMockInitialValues(saved);
      prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const FluffyMergeApp(),
        ),
      );
      await advance(tester, 2400);
    }

    Future<FluffyGame> play(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Play'));
      await advance(tester, 1200);
      return tester
          .widget<GameWidget<FluffyGame>>(find.byType(GameWidget<FluffyGame>))
          .game!;
    }

    testWidgets('overflow → So Fluffy! results, saved → Home', (tester) async {
      await boot(tester, saved: {SaveKeys.coins: 10});
      final game = await play(tester);
      game.scoring.score.value = 4321;
      game.scoring.coins.value = 6;
      _overfill(game); // no game.ready(): widget tests load by pumping
      await _untilFound(tester, find.text('Keep going?'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50)); // entrance
      }
      await tester.tap(find.bySemanticsLabel('No thanks'));
      await _untilFound(tester, find.byType(ResultsScreen));
      await advance(tester, 1500);

      expect(find.byType(ResultsScreen), findsOneWidget);
      expect(find.byType(GameplayScreen), findsNothing);
      expect(find.bySemanticsLabel('Score 4321'), findsOneWidget);
      expect(find.bySemanticsLabel('Best score 4321'), findsOneWidget);
      expect(find.text('NEW BEST!'), findsOneWidget);
      expect(find.bySemanticsLabel('Coins earned 6'), findsOneWidget);
      expect(readSave(prefs).bestScore, 4321);
      expect(readSave(prefs).coins, 16);

      await tester.tap(find.bySemanticsLabel('Home'));
      await advance(tester, 1200);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('4,321'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('results: 2X reward pays once; Retry starts a new run', (
      tester,
    ) async {
      await boot(tester, saved: {SaveKeys.coins: 50});
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pushNamed(
        '/results',
        arguments: const RunResult(
          score: 900,
          bestScore: 1200,
          isNewBest: false,
          highestLevel: 7,
          coinsEarned: 8,
          merges: 20,
          drops: 30,
          bestCombo: 3,
          seconds: 95,
        ),
      );
      await advance(tester, 1600);
      expect(find.text('NEW BEST!'), findsNothing);
      expect(
        find.bySemanticsLabel('Highest creature: Peach Puff, level 7'),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel('Watch Ad for 2X Reward'));
      await advance(tester, 2200); // debug "ad" takes 1.5 s
      expect(find.bySemanticsLabel('Coins earned 16'), findsOneWidget);
      expect(readSave(prefs).coins, 58);
      // Button is spent.
      await tester.tap(find.bySemanticsLabel('Reward doubled!'));
      await advance(tester, 2000);
      expect(readSave(prefs).coins, 58);

      await tester.tap(find.bySemanticsLabel('Retry'));
      await advance(tester, 1200);
      expect(find.byType(GameplayScreen), findsOneWidget);
    });

    testWidgets('pause: button and system back open the menu', (tester) async {
      await boot(tester);
      final game = await play(tester);

      await tester.tap(find.bySemanticsLabel('Pause'));
      await advance(tester);
      expect(find.text('Paused'), findsWidgets);
      expect(game.paused, isTrue);
      await tester.tap(find.bySemanticsLabel('Resume'));
      await advance(tester);
      expect(find.text('Paused'), findsNothing);
      expect(game.paused, isFalse);

      // Android back gesture: pause menu, not leaving the run.
      await tester.binding.handlePopRoute();
      await advance(tester);
      expect(find.byType(GameplayScreen), findsOneWidget);
      expect(find.text('Paused'), findsWidgets);

      await tester.tap(find.bySemanticsLabel('Restart'));
      await advance(tester, 1200);
      expect(find.byType(GameplayScreen), findsOneWidget);
      final fresh = tester
          .widget<GameWidget<FluffyGame>>(find.byType(GameWidget<FluffyGame>))
          .game!;
      expect(identical(fresh, game), isFalse, reason: 'a brand-new run');
      expect(tester.takeException(), isNull);
    });
  });
}
