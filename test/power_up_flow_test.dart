import 'package:fluffy_merge/app/app.dart';
import 'package:fluffy_merge/core/constants/game_constants.dart';
import 'package:fluffy_merge/data/local/preferences_provider.dart';
import 'package:fluffy_merge/data/local/save_keys.dart';
import 'package:fluffy_merge/features/gameplay/widgets/pick_banner.dart';
import 'package:fluffy_merge/game/fluffy_game.dart';
import 'package:fluffy_merge/game/models/creature_spec.dart';
import 'package:fluffy_merge/game/models/power_up.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real screen, real taps: the power-up UI flow end to end.
void main() {
  late SharedPreferences prefs;

  Future<void> advance(WidgetTester tester, [int ms = 600]) async {
    for (var t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<FluffyGame> openGame(
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
    await tester.tap(find.bySemanticsLabel('Play'));
    await advance(tester, 1200);
    return tester
        .widget<GameWidget<FluffyGame>>(find.byType(GameWidget<FluffyGame>))
        .game!;
  }

  Offset screenPos(WidgetTester tester, FluffyGame game, Vector2 world) {
    final origin = tester.getTopLeft(find.byType(GameWidget<FluffyGame>));
    final px = game.worldToScreen(world);
    return origin + Offset(px.x, px.y);
  }

  testWidgets('POP: pick a puff → confirm → it is gone and one POP spent', (
    tester,
  ) async {
    final game = await openGame(tester);
    final r = CreatureCatalog.byLevel(4).radius * 0.95;
    final target = game.spawnCreature(
      4,
      Vector2(7, GameConstants.worldHeight - r),
    );
    await advance(tester, 800);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Pop, 3 left')));
    await advance(tester, 300);
    expect(find.byType(PickBanner), findsOneWidget);
    expect(target.highlighted, isTrue);

    // Tapping empty space keeps pick mode (and doesn't drop).
    final drops = game.drops.value;
    await tester.tapAt(screenPos(tester, game, Vector2(2, 6)));
    await advance(tester, 300);
    expect(find.byType(PickBanner), findsOneWidget);
    expect(game.drops.value, drops);

    await tester.tapAt(screenPos(tester, game, target.body.position));
    await advance(tester, 500);
    expect(find.text('Pop this Mint Puff?'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Pop!'));
    await advance(tester, 800);

    expect(game.creatures.where((c) => c.id == target.id), isEmpty);
    expect(prefs.getInt(SaveKeys.powerUp(PowerUp.pop)), 2);
    expect(find.byType(PickBanner), findsNothing);
    expect(game.inputLocked, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SWEEP: cancel spends nothing and removes nothing', (
    tester,
  ) async {
    final game = await openGame(tester);
    await advance(tester, 1500); // first Tiny Puff is in the dropper only
    game.spawnCreature(1, Vector2(3, GameConstants.worldHeight - 0.4));
    await advance(tester, 500);
    final before = game.creatures.length;

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Sweep, 3 left')));
    await advance(tester, 500);
    expect(find.textContaining('Sweep away 1 small puff'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Cancel'));
    await advance(tester, 500);

    expect(game.creatures.length, before);
    expect(prefs.getInt(SaveKeys.powerUp(PowerUp.sweep)), isNull);
  });

  testWidgets('empty power-up explains how to earn more', (tester) async {
    await openGame(tester, saved: {SaveKeys.powerUp(PowerUp.grow): 0});
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Grow, 0 left')));
    await advance(tester, 400);
    expect(find.textContaining('No Grows left'), findsOneWidget);
    expect(find.byType(PickBanner), findsNothing);
  });

  testWidgets('SHAKE spends one and wobbles immediately', (tester) async {
    final game = await openGame(tester);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Shake, 3 left')));
    await advance(tester, 300);
    expect(game.powerUps.shakes.value, 1);
    expect(prefs.getInt(SaveKeys.powerUp(PowerUp.shake)), 2);
    expect(tester.takeException(), isNull);
  });
}
