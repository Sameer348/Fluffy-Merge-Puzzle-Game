import 'package:fluffy_merge/app/app.dart';
import 'package:fluffy_merge/core/utils/clock.dart';
import 'package:fluffy_merge/data/local/preferences_provider.dart';
import 'package:fluffy_merge/data/local/save_data.dart';
import 'package:fluffy_merge/data/repositories/save_controller.dart';
import 'package:fluffy_merge/features/daily_challenge/daily_challenge_screen.dart';
import 'package:fluffy_merge/features/daily_challenge/daily_controller.dart';
import 'package:fluffy_merge/features/daily_challenge/model/daily_challenge.dart';
import 'package:fluffy_merge/features/daily_challenge/model/streak.dart';
import 'package:fluffy_merge/game/fluffy_game.dart';
import 'package:fluffy_merge/game/models/power_up.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/save_reader.dart';

/// First day on/after [from] whose challenge is of [kind].
DateTime _dayWith(ChallengeKind kind, [DateTime? from]) {
  var d = from ?? DateTime(2026, 11, 20, 10);
  while (DailyChallenge.forDay(d).kind != kind) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

void main() {
  group('DailyChallenge', () {
    test('same date → same challenge; neighbouring days differ', () {
      final a = DailyChallenge.forDay(DateTime(2026, 12, 3, 8));
      final b = DailyChallenge.forDay(DateTime(2026, 12, 3, 23, 59));
      expect(a.id, b.id);
      for (var i = 0; i < 60; i++) {
        final d = DateTime(2026, 1, 1).add(Duration(days: i));
        final today = DailyChallenge.forDay(d);
        final tomorrow = DailyChallenge.forDay(d.add(const Duration(days: 1)));
        expect(today.kind, isNot(tomorrow.kind), reason: '$d');
        expect(today.title, isNotEmpty);
        expect(today.target, greaterThan(0));
      }
    });

    test('all kinds and power-up rewards appear over a month', () {
      final cs = [
        for (var i = 0; i < 30; i++)
          DailyChallenge.forDay(DateTime(2026, 3, 1).add(Duration(days: i))),
      ];
      expect(cs.map((c) => c.kind).toSet(), ChallengeKind.values.toSet());
      expect(cs.map((c) => c.powerUp).toSet().length, greaterThan(1));
    });

    test('cumulative kinds add runs up; others keep the best run', () {
      final merges = DailyChallenge.forDay(_dayWith(ChallengeKind.merges));
      expect(merges.combine(10, const RunSnapshot(merges: 7)), 17);
      expect(
        merges.combine(merges.target - 1, const RunSnapshot(merges: 50)),
        merges.target,
        reason: 'clamped to the target',
      );
      final score = DailyChallenge.forDay(_dayWith(ChallengeKind.score));
      expect(score.combine(900, const RunSnapshot(score: 400)), 900);
      expect(score.combine(900, const RunSnapshot(score: 1200)), 1200);
    });
  });

  group('Streak', () {
    final d1 = DateTime(2026, 11, 1, 9);
    DateTime day(int n) => d1.add(Duration(days: n));

    test('first claim is Day 1; same day can\'t claim twice', () {
      var s = const StreakData();
      expect(Streak.status(s, d1).dayToClaim, 1);
      s = Streak.claim(s, d1);
      expect(Streak.status(s, d1).claimedToday, isTrue);
      expect(identical(Streak.claim(s, d1), s), isTrue);
    });

    test('consecutive days climb to the Day 7 gift, then restart', () {
      var s = const StreakData();
      for (var i = 0; i < 7; i++) {
        final st = Streak.status(s, day(i));
        expect(st.dayToClaim, i + 1);
        expect(st.daysDone, i);
        s = Streak.claim(s, day(i));
      }
      expect(Streak.rewards[6].isGift, isTrue);
      expect(Streak.status(s, day(6)).daysDone, 7);
      final next = Streak.status(s, day(7));
      expect(next.dayToClaim, 1);
      expect(next.daysDone, 0);
    });

    test('missing a day starts over at Day 1', () {
      var s = Streak.claim(const StreakData(), day(0));
      s = Streak.claim(s, day(1));
      expect(Streak.status(s, day(3)).dayToClaim, 1);
      s = Streak.claim(s, day(3));
      expect(s.count, 1);
    });
  });

  group('DailyController', () {
    late DateTime now;

    Future<ProviderContainer> container() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('progress is idempotent per run; completes; claims once', () async {
      now = _dayWith(ChallengeKind.merges);
      final c = await container();
      final daily = c.read(dailyControllerProvider);
      final ch = daily.today();

      // Run 1: 10 merges, applied twice (background + end) → still 10.
      expect(daily.applyRun(ch, 0, const RunSnapshot(merges: 10)), isFalse);
      daily.applyRun(ch, 0, const RunSnapshot(merges: 10));
      expect(daily.progressFor(ch).progress, 10);

      // Live checks don't write partial progress.
      daily.applyRun(
        ch,
        10,
        const RunSnapshot(merges: 3),
        persistProgress: false,
      );
      expect(daily.progressFor(ch).progress, 10);

      // Run 2 finishes it.
      expect(daily.applyRun(ch, 10, RunSnapshot(merges: ch.target)), isTrue);
      expect(c.read(dailyViewProvider).completed, isTrue);
      expect(c.read(dailyViewProvider).hasReward, isTrue);

      final coinsBefore = c.read(saveProvider).coins;
      final puBefore = c.read(saveProvider).powerUpCount(ch.powerUp);
      expect(daily.claimChallenge(), isTrue);
      expect(daily.claimChallenge(), isFalse);
      expect(c.read(saveProvider).coins, coinsBefore + ch.coins);
      expect(c.read(saveProvider).powerUpCount(ch.powerUp), puBefore + 1);
    });

    test('a new day brings a fresh challenge with zero progress', () async {
      now = _dayWith(ChallengeKind.score);
      final c = await container();
      final daily = c.read(dailyControllerProvider);
      final ch = daily.today();
      daily.applyRun(ch, 0, const RunSnapshot(score: 1000));
      expect(daily.progressFor(ch).progress, 1000);

      now = now.add(const Duration(days: 1));
      final v = c.read(dailyControllerProvider).view();
      expect(v.challenge.id, isNot(ch.id));
      expect(v.progress, 0);
      expect(v.completed, isFalse);
    });

    test('streak claim pays the day\'s reward, gift on Day 7', () async {
      now = DateTime(2026, 11, 1, 12);
      final c = await container();
      final daily = c.read(dailyControllerProvider);
      var coins = c.read(saveProvider).coins;
      for (var i = 0; i < 7; i++) {
        final r = daily.claimStreak()!;
        expect(daily.claimStreak(), isNull, reason: 'once a day');
        coins += r.coins;
        expect(c.read(saveProvider).coins, coins);
        now = now.add(const Duration(days: 1));
      }
      expect(c.read(saveProvider).powerUpCount(PowerUp.grow), 4);
      expect(c.read(saveProvider).powerUpCount(PowerUp.pop), 4);
    });
  });

  group('Screens', () {
    late SharedPreferences prefs;

    Future<void> advance(WidgetTester tester, [int ms = 600]) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> boot(WidgetTester tester, DateTime now) async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clockProvider.overrideWithValue(() => now),
          ],
          child: const FluffyMergeApp(),
        ),
      );
      await advance(tester, 2400);
    }

    testWidgets('home badge → daily screen → claim streak → badge gone', (
      tester,
    ) async {
      final now = DateTime(2026, 11, 20, 18);
      await boot(tester, now);
      expect(find.bySemanticsLabel('Daily, reward waiting'), findsOneWidget);

      await tester.tap(find.text('Daily'));
      await advance(tester, 900);
      expect(find.byType(DailyChallengeScreen), findsOneWidget);
      final ch = DailyChallenge.forDay(now);
      expect(find.text(ch.title), findsOneWidget);
      expect(find.text('Time left: 6h 0m'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Progress 0 / ${_fmt(ch.target)}'),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel('Claim Day 1'));
      await advance(tester, 600);
      expect(find.textContaining('Claimed 50 coins'), findsOneWidget);
      expect(find.text('Day 1 claimed. See you tomorrow!'), findsOneWidget);
      expect(readSave(prefs).coins, 50);

      await tester.tap(find.bySemanticsLabel('Back'));
      await advance(tester, 900);
      expect(find.bySemanticsLabel('Daily, reward waiting'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('finishing the challenge in a run: popup, then Claim!', (
      tester,
    ) async {
      final now = _dayWith(ChallengeKind.score, DateTime(2026, 11, 20, 12));
      final ch = DailyChallenge.forDay(now);
      await boot(tester, now);
      await tester.tap(find.bySemanticsLabel('Play'));
      await advance(tester, 1200);
      final game = tester
          .widget<GameWidget<FluffyGame>>(find.byType(GameWidget<FluffyGame>))
          .game!;
      game.scoring.score.value = ch.target + 10;
      game.aimAt(5);
      game.drop(); // a drop triggers the live check
      await advance(tester, 300);
      expect(readSave(prefs).daily.completed, isTrue);

      await tester.tap(find.bySemanticsLabel('Pause'));
      await advance(tester);
      await tester.tap(find.bySemanticsLabel('Home'));
      await advance(tester, 900);
      await tester.tap(find.text('Daily'));
      await advance(tester, 900);
      await tester.tap(find.bySemanticsLabel('Claim!'));
      await advance(tester, 600);
      expect(readSave(prefs).daily.claimed, isTrue);
      expect(find.bySemanticsLabel('Claimed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

String _fmt(int n) {
  final s = '$n';
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
