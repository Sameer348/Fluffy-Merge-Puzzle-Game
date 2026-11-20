import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_service.dart' show runningInTest;
import 'store_payment_service.dart';

/// Real-money products. Ids match what will be configured in Google Play
/// Console and App Store Connect.
enum StoreProduct {
  coins500('coins_500', consumable: true),
  coins1500('coins_1500', consumable: true),
  coins5000('coins_5000', consumable: true),
  removeAds('remove_ads', consumable: false);

  const StoreProduct(this.id, {required this.consumable});

  final String id;

  /// Consumables can be bought again; non-consumables are restorable.
  final bool consumable;
}

/// Outcome of a purchase attempt.
enum PurchaseStatus { success, cancelled, failed, unavailable }

@immutable
class PurchaseResult {
  const PurchaseResult(this.status, [this.message]);
  final PurchaseStatus status;
  final String? message;
  bool get ok => status == PurchaseStatus.success;
}

/// In-app purchases behind an interface, so Google Play Billing and Apple
/// StoreKit (e.g. via `in_app_purchase`) can be plugged in later without
/// touching the shop. The shop only ever grants rewards after [buy]
/// reports success.
abstract interface class PaymentService {
  /// Whether real-money purchases can be made at all right now.
  bool get available;

  /// True for a simulated store (debug builds): the UI says so clearly.
  bool get isTestStore;

  /// Localized price string for display, or null if unknown.
  String? priceOf(StoreProduct p);

  Future<PurchaseResult> buy(StoreProduct p);

  /// Non-consumables the player owns (for "Restore purchases").
  Future<Set<StoreProduct>> restore();
}

/// Release builds until a real store is integrated: nothing for sale.
class NoPaymentService implements PaymentService {
  const NoPaymentService();

  @override
  bool get available => false;

  @override
  bool get isTestStore => false;

  @override
  String? priceOf(StoreProduct p) => null;

  @override
  Future<PurchaseResult> buy(StoreProduct p) async =>
      const PurchaseResult(PurchaseStatus.unavailable);

  @override
  Future<Set<StoreProduct>> restore() async => const {};
}

/// Debug builds only: a pretend store with placeholder prices that
/// "succeeds" after a short delay and charges nothing. Lets the whole
/// purchase → reward flow be played and tested end to end.
class TestPaymentService implements PaymentService {
  TestPaymentService({this.delay = const Duration(milliseconds: 600)});

  final Duration delay;
  final Set<StoreProduct> _owned = {};
  final List<StoreProduct> purchases = [];

  static const _prices = {
    StoreProduct.coins500: r'$0.99',
    StoreProduct.coins1500: r'$1.99',
    StoreProduct.coins5000: r'$4.99',
    StoreProduct.removeAds: r'$1.99',
  };

  @override
  bool get available => true;

  @override
  bool get isTestStore => true;

  @override
  String? priceOf(StoreProduct p) => _prices[p];

  @override
  Future<PurchaseResult> buy(StoreProduct p) async {
    await Future<void>.delayed(delay);
    purchases.add(p);
    if (!p.consumable) _owned.add(p);
    return const PurchaseResult(PurchaseStatus.success);
  }

  @override
  Future<Set<StoreProduct>> restore() async => {..._owned};
}

/// Debug builds use the pretend store; release builds the real one
/// (unavailable until products exist in Play Console / App Store Connect).
/// Purchases completed outside a buy() call are granted by the shop,
/// which sets [StorePaymentService.onDelivered].
final paymentServiceProvider = Provider<PaymentService>((ref) {
  if (kDebugMode || runningInTest) return TestPaymentService();
  final store = StorePaymentService(IapStoreGateway());
  unawaited(store.init());
  ref.onDispose(store.dispose);
  return store;
});
