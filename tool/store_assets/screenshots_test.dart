// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders store screenshots of the real app screens at full resolution,
// with the bundled fonts and a seeded, mid-game save.
//
//   flutter test tool/store_assets/screenshots_test.dart
//   python3 tool/store_assets/make_store_screens.py
//
// Writes PNGs per store device class (iPhone 6.9", iPad 13") to
// build/store_screens/<device>/.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluffy_merge/app/app.dart';
import 'package:fluffy_merge/app/routes.dart';
import 'package:fluffy_merge/core/services/ads/ad_service.dart';
import 'package:fluffy_merge/core/services/payments/payment_service.dart';
import 'package:fluffy_merge/data/local/preferences_provider.dart';
import 'package:fluffy_merge/data/local/save_data.dart';
import 'package:fluffy_merge/data/local/save_store.dart';
import 'package:fluffy_merge/game/fluffy_game.dart';
import 'package:fluffy_merge/game/models/run_result.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Store device classes: folder, logical size, device pixel ratio.
const _devices = [
  ('iphone_6_9', Size(440, 956), 3.0), // 1320 x 2868
  ('ipad_13', Size(1032, 1376), 2.0), // 2064 x 2752
];

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(f).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  await family('Fredoka', ['assets/fonts/Fredoka-SemiBold.ttf']);
  await family('Nunito', [
    'assets/fonts/Nunito-SemiBold.ttf',
    'assets/fonts/Nunito-Bold.ttf',
    'assets/fonts/Nunito-ExtraBold.ttf',
    'assets/fonts/Nunito-Black.ttf',
  ]);
  final sdk = File(Platform.resolvedExecutable).parent.parent.parent.parent;
  await family('MaterialIcons', [
    '${sdk.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

Future<void> _shot(WidgetTester tester, String device, String name) async {
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    // The root layer is already in device pixels.
    final img = await layer.toImage(Offset.zero & tester.view.physicalSize);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    File('build/store_screens/$device/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  Future<void> advance(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  for (final (device, logical, dpr) in _devices) {
    testWidgets('store screenshots: $device', (tester) async {
      final save = SaveData.fresh().copyWith(
        bestScore: 48250,
        coins: 1240,
        unlockedLevels: {1, 2, 3, 4, 5, 6, 7, 8, 9},
        seenLevels: {1, 2, 3, 4, 5, 6, 7, 8, 9},
        stats: const LifetimeStats(gamesPlayed: 42, highestLevel: 9),
      );
      SharedPreferences.setMockInitialValues({
        SaveStore.primaryKey: jsonEncode(save.toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = logical * dpr;
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            // What release builds show: no ads, a real (not test) store.
            adServiceProvider.overrideWithValue(const NoAdService()),
            paymentServiceProvider.overrideWithValue(_StoreLike()),
          ],
          child: const FluffyMergeApp(),
        ),
      );
      await advance(tester, 3000);
      await _shot(tester, device, '01_home');

      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.pushNamed(
        AppRoutes.results,
        arguments: const RunResult(
          score: 52480,
          bestScore: 52480,
          isNewBest: true,
          highestLevel: 9,
          coinsEarned: 64,
          merges: 138,
          drops: 171,
          bestCombo: 6,
          seconds: 412,
        ),
      );
      await advance(tester, 2500);
      await _shot(tester, device, '05_results');
      nav.pop();
      await advance(tester, 800);

      for (final (route, name) in const [
        (AppRoutes.collection, '06_collection'),
        (AppRoutes.daily, '07_daily'),
        (AppRoutes.shop, '08_shop'),
      ]) {
        nav.pushNamed(route);
        await advance(tester, 2000);
        await _shot(tester, device, name);
        nav.pop();
        await advance(tester, 800);
      }

      // Gameplay: a mid-run jar (placed, then settled by the real physics).
      nav.pushNamed(AppRoutes.game);
      await advance(tester, 1500);
      final game = tester
          .widget<GameWidget<FluffyGame>>(find.byType(GameWidget<FluffyGame>))
          .game!;
      // Keep the arrangement exactly as placed (no merges in the shot).
      game.onMergeDetected = (pair) {
        pair.a.claimedForMerge = false;
        pair.b.claimedForMerge = false;
      };
      const pile = [
        (8, 1.9, 12.2),
        (9, 5.3, 12.0),
        (7, 8.6, 12.4),
        (5, 1.4, 9.6),
        (6, 4.2, 9.4),
        (4, 6.9, 9.6),
        (6, 8.9, 9.4),
        (3, 2.6, 7.8),
        (2, 5.0, 7.6),
        (5, 7.4, 7.6),
        (1, 9.3, 7.4),
      ];
      for (final (level, x, y) in pile) {
        game.spawnCreature(level, Vector2(x, y));
      }
      game.drops.value = 57; // past the first-run "drag to aim" hint
      game.scoring.score.value = 18640;
      game.scoring.coins.value = 37;
      game.aimAt(4.2);
      await advance(tester, 4000);
      await _shot(tester, device, '02_gameplay');
      expect(tester.takeException(), isNull);
    });
  }
}

/// A store as it looks in release (localized prices, no "test store" note).
class _StoreLike extends TestPaymentService {
  @override
  bool get isTestStore => false;
}
