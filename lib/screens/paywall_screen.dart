import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/entitlement_status.dart';
import '../services/purchases_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pixel_button.dart';
import '../widgets/capture_spinner.dart';

/// Shown when the player runs out of captures/rerolls, or opened
/// directly from a "Go Plus" entry point elsewhere. Offers the
/// Wildkin Plus subscription (unlimited captures + rerolls) and
/// one-off token packs (a handful of extra captures/rerolls without
/// subscribing).
///
/// IMPORTANT: this screen only triggers purchases and shows their
/// immediate result. It never grants anything itself — the actual
/// unlock happens when revenuecat-webhook/index.ts processes the
/// purchase server-side and updates `profiles`. That can take a few
/// seconds, which is why this screen re-fetches entitlement status
/// after a purchase instead of assuming success means "done".
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  EntitlementStatus? _status;
  String? _loadError;
  bool _loading = true;
  String? _purchasingPackageId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        PurchasesService.getOfferings(),
        SupabaseService().getEntitlementStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _offerings = results[0] as Offerings;
        _status = results[1] as EntitlementStatus;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _purchase(Package package) async {
    setState(() => _purchasingPackageId = package.identifier);
    try {
      await PurchasesService.purchasePackage(package);
      // The webhook may take a moment to land — give it a beat before
      // re-checking, then show whatever's true at that point rather
      // than assuming the purchase alone means "unlocked".
      await Future.delayed(const Duration(seconds: 2));
      final status = await SupabaseService().getEntitlementStatus();
      if (!mounted) return;
      setState(() => _status = status);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Thanks! Syncing your purchase...")),
      );
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      // Not a real failure: the player just backed out of the sheet.
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) return;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Purchase failed: ${e.message ?? errorCode}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Purchase failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _purchasingPackageId = null);
    }
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    try {
      await PurchasesService.restorePurchases();
      final status = await SupabaseService().getEntitlementStatus();
      if (!mounted) return;
      setState(() => _status = status);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchases restored.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WILDKIN PLUS')),
      body: RouteBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CaptureSpinner())
              : _loadError != null
                  ? _ErrorState(message: _loadError!, onRetry: _load)
                  : _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final status = _status;
    final current = _offerings?.current;
    final subscriptionPackages = current?.availablePackages
            .where((p) => p.packageType != PackageType.lifetime &&
                !_isConsumable(p))
            .toList() ??
        const <Package>[];
    final tokenPackages =
        current?.availablePackages.where(_isConsumable).toList() ??
            const <Package>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (status != null) ...[
            GbaDialogBox(text: _statusLine(status), fontSize: 15),
            const SizedBox(height: 20),
          ],
          if (status?.isPremium != true) ...[
            Text('WILDKIN PLUS', style: AppFonts.pixelTitle(fontSize: 14)),
            const SizedBox(height: 10),
            Text(
              'Unlimited captures. Unlimited rerolls. No daily limit, ever.',
              textAlign: TextAlign.center,
              style: AppFonts.body(fontSize: 15, color: AppColors.panelBrown),
            ),
            const SizedBox(height: 16),
            if (subscriptionPackages.isEmpty)
              Text(
                'No subscription available right now.',
                style: AppFonts.body(fontSize: 14, color: AppColors.textMuted),
              )
            else
              ...subscriptionPackages.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PackageButton(
                    package: p,
                    busy: _purchasingPackageId == p.identifier,
                    background: AppColors.tidalBlue,
                    onPressed: () => _purchase(p),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
          Text('EXTRA TOKENS', style: AppFonts.pixelTitle(fontSize: 14)),
          const SizedBox(height: 10),
          Text(
            'One token = one extra capture, or one sprite reroll. No subscription needed.',
            textAlign: TextAlign.center,
            style: AppFonts.body(fontSize: 15, color: AppColors.panelBrown),
          ),
          const SizedBox(height: 16),
          if (tokenPackages.isEmpty)
            Text(
              'No token packs available right now.',
              style: AppFonts.body(fontSize: 14, color: AppColors.textMuted),
            )
          else
            ...tokenPackages.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PackageButton(
                  package: p,
                  busy: _purchasingPackageId == p.identifier,
                  background: AppColors.grassGreen,
                  onPressed: () => _purchase(p),
                ),
              ),
            ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _restore,
            child: Text(
              'Restore purchases',
              style: AppFonts.body(fontSize: 14, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  /// Consumables (token packs) are identified by RevenueCat package
  /// type NOT matching any subscription duration — RevenueCat has no
  /// built-in "this is a consumable" package type, so this relies on
  /// a naming convention: configure your token-pack product
  /// identifiers in RevenueCat/App Store Connect to start with
  /// "tokens_" (matching CONSUMABLE_TOKEN_PRODUCTS server-side in
  /// revenuecat-webhook/index.ts). Adjust this check if you name
  /// them differently.
  bool _isConsumable(Package p) => p.storeProduct.identifier.startsWith('tokens_');

  String _statusLine(EntitlementStatus status) {
    if (status.isPremium) return "You're on Wildkin Plus — unlimited captures and rerolls.";
    final free = status.freeCapturesRemaining ?? 0;
    return '$free free ${free == 1 ? 'capture' : 'captures'} left today · '
        '${status.captureTokens} token${status.captureTokens == 1 ? '' : 's'}';
  }
}

class _PackageButton extends StatelessWidget {
  final Package package;
  final bool busy;
  final Color background;
  final VoidCallback onPressed;

  const _PackageButton({
    required this.package,
    required this.busy,
    required this.background,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final product = package.storeProduct;
    return PixelButton(
      label: busy
          ? 'PURCHASING...'
          : '${product.title.isEmpty ? product.identifier : product.title} · ${product.priceString}',
      background: background,
      onPressed: busy ? null : onPressed,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GbaDialogBox(text: 'Could not load the store: $message', fontSize: 15),
            const SizedBox(height: 16),
            PixelButton(label: 'RETRY', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
