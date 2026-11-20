import 'dart:async';
import 'dart:convert';

import 'package:fluffy_merge/app/app.dart';
import 'package:fluffy_merge/core/services/ads/ad_service.dart';
import 'package:fluffy_merge/core/services/analytics/analytics_service.dart';
import 'package:fluffy_merge/core/services/payments/payment_service.dart';
import 'package:fluffy_merge/core/services/payments/store_payment_service.dart';
import 'package:fluffy_merge/data/local/preferences_provider.dart';
import 'package:fluffy_merge/data/local/save_data.dart';
import 'package:fluffy_merge/data/local/save_keys.dart';
import 'package:fluffy_merge/data/local/save_store.dart';
import 'package:fluffy_merge/features/game_over/results_screen.dart';
import 'package:fluffy_merge/features/home/home_screen.dart';
import 'package:fluffy_merge/features/shop/shop_controller.dart';
import 'package:fluffy_merge/game/components/danger_line_component.dart';
import 'package:fluffy_merge/game/fluffy_game.dart';
import 'package:fluffy_merge/game/models/power_up.dart';
import 'package:fluffy_merge/game/models/run_result.dart';
import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/save_reader.dart';

/// Same overfill as game_over_test: Lv. 6 grid reaching above the jar,
/// merges disabled.
void _overfill(FluffyGame game, {int rows = 9}) {
  game.onMergeDetected = (pair) {
    pair.a.claimedForMerge = false;
    pair.b.claimedForMerge = false;
  };
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < 4; col++) {
      game.spawnCreature(6, Vector2(1.3 + col * 2.45, 12.8 - row * 2.3));
    }
  }
}

/// A store that answers like Google Play / StoreKit would, on demand.
class _FakeGateway implements StoreGateway {
  _FakeGateway({this.storeUp = true, this.known = const {}});

  bool storeUp;
  Map<String, String> known;
  final _updates = StreamController<List<StoreUpdate>>.broadcast();
  final List<String> bought = [];
  final List<String> acknowledged = [];
  int restores = 0;

  void emit(String id, PurchaseStatus status, {bool restored = false}) =>
      _updates.add([
        StoreUpdate(
          productId: id,
          status: status,
          restored: restored,
          complete: () async => acknowledged.add(id),
        ),
      ]);

  @override
  Future<bool> isAvailable() async => storeUp;

  @override
  Future<Map<String, String>> queryPrices(Set<String> ids) async => {
    for (final e in known.entries)
      if (ids.contains(e.key)) e.key: e.value,
  };

  @override
  Stream<List<StoreUpdate>> get updates => _updates.stream;

  @override
  Future<bool> buy(String id, {required bool consumable}) async {
    bought.add(id);
    return true;
  }

  @override
  Future<void> restore() async => restores++;
}

const _allPrices = {
  'coins_500': r'$0.99',
  'coins_1500': r'$1.99',
  'coins_5000': r'$4.99',
  'remove_ads': r'$1.99',
};

void main() {
  group('InterstitialPolicy', () {
    final t0 = DateTime(2026, 11, 20, 12);

    test('never for new players or after Remove Ads', () {
      final p = InterstitialPolicy();
      for (var g = 1; g <= 3; g++) {
        expect(
          p.onRunFinished(adsRemoved: false, lifetimeGames: g, now: t0),
          isFalse,
          reason: 'grace game $g',
        );
      }
      final paid = InterstitialPolicy();
      for (var g = 10; g < 30; g++) {
        expect(
          paid.onRunFinished(
            adsRemoved: true,
            lifetimeGames: g,
            now: t0.add(Duration(hours: g)),
          ),
          isFalse,
        );
      }
    });

    test('at most every 3rd run and 3 minutes apart', () {
      final p = InterstitialPolicy();
      var now = t0;
      bool run(int games, [Duration gap = const Duration(minutes: 2)]) {
        now = now.add(gap);
        return p.onRunFinished(
          adsRemoved: false,
          lifetimeGames: games,
          now: now,
        );
      }

      expect([run(10), run(11), run(12)], [false, false, true]);
      // Three quick runs (2 min each = 6 min since the last ad) → due.
      expect([run(13), run(14), run(15)], [false, false, true]);
      // Three very quick runs (30 s each): not yet 3 minutes.
      const quick = Duration(seconds: 30);
      expect([run(16, quick), run(17, quick), run(18, quick)], [
        false,
        false,
        false,
      ]);
      // Next run, once the gap is over, gets it.
      expect(run(19, const Duration(minutes: 3)), isTrue);
    });
  });

  group('StorePaymentService', () {
    test('unavailable when the store is down or has no products', () async {
      final down = StorePaymentService(_FakeGateway(storeUp: false));
      await down.init();
      expect(down.available, isFalse);
      expect(
        (await down.buy(StoreProduct.coins500)).status,
        PurchaseStatus.unavailable,
      );

      // Store up but products not configured yet (fresh console).
      final empty = StorePaymentService(_FakeGateway());
      await empty.init();
      expect(empty.available, isFalse);
      expect(empty.priceOf(StoreProduct.removeAds), isNull);
      expect(await empty.restore(), isEmpty);
    });

    test('buy resolves from the purchase stream; acknowledged', () async {
      final gw = _FakeGateway(known: _allPrices);
      final store = StorePaymentService(gw);
      await store.init();
      expect(store.available, isTrue);
      expect(store.isTestStore, isFalse);
      expect(store.priceOf(StoreProduct.coins1500), r'$1.99');

      final buying = store.buy(StoreProduct.coins1500);
      await Future<void>.delayed(Duration.zero);
      expect(gw.bought, ['coins_1500']);
      gw.emit('coins_1500', PurchaseStatus.success);
      expect((await buying).ok, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(gw.acknowledged, ['coins_1500']);

      final cancelled = store.buy(StoreProduct.coins500);
      await Future<void>.delayed(Duration.zero);
      gw.emit('coins_500', PurchaseStatus.cancelled);
      expect((await cancelled).status, PurchaseStatus.cancelled);
      store.dispose();
    });

    test('late (pending) purchases are delivered, then acknowledged', () async {
      final gw = _FakeGateway(known: _allPrices);
      final delivered = <StoreProduct>[];
      final store = StorePaymentService(gw)..onDelivered = delivered.add;
      await store.init();

      gw.emit('coins_5000', PurchaseStatus.unavailable); // pending
      await Future<void>.delayed(Duration.zero);
      expect(delivered, isEmpty);
      expect(gw.acknowledged, isEmpty);

      gw.emit('coins_5000', PurchaseStatus.success); // approved later
      await Future<void>.delayed(Duration.zero);
      expect(delivered, [StoreProduct.coins5000]);
      expect(gw.acknowledged, ['coins_5000']);
      store.dispose();
    });

    test('restore collects restored items', () async {
      final gw = _FakeGateway(known: _allPrices);
      final store = StorePaymentService(gw, restoreWindow: Duration.zero);
      await store.init();
      final restoring = store.restore();
      gw.emit('remove_ads', PurchaseStatus.success, restored: true);
      expect(await restoring, {StoreProduct.removeAds});
      expect(gw.restores, 1);
      store.dispose();
    });
  });

  group('Shop analytics', () {
    test('purchase_started / purchase_completed', () async {
      SharedPreferences.setMockInitialValues({
        SaveStore.primaryKey: jsonEncode(SaveData.fresh().toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      final analytics = DebugAnalytics();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          paymentServiceProvider.overrideWithValue(
            TestPaymentService(delay: Duration.zero),
          ),
          analyticsProvider.overrideWithValue(analytics),
        ],
      );
      addTearDown(c.dispose);
      final out = await c
          .read(shopControllerProvider)
          .buyProduct(StoreProduct.coins500);
      expect(out.ok, isTrue);
      expect(analytics.of(AnalyticsEvent.purchaseStarted), [
        {'product': 'coins_500'},
      ]);
      expect(analytics.of(AnalyticsEvent.purchaseCompleted), [
        {'product': 'coins_500'},
      ]);
    });
  });

  group('Continue (revive)', () {
    testWithGame<FluffyGame>(
      'revive clears the top of the jar and the run goes on',
      () => FluffyGame(seed: 4),
      (game) async {
        try {
          await game.ready();
          expect(game.revive(), 0, reason: 'nothing to do mid-run');
          var overs = 0;
          game.addGameOverListener(() => overs++);
          _overfill(game);
          await game.ready();
          for (var t = 0.0; t < 12 && overs == 0; t += 1 / 60) {
            game.update(1 / 60);
            await game.ready();
          }
          expect(overs, 1);
          final before = game.creatures.length;

          final cleared = game.revive();
          await game.ready();
          expect(cleared, greaterThan(0));
          expect(game.creatures.length, before - cleared);
          expect(game.isGameOver, isFalse);
          expect(game.frozen, isFalse);
          expect(game.inputLocked, isFalse);
          expect(game.revives, 1);
          final limit = DangerLineComponent.y + FluffyGame.reviveClearDepth;
          for (final c in game.creatures) {
            expect(c.y - c.bodyRadius, greaterThanOrEqualTo(limit - 1e-6));
          }
          // The jar is below the line again: it keeps running.
          for (var i = 0; i < 300; i++) {
            game.update(1 / 60);
            await game.ready();
          }
          expect(overs, 1);
          expect(game.isGameOver, isFalse);
        } finally {
          game.disposeSession();
        }
      },
    );
  });

  group('Screens', () {
    late SharedPreferences prefs;
    late DebugAdService ads;
    late DebugAnalytics analytics;

    Future<void> advance(WidgetTester tester, [int ms = 600]) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> untilFound(WidgetTester tester, Finder f) async {
      for (var i = 0; i < 240 && f.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(f, findsWidgets);
    }

    Future<void> boot(
      WidgetTester tester, {
      Map<String, Object> saved = const {},
    }) async {
      SharedPreferences.setMockInitialValues(saved);
      prefs = await SharedPreferences.getInstance();
      ads = DebugAdService(delay: const Duration(milliseconds: 300));
      analytics = DebugAnalytics();
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            adServiceProvider.overrideWithValue(ads),
            analyticsProvider.overrideWithValue(analytics),
          ],
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

    testWidgets('game over → watch ad → keep playing; offered only once', (
      tester,
    ) async {
      await boot(tester);
      final game = await play(tester);
      expect(analytics.of(AnalyticsEvent.gameStarted), hasLength(1));
      _overfill(game);
      await untilFound(tester, find.text('Keep going?'));
      await advance(tester, 500); // dialog entrance
      await tester.tap(find.bySemanticsLabel('Watch ad'));
      await advance(tester, 1000);

      expect(ads.shown, ['rewarded:continue']);
      expect(find.byType(ResultsScreen), findsNothing);
      expect(game.isGameOver, isFalse);
      expect(game.revives, 1);
      expect(analytics.of(AnalyticsEvent.rewardedAdWatched), [
        {'placement': 'continue'},
      ]);
      expect(readSave(prefs).stats.gamesPlayed, 0, reason: 'run goes on');

      // Overflow again: no second offer, straight to results.
      _overfill(game, rows: 6);
      await untilFound(tester, find.byType(ResultsScreen));
      expect(find.text('Keep going?'), findsNothing);
      expect(readSave(prefs).stats.gamesPlayed, 1);
      final over = analytics.of(AnalyticsEvent.gameOver).single;
      expect(over['continued'], 1);
      expect(over['ended_by'], 'overflow');
      expect(tester.takeException(), isNull);
    });

    testWidgets('out of a power-up: one free for an ad, once per run', (
      tester,
    ) async {
      await boot(tester, saved: {SaveKeys.powerUp(PowerUp.shake): 0});
      final game = await play(tester);

      await tester.tap(find.bySemanticsLabel(RegExp(r'^Shake, 0 left')));
      await advance(tester, 500);
      expect(find.text('Free Shake?'), findsWidgets);
      await tester.tap(find.bySemanticsLabel('Watch ad'));
      await advance(tester, 1000);
      expect(ads.shown, ['rewarded:free_powerup']);
      expect(readSave(prefs).powerUpCount(PowerUp.shake), 1);
      expect(find.byType(SnackBar), findsNothing, reason: 'bar stays clear');

      await tester.tap(find.bySemanticsLabel(RegExp(r'^Shake, 1 left')));
      await advance(tester, 400);
      expect(game.powerUps.shakes.value, 1);
      expect(analytics.of(AnalyticsEvent.powerUpUsed), [
        {'type': 'shake'},
      ]);

      // Second time this run: just the how-to-earn tip.
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Shake, 0 left')));
      await advance(tester, 500);
      expect(find.text('Free Shake?'), findsNothing);
      expect(find.textContaining('No Shakes left'), findsOneWidget);
      expect(ads.shown, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('due interstitial shows only when leaving results', (
      tester,
    ) async {
      await boot(tester);
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pushNamed(
        '/results',
        arguments: const RunResult(
          score: 500,
          bestScore: 500,
          isNewBest: false,
          highestLevel: 5,
          coinsEarned: 4,
          merges: 10,
          drops: 15,
          bestCombo: 2,
          seconds: 60,
          interstitialDue: true,
        ),
      );
      await advance(tester, 1600);
      expect(ads.shown, isEmpty, reason: 'never over the score');
      await tester.tap(find.bySemanticsLabel('Home'));
      await advance(tester, 1600);
      expect(ads.shown, ['interstitial']);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('quit runs count toward the interstitial policy', (
      tester,
    ) async {
      final saved = SaveData.fresh().copyWith(
        stats: const LifetimeStats(gamesPlayed: 20),
      );
      await boot(
        tester,
        saved: {SaveStore.primaryKey: jsonEncode(saved.toJson())},
      );
      Future<void> quit() async {
        await tester.tap(find.bySemanticsLabel('Pause'));
        await advance(tester, 600);
        await tester.tap(find.bySemanticsLabel('Home'));
        await advance(tester, 1200);
      }

      await play(tester);
      await quit();
      await play(tester);
      await quit();
      expect(ads.shown, isEmpty);
      await play(tester);
      await quit();
      expect(ads.shown, ['interstitial'], reason: 'every 3rd run');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        analytics.of(AnalyticsEvent.gameOver).map((e) => e['ended_by']),
        ['quit', 'quit', 'quit'],
      );
    });
  });
}
