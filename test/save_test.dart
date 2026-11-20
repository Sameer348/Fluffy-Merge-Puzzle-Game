import 'dart:convert';

import 'package:fluffy_merge/app/app.dart';
import 'package:fluffy_merge/data/local/preferences_provider.dart';
import 'package:fluffy_merge/data/local/save_data.dart';
import 'package:fluffy_merge/data/local/save_keys.dart';
import 'package:fluffy_merge/data/local/save_store.dart';
import 'package:fluffy_merge/data/repositories/save_controller.dart';
import 'package:fluffy_merge/features/home/home_screen.dart';
import 'package:fluffy_merge/game/fluffy_game.dart';
import 'package:fluffy_merge/game/models/power_up.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/save_reader.dart';

Future<SharedPreferences> _prefs([Map<String, Object> v = const {}]) async {
  SharedPreferences.setMockInitialValues(v);
  return SharedPreferences.getInstance();
}

void main() {
  group('SaveData', () {
    test('round-trips through JSON', () {
      final d = SaveData.fresh().copyWith(
        bestScore: 12345,
        coins: 77,
        unlockedLevels: {1, 2, 5},
        tutorialCompleted: true,
        achievements: {'first_merge'},
        settings: const GameSettings(music: false, sfxVolume: 0.3),
        stats: const LifetimeStats(gamesPlayed: 4, bestCombo: 6),
        daily: const DailyProgress(date: '2026-11-20', progress: 3),
        streak: const StreakData(count: 2, lastClaimDate: '2026-11-19'),
      );
      final back = SaveData.fromJson(
        jsonDecode(jsonEncode(d.toJson())) as Map<String, Object?>,
      );
      expect(back.toJson(), d.toJson());
      expect(d.toJson()['version'], SaveData.schemaVersion);
    });

    test('damaged or hand-edited values fall back to safe defaults', () {
      final d = SaveData.fromJson({
        'bestScore': -50,
        'coins': 'lots',
        'powerUps': {'pop': 9999, 'grow': 2.6, 'sweep': null},
        'unlockedLevels': [1, 99, 'x', 4, -2],
        'settings': {'music': 'yes', 'sfxVolume': 7.5},
        'achievements': [1, 'ok'],
        'stats': 'nope',
      });
      expect(d.bestScore, 0);
      expect(d.coins, 0);
      expect(d.powerUpCount(PowerUp.pop), SaveData.maxPowerUps);
      expect(d.powerUpCount(PowerUp.grow), 3);
      expect(d.powerUpCount(PowerUp.sweep), SaveData.starterPowerUps);
      expect(d.unlockedLevels, {1, 4});
      expect(d.settings.music, isTrue);
      expect(d.settings.sfxVolume, 1.0);
      expect(d.achievements, {'ok'});
      expect(d.stats.gamesPlayed, 0);
    });
  });

  group('SaveStore', () {
    test('first launch: fresh save with starter power-ups, written', () async {
      final prefs = await _prefs();
      final store = SaveStore(prefs);
      final d = store.load();
      await store.flush();
      expect(store.lastSource, SaveSource.fresh);
      expect(d.powerUpCount(PowerUp.shake), SaveData.starterPowerUps);
      expect(readSave(prefs).toJson(), d.toJson());
    });

    test('migrates pre-v1 keys once, then removes them', () async {
      final prefs = await _prefs({
        SaveKeys.bestScore: 500,
        SaveKeys.coins: 40,
        SaveKeys.powerUp(PowerUp.pop): 1,
      });
      final store = SaveStore(prefs);
      final d = store.load();
      await store.flush();
      expect(store.lastSource, SaveSource.legacy);
      expect(d.bestScore, 500);
      expect(d.coins, 40);
      expect(d.powerUpCount(PowerUp.pop), 1);
      expect(d.powerUpCount(PowerUp.grow), SaveData.starterPowerUps);
      expect(prefs.getInt(SaveKeys.coins), isNull);
      expect(prefs.getInt(SaveKeys.powerUp(PowerUp.pop)), isNull);

      final again = SaveStore(prefs);
      expect(again.load().coins, 40);
      expect(again.lastSource, SaveSource.primary);
    });

    test('corrupt save: restored from backup, corrupt text kept', () async {
      final good = jsonEncode(SaveData.fresh().copyWith(coins: 123).toJson());
      final prefs = await _prefs({
        SaveStore.primaryKey: '{"coins": 12',
        SaveStore.backupKey: good,
      });
      final store = SaveStore(prefs);
      final d = store.load();
      await store.flush();
      expect(store.lastSource, SaveSource.backup);
      expect(d.coins, 123);
      expect(prefs.getString(SaveStore.corruptKey), '{"coins": 12');
      expect(readSave(prefs).coins, 123, reason: 'primary repaired');
    });

    test(
      'corrupt save and no backup: starts fresh instead of crashing',
      () async {
        final prefs = await _prefs({SaveStore.primaryKey: 'not json'});
        final store = SaveStore(prefs);
        expect(store.load().coins, 0);
        expect(store.lastSource, SaveSource.fresh);
      },
    );

    test('fields from a newer app version survive a save', () async {
      final prefs = await _prefs({
        SaveStore.primaryKey: jsonEncode({
          'version': SaveData.schemaVersion + 3,
          'coins': 9,
          'pets': ['dragon'],
        }),
      });
      final store = SaveStore(prefs);
      final d = store.load();
      expect(d.coins, 9);
      store.save(d.copyWith(coins: 10));
      await store.flush();
      final raw = jsonDecode(prefs.getString(SaveStore.primaryKey)!) as Map;
      expect(raw['pets'], ['dragon']);
      expect(raw['coins'], 10);
    });
  });

  group('SaveController', () {
    Future<ProviderContainer> container([
      Map<String, Object> v = const {},
    ]) async {
      final prefs = await _prefs(v);
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('banking a run twice never double-counts', () async {
      final c = await container();
      final save = c.read(saveProvider.notifier);
      // App backgrounded mid-run: 300 points, 5 coins so far.
      save.bankRun(score: 300, coinsDelta: 5);
      // Run ends: 900 points, 8 coins total → only 3 more coins.
      save.bankRun(score: 900, coinsDelta: 3);
      expect(c.read(saveProvider).bestScore, 900);
      expect(c.read(saveProvider).coins, 8);
      // A worse run never lowers the best.
      save.bankRun(score: 100, coinsDelta: 0);
      expect(c.read(saveProvider).bestScore, 900);
    });

    test('unlocks, settings, tutorial, stats, coins', () async {
      final c = await container();
      final save = c.read(saveProvider.notifier);
      expect(save.unlockLevel(5), isTrue);
      expect(save.unlockLevel(5), isFalse);
      expect(save.unlockLevel(13), isFalse);
      save
        ..updateSettings((s) => s.copyWith(haptics: false))
        ..completeTutorial()
        ..finishRun(
          const RunStats(
            merges: 10,
            drops: 20,
            coinsEarned: 4,
            bestCombo: 3,
            highestLevel: 7,
          ),
        )
        ..addCoins(50);
      expect(save.spendCoins(80), isFalse);
      expect(save.spendCoins(30), isTrue);
      final d = c.read(saveProvider);
      expect(d.unlockedLevels, {5});
      expect(d.settings.haptics, isFalse);
      expect(d.tutorialCompleted, isTrue);
      expect(d.stats.gamesPlayed, 1);
      expect(d.stats.highestLevel, 7);
      expect(d.coins, 20);
      await save.flush();
      expect(readSave(c.read(sharedPreferencesProvider)).toJson(), d.toJson());
    });
  });

  group('In the app', () {
    Future<void> advance(WidgetTester tester, [int ms = 600]) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<SharedPreferences> boot(
      WidgetTester tester, [
      Map<String, Object> v = const {},
    ]) async {
      final prefs = await _prefs(v);
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
      return prefs;
    }

    testWidgets('backgrounding mid-run banks progress; leaving adds no extra', (
      tester,
    ) async {
      final prefs = await boot(tester);
      await tester.tap(find.bySemanticsLabel('Play'));
      await advance(tester, 1200);
      final game = tester
          .widget<GameWidget<FluffyGame>>(find.byType(GameWidget<FluffyGame>))
          .game!;
      game.scoring.score.value = 2500;
      game.scoring.coins.value = 4;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await advance(tester, 400);
      expect(readSave(prefs).bestScore, 2500, reason: 'banked on background');
      expect(readSave(prefs).coins, 4);
      expect(find.text('Paused'), findsWidgets);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      game.scoring.coins.value = 6; // two more before leaving
      await tester.tap(find.bySemanticsLabel('Home'));
      await advance(tester, 1200);
      expect(find.byType(HomeScreen), findsOneWidget);
      final saved = readSave(prefs);
      expect(saved.coins, 6, reason: 'only the 2 new coins added');
      expect(saved.stats.gamesPlayed, 1);
    });

    testWidgets('dropping creatures unlocks them in the collection', (
      tester,
    ) async {
      final prefs = await boot(tester);
      await tester.tap(find.bySemanticsLabel('Play'));
      await advance(tester, 1200);
      final game = tester
          .widget<GameWidget<FluffyGame>>(find.byType(GameWidget<FluffyGame>))
          .game!;
      game.aimAt(5);
      expect(game.drop(), isTrue);
      await advance(tester, 600);
      expect(readSave(prefs).unlockedLevels, contains(1));
    });

    testWidgets('in-app reduced motion turns animations off app-wide', (
      tester,
    ) async {
      final saved = SaveData.fresh().copyWith(
        settings: const GameSettings(reducedMotion: true),
      );
      await boot(tester, {SaveStore.primaryKey: jsonEncode(saved.toJson())});
      final ctx = tester.element(find.byType(HomeScreen));
      expect(MediaQuery.disableAnimationsOf(ctx), isTrue);
    });
  });
}
