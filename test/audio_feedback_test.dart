import 'dart:io';

import 'package:fluffy_merge/app/app.dart';
import 'package:fluffy_merge/core/services/audio/audio_service.dart';
import 'package:fluffy_merge/core/services/feedback_service.dart';
import 'package:fluffy_merge/data/local/preferences_provider.dart';
import 'package:fluffy_merge/data/local/save_data.dart';
import 'package:fluffy_merge/features/home/home_screen.dart';
import 'package:fluffy_merge/features/settings/settings_screen.dart';
import 'package:fluffy_merge/game/fluffy_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/save_reader.dart';

void main() {
  group('FeedbackService', () {
    late SilentAudioService audio;
    late HapticsService haptics;
    late FeedbackService f;
    setUp(() {
      audio = SilentAudioService();
      haptics = HapticsService();
      f = FeedbackService(audio, haptics);
    });

    test('merge sound rises with level; chains add an arpeggio', () {
      f.merge(level: 2, combo: 1);
      f.merge(level: 5, combo: 1);
      f.merge(level: 8, combo: 1);
      f.merge(level: 11, combo: 3);
      expect(audio.played, [
        Sfx.merge1,
        Sfx.merge2,
        Sfx.merge3,
        Sfx.merge4,
        Sfx.chain,
      ]);
      expect(haptics.fired, [
        Haptic.medium,
        Haptic.medium,
        Haptic.heavy, // level 8+
        Haptic.heavy,
      ]);
    });

    test('big combos and the rainbow clear feel heavy', () {
      f.merge(level: 1, combo: 4);
      f.merge(level: 12, combo: 1, rainbow: true);
      expect(haptics.fired, [Haptic.heavy, Haptic.heavy]);
      expect(audio.played.where((s) => s == Sfx.chain), hasLength(2));
    });

    test('soft touches make no bounce sound', () {
      f
        ..bounce(0.05)
        ..bounce(0.6);
      expect(audio.played, [Sfx.bounce]);
    });

    test('settings switch sound and haptics off', () {
      f.apply(const GameSettings(sfx: false, haptics: false, music: false));
      f
        ..tap()
        ..merge(level: 3, combo: 1)
        ..reward();
      expect(audio.played, isEmpty);
      expect(haptics.fired, isEmpty);
      expect(audio.musicOn, isFalse);

      f.apply(const GameSettings(sfxVolume: 0.3, musicVolume: 0.2));
      f.tap();
      expect(audio.played, [Sfx.tap]);
      expect(haptics.fired, [Haptic.light]);
      expect(audio.sfxVolume, 0.3);
      expect(audio.musicVolume, 0.2);
    });
  });

  test('every sound file ships and is a real WAV/AAC file', () {
    for (final s in Sfx.values) {
      final f = File('assets/audio/${s.file}');
      expect(f.existsSync(), isTrue, reason: s.file);
      final bytes = f.readAsBytesSync();
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF', reason: s.file);
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(bytes.length, greaterThan(1000));
    }
    final music = File('assets/audio/music_loop.m4a');
    expect(music.existsSync(), isTrue);
    expect(music.lengthSync(), greaterThan(50000));
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/audio/'),
    );
  });

  group('In the app', () {
    late SharedPreferences prefs;
    late SilentAudioService audio;
    late HapticsService haptics;

    Future<void> advance(WidgetTester tester, [int ms = 600]) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> boot(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      audio = SilentAudioService();
      haptics = HapticsService();
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            audioServiceProvider.overrideWithValue(audio),
            hapticsServiceProvider.overrideWithValue(haptics),
          ],
          child: const FluffyMergeApp(),
        ),
      );
      await advance(tester, 2400);
    }

    testWidgets('music starts; buttons tick; drops bloop', (tester) async {
      await boot(tester);
      expect(audio.musicPlaying, isTrue);

      await tester.tap(find.bySemanticsLabel('Play'));
      await advance(tester, 1200);
      expect(audio.played, contains(Sfx.tap));
      expect(haptics.fired, contains(Haptic.light));

      final game = tester
          .widget<GameWidget<FluffyGame>>(find.byType(GameWidget<FluffyGame>))
          .game!;
      game.aimAt(5);
      game.drop();
      await advance(tester, 200);
      expect(audio.played, contains(Sfx.drop));
      expect(haptics.fired, contains(Haptic.selection));
    });

    testWidgets('settings: toggles save and apply live', (tester) async {
      await boot(tester);
      await tester.tap(find.text('Settings'));
      await advance(tester, 1000);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2));

      await tester.tap(find.text('Music'));
      await advance(tester);
      expect(readSave(prefs).settings.music, isFalse);
      expect(audio.musicPlaying, isFalse);
      expect(find.byType(Slider), findsOneWidget, reason: 'volume hidden');

      await tester.tap(find.text('Haptics'));
      await advance(tester);
      expect(readSave(prefs).settings.haptics, isFalse);
      haptics.fired.clear();
      await tester.tap(find.bySemanticsLabel('Privacy Policy'));
      await advance(tester);
      expect(haptics.fired, isEmpty, reason: 'haptics off');
      expect(find.textContaining('device only'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close'));
      await advance(tester);

      await tester.tap(find.text('Reduced Animations'));
      await advance(tester);
      expect(readSave(prefs).settings.reducedMotion, isTrue);
      expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(SettingsScreen)),
        ),
        isTrue,
      );

      await tester.tap(find.bySemanticsLabel('Back').last);
      await advance(tester, 900);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
