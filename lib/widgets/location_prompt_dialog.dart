import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'pixel_button.dart';

/// Shown when the player tries to start a new capture but GPS is
/// turned off at the OS level. Location is required because it
/// feeds the whole capture context (weather lookup, biome estimate,
/// type assignment) — better to stop here than let the pipeline fail
/// with a generic error deep inside the capture flow.
///
/// Returns `true` if, by the time the dialog is dismissed, location
/// services are confirmed enabled (either the player already had
/// them on somehow, or they enabled them from Settings and came back
/// while this dialog was still showing).
Future<bool> showLocationRequiredDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _LocationRequiredDialog(),
  ).then((result) => result ?? false);
}

class _LocationRequiredDialog extends StatefulWidget {
  const _LocationRequiredDialog();

  @override
  State<_LocationRequiredDialog> createState() => _LocationRequiredDialogState();
}

class _LocationRequiredDialogState extends State<_LocationRequiredDialog>
    with WidgetsBindingObserver {
  bool _waitingForSettings = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// When the player backgrounds the app to open system Settings and
  /// comes back, this fires automatically — no need for them to tap
  /// a "try again" button themselves.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettings) {
      _waitingForSettings = false;
      _recheck();
    }
  }

  Future<void> _openSettings() async {
    _waitingForSettings = true;
    await Geolocator.openLocationSettings();
    // On some Android builds openLocationSettings resolves without
    // the app ever truly backgrounding, so also recheck right away
    // as a fallback to the lifecycle observer above.
    if (mounted) _recheck();
  }

  Future<void> _recheck() async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    setState(() => _checking = false);
    if (enabled) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.dialogBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowSoft, blurRadius: 14, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 48, color: AppColors.emberRed),
            const SizedBox(height: 16),
            Text(
              'LOCATION NEEDED',
              style: AppFonts.pixelTitle(fontSize: 14, color: AppColors.panelBrown),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Wildkin need your location to know the weather and terrain "
              "around you — that's what decides which type you'll find. "
              "Turn on GPS to keep exploring.",
              style: AppFonts.body(fontSize: 16, color: AppColors.panelBrown),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            PixelButton(
              label: _checking ? 'CHECKING...' : 'OPEN SETTINGS',
              icon: Icons.settings,
              background: AppColors.tidalBlue,
              onPressed: _checking ? null : _openSettings,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: AppFonts.body(fontSize: 15, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
