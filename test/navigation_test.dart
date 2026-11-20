import 'package:fluffy_merge/app/app.dart';
import 'package:fluffy_merge/core/constants/game_constants.dart';
import 'package:fluffy_merge/game/fluffy_game.dart';
import 'package:flame/game.dart';
import 'package:fluffy_merge/data/local/preferences_provider.dart';
import 'package:fluffy_merge/data/local/save_keys.dart';
import 'package:fluffy_merge/features/gameplay/gameplay_screen.dart';
import 'package:fluffy_merge/features/home/home_screen.dart';
import 'package:fluffy_merge/features/home/widgets/home_mascot.dart';
import 'package:fluffy_merge/widgets/buttons/tile_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _boot(
  WidgetTester tester,
  Size logical, {
  Map<String, Object> saved = const {},
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = logical * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const FluffyMergeApp(),
    ),
  );
}

/// Pumps a fixed time span (the home screen animates forever, so
/// pumpAndSettle would never return).
Future<void> _advance(WidgetTester tester, [int ms = 1200]) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('animated: splash → home → game → back', (tester) async {
    await _boot(
      tester,
      const Size(393, 852),
      saved: {SaveKeys.bestScore: 12345, SaveKeys.coins: 250},
    );
    await _advance(tester, 2400);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(HomeMascot), findsOneWidget);
    expect(find.text('12,345'), findsOneWidget);
    expect(find.text('250'), findsOneWidget);

    // Poke the mascot (squish reaction) – must not throw.
    await tester.tap(find.byType(HomeMascot));
    await _advance(tester, 400);

    await tester.tap(find.bySemanticsLabel('Play'));
    await _advance(tester);
    expect(find.byType(GameplayScreen), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);

    // Drag across the jar and release: a creature drops into the game.
    final jar = find.bySemanticsLabel('Jar. Drag to aim, release to drop.');
    final center = tester.getCenter(jar);
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await _advance(tester, 1500);
    final game = tester
        .widget<GameWidget<FluffyGame>>(find.byType(GameWidget<FluffyGame>))
        .game!;
    expect(game.drops.value, 1);
    expect(game.creatures.single.isFalling, isFalse);
    // Dropped left of center, where the finger was released.
    expect(game.creatures.single.x, lessThan(GameConstants.worldWidth / 2));

    // Score and coins from this run reach the HUD...
    game.scoring.score.value = 54321;
    game.scoring.coins.value = 7;
    await _advance(tester, 600);
    expect(find.text('54,321'), findsOneWidget);
    expect(find.text('257'), findsOneWidget); // wallet 250 + 7

    // ...and are saved the moment you leave, so Home shows them at once.
    await tester.tap(find.bySemanticsLabel('Pause'));
    await _advance(tester);
    await tester.tap(find.bySemanticsLabel('Home'));
    await _advance(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('54,321'), findsOneWidget, reason: 'new best');
    expect(find.text('257'), findsOneWidget, reason: 'wallet');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion: everything settles and every menu route opens', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _boot(tester, const Size(393, 852));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    for (final (label, title) in const [
      ('Daily', 'Daily Challenge'),
      ('Collection', 'Collection'),
      ('Shop', 'Shop'),
      ('Settings', 'Settings'),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(title), findsWidgets, reason: label);
      // The top-left arrow (Settings also has a Back button at the bottom).
      await tester.tap(find.bySemanticsLabel('Back').first);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    }
  });

  testWidgets('home tiles share the row evenly (with or without a badge)', (
    tester,
  ) async {
    await _boot(tester, const Size(393, 852));
    await _advance(tester, 2400);
    final widths = tester
        .widgetList<TileButton>(find.byType(TileButton))
        .map((w) => tester.getSize(find.byWidget(w)).width)
        .toList();
    expect(widths, hasLength(4));
    for (final w in widths) {
      expect(w, closeTo(widths.first, 0.5));
    }
    expect(widths.first, greaterThan(70));
  });

  testWidgets('HUD fits a 7-digit score and big wallet on a 360×640 phone', (
    tester,
  ) async {
    await _boot(tester, const Size(360, 640), saved: {SaveKeys.coins: 98765});
    await _advance(tester, 2400);
    await tester.tap(find.bySemanticsLabel('Play'));
    await _advance(tester);
    final game = tester
        .widget<GameWidget<FluffyGame>>(find.byType(GameWidget<FluffyGame>))
        .game!;
    game.scoring.score.value = 9876543;
    game.scoring.coins.value = 1234;
    await _advance(tester, 800);
    expect(tester.takeException(), isNull);
    expect(find.text('9,876,543'), findsOneWidget);
    expect(find.text('99,999'), findsOneWidget);
  });

  for (final (name, size) in const [
    ('small Android 360x640', Size(360, 640)),
    ('iPhone SE 375x667', Size(375, 667)),
    ('Pro Max 430x932', Size(430, 932)),
    ('iPad 820x1180', Size(820, 1180)),
  ]) {
    testWidgets('home layout has no overflow on $name', (tester) async {
      await _boot(tester, size);
      await _advance(tester, 2400);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
