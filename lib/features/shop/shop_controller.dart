import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/analytics/analytics_service.dart';
import '../../core/services/payments/payment_service.dart';
import '../../core/services/payments/store_payment_service.dart';
import '../../data/local/save_data.dart';
import '../../data/repositories/save_controller.dart';
import '../../game/models/power_up.dart';
import 'model/cosmetics.dart';

/// A power-up bundle bought with coins.
@immutable
class PowerUpPack {
  const PowerUpPack(this.powerUp, this.amount, this.price);
  final PowerUp powerUp;
  final int amount;
  final int price;
}

/// A real-money coin pack.
@immutable
class CoinPack {
  const CoinPack(this.product, this.coins);
  final StoreProduct product;
  final int coins;
}

abstract final class ShopCatalog {
  static const coinPacks = [
    CoinPack(StoreProduct.coins500, 500),
    CoinPack(StoreProduct.coins1500, 1500),
    CoinPack(StoreProduct.coins5000, 5000),
  ];

  static const powerUpPacks = [
    PowerUpPack(PowerUp.sweep, 3, 300),
    PowerUpPack(PowerUp.pop, 3, 300),
    PowerUpPack(PowerUp.grow, 3, 400),
    PowerUpPack(PowerUp.shake, 3, 250),
  ];
}

/// Result of a shop action, for the toast.
@immutable
class ShopOutcome {
  const ShopOutcome(this.ok, this.message);
  final bool ok;
  final String message;
}

/// Shop rules. Rewards are granted only after payment succeeds (coins
/// spent or store purchase confirmed), and each action is all-or-nothing.
class ShopController {
  ShopController(this._ref);

  final Ref _ref;

  SaveController get _save => _ref.read(saveProvider.notifier);
  SaveData get _data => _ref.read(saveProvider);
  PaymentService get _payments => _ref.read(paymentServiceProvider);
  AnalyticsService get _analytics => _ref.read(analyticsProvider);

  // --- Coins → power-ups ---------------------------------------------------

  ShopOutcome buyPowerUps(PowerUpPack pack) {
    final have = _data.powerUpCount(pack.powerUp);
    if (have + pack.amount > SaveData.maxPowerUps) {
      return ShopOutcome(false, 'Your ${pack.powerUp.label} pouch is full!');
    }
    if (!_save.spendCoins(pack.price)) {
      return ShopOutcome(
        false,
        'You need ${pack.price - _data.coins} more coins.',
      );
    }
    _save.addPowerUp(pack.powerUp, pack.amount);
    return ShopOutcome(true, '+${pack.amount} ${pack.powerUp.label}!');
  }

  // --- Cosmetics -----------------------------------------------------------

  bool owns(String id) =>
      Cosmetics.defaults.contains(id) || _data.ownedCosmetics.contains(id);

  /// Buys (if needed) and equips a jar skin or background.
  ShopOutcome buyOrEquip(String id) {
    final jar = Cosmetics.jarSkins.where((j) => j.id == id).firstOrNull;
    final scene = Cosmetics.scenes.where((s) => s.id == id).firstOrNull;
    if (jar == null && scene == null) {
      return const ShopOutcome(false, 'That item isn\'t available.');
    }
    final name = jar?.name ?? scene!.name;
    final price = jar?.price ?? scene!.price;
    var bought = false;
    if (!owns(id)) {
      if (!_save.spendCoins(price)) {
        return ShopOutcome(
          false,
          'You need ${price - _data.coins} more coins.',
        );
      }
      _save.addCosmetic(id);
      bought = true;
    }
    if (jar != null) {
      _save.equipJar(id);
    } else {
      _save.equipScene(id);
    }
    return ShopOutcome(true, bought ? 'Unlocked $name!' : '$name equipped');
  }

  // --- Real money ----------------------------------------------------------

  Future<ShopOutcome> buyProduct(StoreProduct p) async {
    if (!_payments.available) {
      return const ShopOutcome(false, 'The store isn\'t available yet.');
    }
    if (p == StoreProduct.removeAds && _data.adsRemoved) {
      return const ShopOutcome(false, 'Ads are already removed.');
    }
    _analytics.log(AnalyticsEvent.purchaseStarted, {'product': p.id});
    final result = await _payments.buy(p);
    if (result.ok) {
      _analytics.log(AnalyticsEvent.purchaseCompleted, {'product': p.id});
    }
    if (!result.ok) {
      return ShopOutcome(
        false,
        result.status == PurchaseStatus.cancelled
            ? 'Purchase cancelled.'
            : 'Purchase didn\'t go through. You weren\'t charged.',
      );
    }
    return deliver(p);
  }

  /// Grants what [p] buys. Called after a successful purchase, and by the
  /// real store for purchases that complete later (pending payments).
  ShopOutcome deliver(StoreProduct p) {
    if (p == StoreProduct.removeAds) {
      _save.setAdsRemoved();
      return const ShopOutcome(true, 'Ads removed. Thank you!');
    }
    final pack = ShopCatalog.coinPacks.firstWhere((c) => c.product == p);
    _save.addCoins(pack.coins);
    return ShopOutcome(true, '+${pack.coins} coins!');
  }

  Future<ShopOutcome> restorePurchases() async {
    if (!_payments.available) {
      return const ShopOutcome(false, 'The store isn\'t available yet.');
    }
    final owned = await _payments.restore();
    if (owned.contains(StoreProduct.removeAds)) {
      _save.setAdsRemoved();
      return const ShopOutcome(true, 'Purchases restored.');
    }
    return const ShopOutcome(true, 'Nothing to restore.');
  }
}

final shopControllerProvider = Provider<ShopController>((ref) {
  final shop = ShopController(ref);
  final payments = ref.watch(paymentServiceProvider);
  if (payments is StorePaymentService) payments.onDelivered = shop.deliver;
  return shop;
});

/// Equipped cosmetics (rebuild only when they change).
final equippedJarProvider = Provider<JarSkin>(
  (ref) => Cosmetics.jar(ref.watch(saveProvider.select((s) => s.equippedJar))),
);

final equippedSceneProvider = Provider<SceneTheme>(
  (ref) =>
      Cosmetics.scene(ref.watch(saveProvider.select((s) => s.equippedScene))),
);
