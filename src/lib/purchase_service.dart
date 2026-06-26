import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'ads.dart' show kProTierKey, setProUser;

/// The product ID for the one-time Pro unlock. This string MUST match exactly
/// the in-app product ID you create in the Google Play Console
/// (Monetize > Products > In-app products). It is a one-time, non-consumable
/// purchase, so we use buyNonConsumable + never consume it.
const String kProProductId = 'pro_unlock';

/// UI-facing status of the billing flow.
enum PurchaseStatusUi { idle, loading, available, unavailable, pending, purchased, error }

/// A small, self-contained billing service.
///
/// Lifecycle:
///   1. call [init] once at startup (sets up the purchase stream listener and
///      finishes any purchases that were left pending from a previous session).
///   2. call [loadProducts] to fetch localized price/title for the Pro product.
///   3. call [buyPro] when the user taps "Go Pro".
///   4. call [restore] for the "Restore purchases" button (required by stores).
///
/// On a successful purchase or restore it flips the local Pro flag
/// (the same [kProTierKey] the ads layer reads) so ads disappear immediately.
class PurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Whether billing is available on this device/build at all.
  final ValueNotifier<bool> available = ValueNotifier(false);

  /// The localized Pro product (price, title) once loaded, else null.
  final ValueNotifier<ProductDetails?> product = ValueNotifier(null);

  /// Current flow status, for showing spinners / messages.
  final ValueNotifier<PurchaseStatusUi> status =
      ValueNotifier(PurchaseStatusUi.idle);

  /// True once the user owns Pro.
  final ValueNotifier<bool> isPro = ValueNotifier(false);

  /// Last human-readable error, if any.
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  Future<void> init() async {
    final ok = await _iap.isAvailable();
    available.value = ok;
    if (!ok) {
      status.value = PurchaseStatusUi.unavailable;
      return;
    }

    // Listen for purchase updates. This fires for new purchases, restores,
    // and for purchases that completed while the app was closed.
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) {
        lastError.value = e.toString();
        status.value = PurchaseStatusUi.error;
      },
    );

    await loadProducts();
  }

  Future<void> loadProducts() async {
    if (!available.value) return;
    status.value = PurchaseStatusUi.loading;
    try {
      final response = await _iap.queryProductDetails({kProProductId});
      if (response.error != null) {
        lastError.value = response.error!.message;
        status.value = PurchaseStatusUi.error;
        return;
      }
      if (response.productDetails.isEmpty) {
        // Usually means the product ID isn't set up / app isn't on a Play
        // testing track yet. See README for the Play Console checklist.
        lastError.value =
            'Product "$kProProductId" not found. Check Play Console setup.';
        status.value = PurchaseStatusUi.unavailable;
        return;
      }
      product.value = response.productDetails.first;
      status.value = PurchaseStatusUi.available;
    } catch (e) {
      lastError.value = e.toString();
      status.value = PurchaseStatusUi.error;
    }
  }

  Future<void> buyPro() async {
    final p = product.value;
    if (p == null) {
      await loadProducts();
      if (product.value == null) return;
    }
    status.value = PurchaseStatusUi.pending;
    final param = PurchaseParam(productDetails: product.value!);
    // Non-consumable: a permanent unlock the user buys once.
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() async {
    status.value = PurchaseStatusUi.loading;
    await _iap.restorePurchases();
    // Results arrive via the purchase stream (_onPurchaseUpdates).
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          status.value = PurchaseStatusUi.pending;
          break;
        case PurchaseStatus.error:
          lastError.value = purchase.error?.message ?? 'Purchase failed';
          status.value = PurchaseStatusUi.error;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.productID == kProProductId) {
            // PRODUCTION: verify the purchase before granting entitlement.
            // Ideally validate purchase.verificationData against the Google
            // Play Developer API on your own server. For a local-only app you
            // can at least gate on a successful, completed purchase as below.
            await _grantPro();
          }
          break;
        case PurchaseStatus.canceled:
          status.value = PurchaseStatusUi.available;
          break;
      }

      // Always acknowledge/complete, or Google will refund after 3 days.
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _grantPro() async {
    await setProUser(true); // persists kProTierKey -> ads turn off
    isPro.value = true;
    status.value = PurchaseStatusUi.purchased;
  }

  void dispose() {
    _sub?.cancel();
  }
}
