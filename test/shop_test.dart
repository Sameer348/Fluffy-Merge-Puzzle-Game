import 'package:fluffy_merge/core/services/ads/ad_service.dart';

import 'dart:convert';

import 'package:fluffy_merge/app/app.dart';
import 'package:fluffy_merge/core/services/payments/payment_service.dart';
import 'package:fluffy_merge/data/local/preferences_provider.dart';
import 'package:fluffy_merge/data/local/save_data.dart';
import 'package:fluffy_merge/data/local/save_store.dart';
import 'package:fluffy_merge/data/repositories/save_controller.dart';
import 'package:fluffy_merge/features/shop/model/cosmetics.dart';
import 'package:fluffy_merge/features/shop/shop_controller.dart';
import 'package:fluffy_merge/features/shop/shop_screen.dart';
import 'package:fluffy_merge/game/models/power_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/save_reader.dart';

/// A store that always fails, to prove nothing is granted without payment.
class _FailingStore implements PaymentService {
  @override
  bool get available => true;
  @override
  bool get isTestStore => true;
  @override
  String? priceOf(StoreProduct p) => r'$9.99';
  @override
  Future<PurchaseResult> buy(StoreProduct p) async =>
      const PurchaseResult(PurchaseStatus.failed);
  @override
  Future<Set<StoreProduct>> restore() async => const {};
}

Future<ProviderContainer> _container({
  int coins = 0,
  PaymentService? payments,
}) async {
  SharedPreferences.setMockInitialValues({
    SaveStore.primaryKey: jsonEncode(
      SaveData.fresh().copyWith(coins: coins).toJson(),
    ),
  });
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      paymentServiceProvider.overrideWithValue(
        payments ?? TestPaymentService(delay: Duration.zero),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('ShopController', () {
    test('coins buy power-ups; not enough coins changes nothing', () async {
      final c = await _container(coins: 350);
      final shop = c.read(shopControllerProvider);
      final pop = ShopCatalog.powerUpPacks.firstWhere(
        (p) => p.powerUp == PowerUp.pop,
      );
      expect(shop.buyPowerUps(pop).ok, isTrue);
      expect(c.read(saveProvider).coins, 50);
      expect(c.read(saveProvider).powerUpCount(PowerUp.pop), 6);

      final again = shop.buyPowerUps(pop);
      expect(again.ok, isFalse);
      expect(again.message, 'You need 250 more coins.');
      expect(c.read(saveProvider).coins, 50);
      expect(c.read(saveProvider).powerUpCount(PowerUp.pop), 6);
    });

    test('cosmetics: buy once, then equip for free', () async {
      final c = await _container(coins: 2000);
      final shop = c.read(shopControllerProvider);
      expect(c.read(equippedJarProvider).id, 'jar_classic');

      expect(shop.buyOrEquip('jar_mint').message, 'Unlocked Mint Soda!');
      expect(c.read(saveProvider).coins, 1200);
      expect(c.read(equippedJarProvider).id, 'jar_mint');

      shop.buyOrEquip('jar_classic'); // free default
      expect(c.read(equippedJarProvider).id, 'jar_classic');
      expect(shop.buyOrEquip('jar_mint').message, 'Mint Soda equipped');
      expect(c.read(saveProvider).coins, 1200, reason: 'not charged twice');

      expect(
        shop.buyOrEquip('scene_dreamy').ok,
        isFalse,
        reason: '1500 > 1200',
      );
      expect(c.read(equippedSceneProvider).id, 'scene_meadow');
      expect(shop.buyOrEquip('nope').ok, isFalse);
    });

    test('real money: grants only after a successful purchase', () async {
      final c = await _container();
      final shop = c.read(shopControllerProvider);
      expect((await shop.buyProduct(StoreProduct.coins1500)).ok, isTrue);
      expect(c.read(saveProvider).coins, 1500);
      expect((await shop.buyProduct(StoreProduct.removeAds)).ok, isTrue);
      expect(c.read(saveProvider).adsRemoved, isTrue);
      final dup = await shop.buyProduct(StoreProduct.removeAds);
      expect(dup.message, 'Ads are already removed.');

      final failing = await _container(payments: _FailingStore());
      final o = await failing
          .read(shopControllerProvider)
          .buyProduct(StoreProduct.coins5000);
      expect(o.ok, isFalse);
      expect(o.message, contains('weren\'t charged'));
      expect(failing.read(saveProvider).coins, 0);
    });

    test('no store (release until integrated): nothing for sale', () async {
      final c = await _container(payments: const NoPaymentService());
      final o = await c
          .read(shopControllerProvider)
          .buyProduct(StoreProduct.coins500);
      expect(o.ok, isFalse);
      expect(c.read(saveProvider).coins, 0);
    });

    test('restore brings back Remove Ads', () async {
      final store = TestPaymentService(delay: Duration.zero);
      await store.buy(StoreProduct.removeAds); // bought on another install
      final c = await _container(payments: store);
      expect(c.read(saveProvider).adsRemoved, isFalse);
      await c.read(shopControllerProvider).restorePurchases();
      expect(c.read(saveProvider).adsRemoved, isTrue);
    });
  });

  group('Shop screen', () {
    late SharedPreferences prefs;

    Future<void> advance(WidgetTester tester, [int ms = 600]) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> openShop(
      WidgetTester tester, {
      int coins = 1000,
      Size size = const Size(393, 852),
      PaymentService? payments,
      AdService? ads,
      bool adsRemoved = false,
    }) async {
      SharedPreferences.setMockInitialValues({
        SaveStore.primaryKey: jsonEncode(
          SaveData.fresh()
              .copyWith(coins: coins, adsRemoved: adsRemoved)
              .toJson(),
        ),
      });
      prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            paymentServiceProvider.overrideWithValue(
              payments ?? TestPaymentService(delay: Duration.zero),
            ),
            if (ads != null) adServiceProvider.overrideWithValue(ads),
          ],
          child: const FluffyMergeApp(),
        ),
      );
      await advance(tester, 2400);
      await tester.tap(find.text('Shop'));
      await advance(tester, 1000);
      expect(find.byType(ShopScreen), findsOneWidget);
    }

    testWidgets('power-ups tab: buy with coins', (tester) async {
      await openShop(tester, coins: 1000);
      await tester.tap(find.bySemanticsLabel('Buy for 400 coins'));
      await advance(tester);
      expect(find.text('+3 Grow!'), findsOneWidget);
      expect(readSave(prefs).coins, 600);
      expect(readSave(prefs).powerUpCount(PowerUp.grow), 6);
    });

    testWidgets('cosmetics tab: buy and equip a background', (tester) async {
      await openShop(tester, coins: 1200);
      await tester.tap(find.bySemanticsLabel('Cosmetics tab'));
      await advance(tester);
      expect(find.text('Peach Sunset'), findsOneWidget);
      expect(find.bySemanticsLabel('Equipped'), findsNWidgets(2));
      await tester.tap(find.bySemanticsLabel('Buy for 1000 coins'));
      await advance(tester);
      expect(find.text('Unlocked Peach Sunset!'), findsOneWidget);
      expect(readSave(prefs).equippedScene, 'scene_sunset');
      expect(
        find.bySemanticsLabel('Buy for 1500 coins, not enough coins'),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('coins tab + remove ads via the (test) store', (tester) async {
      await openShop(tester, coins: 0);
      expect(find.textContaining('no real money is charged'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Coins tab'));
      await advance(tester);
      await tester.tap(find.bySemanticsLabel(r'Buy for $0.99'));
      await advance(tester);
      expect(readSave(prefs).coins, 500);
      await tester.tap(find.bySemanticsLabel(r'Remove Ads  $1.99'));
      await advance(tester);
      expect(readSave(prefs).adsRemoved, isTrue);
      expect(find.bySemanticsLabel('Ads removed'), findsOneWidget);
    });

    testWidgets('release (no store): money items say coming soon', (
      tester,
    ) async {
      await openShop(tester, payments: const NoPaymentService());
      expect(find.textContaining('no real money'), findsNothing);
      expect(find.bySemanticsLabel('Remove Ads: coming soon'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Coins tab'));
      await advance(tester);
      expect(find.textContaining('Coin packs are coming soon'), findsOneWidget);
    });

    testWidgets('no ads in this build: Remove Ads is not sold', (tester) async {
      await openShop(tester, ads: const NoAdService());
      expect(find.textContaining('Remove Ads'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Coins tab'));
      await advance(tester);
      expect(find.textContaining('Remove Ads'), findsNothing);
    });

    testWidgets('already bought Remove Ads: still shown as owned', (
      tester,
    ) async {
      await openShop(tester, ads: const NoAdService(), adsRemoved: true);
      expect(find.bySemanticsLabel('Ads removed'), findsOneWidget);
    });

    testWidgets('fits a small phone', (tester) async {
      await openShop(tester, size: const Size(360, 640));
      for (final tab in ['Coins tab', 'Cosmetics tab', 'Power-ups tab']) {
        await tester.tap(find.bySemanticsLabel(tab));
        await advance(tester, 300);
      }
      expect(tester.takeException(), isNull);
    });
  });

  test('cosmetic catalogue ids are unique and defaults are free', () {
    final ids = [
      for (final j in Cosmetics.jarSkins) j.id,
      for (final s in Cosmetics.scenes) s.id,
    ];
    expect(ids.toSet(), hasLength(ids.length));
    expect(Cosmetics.jarSkins.first.price, 0);
    expect(Cosmetics.scenes.first.price, 0);
    expect(Cosmetics.jar('missing').id, 'jar_classic');
  });
}
