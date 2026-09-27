import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';

/// Placeholder for online battles against other trainers. Real-time
/// matchmaking and turn synchronization (most likely via Supabase
/// Realtime channels) are a separate, sizeable feature that hasn't
/// been built yet — this screen exists so the nav entry has
/// somewhere honest to go, rather than a broken or faked feature.
class BattleOnlineScreen extends StatelessWidget {
  const BattleOnlineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ONLINE BATTLE')),
      body: RouteBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, size: 56, color: AppColors.panelCream),
                  const SizedBox(height: 16),
                  const GbaDialogBox(
                    text: 'Battling other trainers online is coming soon! '
                        'This will let you challenge friends with their '
                        'own teams in real time.',
                    fontSize: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
