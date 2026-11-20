import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart' as iap;

import 'payment_service.dart';

/// One store update, reduced to what the game needs.
@immutable
class StoreUpdate {
  const StoreUpdate({
    required this.productId,
    required this.status,
    this.restored = false,
    this.complete,
  });

  final String productId;
  final PurchaseStatus status;

  /// True for a restored (not newly bought) non-consumable.
  final bool restored;

  /// Acknowledges the purchase with the store (must be called once the
  /// reward is granted, or Google Play refunds it after 3 days).
  final Future<void> Function()? complete;
}

/// The few store calls the game makes. [IapStoreGateway] talks to Google
/// Play Billing / StoreKit through `in_app_purchase`; tests use a fake.
abstract interface class StoreGateway {
  Future<bool> isAvailable();

  /// Product id → localized price, for the ids the store knows about.
  Future<Map<String, String>> queryPrices(Set<String> ids);

  Stream<List<StoreUpdate>> get updates;

  /// Starts the store's purchase sheet. False if it couldn't be shown.
  Future<bool> buy(String id, {required bool consumable});

  Future<void> restore();
}

class IapStoreGateway implements StoreGateway {
  IapStoreGateway([iap.InAppPurchase? store])
    : _store = store ?? iap.InAppPurchase.instance;

  final iap.InAppPurchase _store;
  final Map<String, iap.ProductDetails> _details = {};

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  @override
  Future<Map<String, String>> queryPrices(Set<String> ids) async {
    final res = await _store.queryProductDetails(ids);
    for (final d in res.productDetails) {
      _details[d.id] = d;
    }
    return {for (final d in res.productDetails) d.id: d.price};
  }

  @override
  Stream<List<StoreUpdate>> get updates =>
      _store.purchaseStream.map((list) => [for (final p in list) _convert(p)]);

  StoreUpdate _convert(iap.PurchaseDetails p) {
    Future<void> complete() async {
      if (p.pendingCompletePurchase) await _store.completePurchase(p);
    }

    return switch (p.status) {
      iap.PurchaseStatus.restored => StoreUpdate(
        productId: p.productID,
        status: PurchaseStatus.success,
        restored: true,
        complete: complete,
      ),
      iap.PurchaseStatus.purchased => StoreUpdate(
        productId: p.productID,
        status: PurchaseStatus.success,
        complete: complete,
      ),
      iap.PurchaseStatus.canceled => StoreUpdate(
        productId: p.productID,
        status: PurchaseStatus.cancelled,
        complete: complete,
      ),
      iap.PurchaseStatus.error => StoreUpdate(
        productId: p.productID,
        status: PurchaseStatus.failed,
        complete: complete,
      ),
      // Waiting for the bank/parent approval: the final update comes later.
      iap.PurchaseStatus.pending => StoreUpdate(
        productId: p.productID,
        status: PurchaseStatus.unavailable,
      ),
    };
  }

  @override
  Future<bool> buy(String id, {required bool consumable}) {
    final d = _details[id];
    if (d == null) return Future.value(false);
    final param = iap.PurchaseParam(productDetails: d);
    return consumable
        ? _store.buyConsumable(purchaseParam: param)
        : _store.buyNonConsumable(purchaseParam: param);
  }

  @override
  Future<void> restore() => _store.restorePurchases();
}

/// Real Google Play / App Store purchases.
///
/// [available] stays false until the store answers *and* knows our
/// products, so a build whose products aren't set up yet in the consoles
/// simply shows the store as unavailable (nothing breaks, nothing is sold).
///
/// Purchases that finish outside a [buy] call (a pending payment approved
/// later, or one interrupted by an app kill) are passed to [onDelivered]
/// so the reward is still granted, then acknowledged.
class StorePaymentService implements PaymentService {
  StorePaymentService(
    this._gateway, {
    this.onDelivered,
    this.restoreWindow = const Duration(seconds: 4),
  });

  final StoreGateway _gateway;
  final Duration restoreWindow;

  /// Grants a purchase nobody was waiting for. Set by the provider.
  void Function(StoreProduct product)? onDelivered;

  final Map<String, String> _prices = {};
  final Map<StoreProduct, Completer<PurchaseResult>> _waiting = {};
  Set<StoreProduct>? _restoring;
  StreamSubscription<List<StoreUpdate>>? _sub;
  bool _ready = false;

  /// Connects to the store and loads prices. Safe to call once at start;
  /// failures leave the store unavailable.
  Future<void> init() async {
    _sub ??= _gateway.updates.listen(_onUpdates, onError: (_) {});
    try {
      if (!await _gateway.isAvailable()) return;
      _prices.addAll(
        await _gateway.queryPrices({for (final p in StoreProduct.values) p.id}),
      );
      _ready = _prices.isNotEmpty;
    } on Object catch (e) {
      debugPrint('store: init failed: $e');
    }
  }

  @override
  bool get available => _ready;

  @override
  bool get isTestStore => false;

  @override
  String? priceOf(StoreProduct p) => _prices[p.id];

  static StoreProduct? _product(String id) {
    for (final p in StoreProduct.values) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _onUpdates(List<StoreUpdate> updates) async {
    for (final u in updates) {
      final p = _product(u.productId);
      if (p == null) {
        await u.complete?.call();
        continue;
      }
      if (u.status == PurchaseStatus.unavailable) continue; // pending
      if (u.restored) {
        _restoring?.add(p);
        await u.complete?.call();
        continue;
      }
      final waiter = _waiting.remove(p);
      if (u.status == PurchaseStatus.success) {
        if (waiter != null) {
          waiter.complete(const PurchaseResult(PurchaseStatus.success));
        } else {
          onDelivered?.call(p);
        }
      } else {
        waiter?.complete(PurchaseResult(u.status));
      }
      // Acknowledge only after the reward is granted (above), so a crash
      // in between means the store re-delivers rather than the player
      // losing what they paid for.
      await u.complete?.call();
    }
  }

  @override
  Future<PurchaseResult> buy(StoreProduct p) async {
    if (!_ready || _prices[p.id] == null) {
      return const PurchaseResult(PurchaseStatus.unavailable);
    }
    if (_waiting.containsKey(p)) {
      return const PurchaseResult(PurchaseStatus.failed, 'Already buying');
    }
    final done = Completer<PurchaseResult>();
    _waiting[p] = done;
    try {
      if (!await _gateway.buy(p.id, consumable: p.consumable)) {
        _waiting.remove(p);
        return const PurchaseResult(PurchaseStatus.failed);
      }
    } on Object catch (e) {
      _waiting.remove(p);
      return PurchaseResult(PurchaseStatus.failed, '$e');
    }
    return done.future;
  }

  @override
  Future<Set<StoreProduct>> restore() async {
    if (!_ready) return const {};
    final found = _restoring = {};
    try {
      await _gateway.restore();
      // The store sends restored items on the purchase stream with no
      // "finished" signal, so collect for a short window.
      await Future<void>.delayed(restoreWindow);
    } on Object catch (e) {
      debugPrint('store: restore failed: $e');
    } finally {
      _restoring = null;
    }
    return found;
  }

  void dispose() => _sub?.cancel();
}
