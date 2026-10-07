import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../db/database_helper.dart';

class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  static const productId = 'com.thilina.budgie.premium';

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // ── Local state ───────────────────────────────────────────────────────────

  Future<bool> isPremium() async {
    final v = await DatabaseHelper.instance.getSetting('is_premium', '');
    return v == '1';
  }

  Future<void> _setPremium(bool value) =>
      DatabaseHelper.instance.setSetting('is_premium', value ? '1' : '0');

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Call once from main() or app init to start listening for purchase updates.
  void initialize() {
    _subscription?.cancel();
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) => debugPrint('PremiumService purchaseStream error: $e'),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  // ── Purchase ──────────────────────────────────────────────────────────────

  /// Returns false if the store is unavailable.
  Future<bool> buy() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) return false;

    final response = await InAppPurchase.instance
        .queryProductDetails({productId});
    if (response.productDetails.isEmpty) return false;

    final param = PurchaseParam(
        productDetails: response.productDetails.first);
    return InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  /// Restores previously purchased products.
  Future<void> restore() =>
      InAppPurchase.instance.restorePurchases();

  // ── Purchase stream handler ───────────────────────────────────────────────

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != productId) continue;

      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        await _setPremium(true);
      } else if (p.status == PurchaseStatus.error) {
        debugPrint('PremiumService purchase error: ${p.error}');
      }

      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
    }
  }
}
