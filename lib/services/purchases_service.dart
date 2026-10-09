import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Thin wrapper around the RevenueCat SDK. Keeps RevenueCat's
/// `appUserID` in lockstep with Supabase's `auth.uid()` — see
/// [logIn], which main.dart calls both at startup AND whenever
/// Supabase's auth state changes (linking an email, or recovering an
/// existing account on a new device can both change auth.uid()
/// mid-session; see email_auth_service.dart).
///
/// The actual granting of premium/tokens never happens here or
/// anywhere else client-side: this class only triggers purchases and
/// reads their immediate result for UI feedback. The source of truth
/// is the `profiles` table, written exclusively by
/// revenuecat-webhook/index.ts server-side — this class's
/// [isPremiumActive] check is a convenience for instant UI state
/// right after a purchase, not something the backend trusts.
class PurchasesService {
  static const String _entitlementId = 'premium';

  /// TODO: replace with your real RevenueCat public API keys
  /// (dashboard -> Project settings -> API keys). These are
  /// per-platform and safe to embed in the client (they're public
  /// keys, not secrets — the secret is the webhook Authorization
  /// header configured server-side, see revenuecat-webhook/index.ts).
  static const String _iosApiKey = 'appl_YOUR_IOS_API_KEY';
  static const String _androidApiKey = 'goog_lGfkaABsRZLNQQDVlKZcHPqRfpR';

  static Future<void> configure() async {
    await Purchases.setLogLevel(LogLevel.warn);

    final apiKey = Platform.isIOS ? _iosApiKey : _androidApiKey;
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  /// Logs RevenueCat in as the given Supabase user id. Safe to call
  /// repeatedly with the same id (RevenueCat no-ops in that case).
  static Future<void> logIn(String supabaseUserId) async {
    await Purchases.logIn(supabaseUserId);
  }

  static Future<Offerings> getOfferings() => Purchases.getOfferings();

  static Future<CustomerInfo> purchasePackage(Package package) async {
    final result = await Purchases.purchasePackage(package);
    return result.customerInfo;
  }

  static Future<CustomerInfo> restorePurchases() =>
      Purchases.restorePurchases();

  static Future<CustomerInfo> getCustomerInfo() => Purchases.getCustomerInfo();

  /// Convenience check for immediate post-purchase UI feedback ONLY.
  /// The capture flow itself never trusts this — see the class doc.
  static bool isPremiumActive(CustomerInfo info) {
    return info.entitlements.active.containsKey(_entitlementId);
  }
}
