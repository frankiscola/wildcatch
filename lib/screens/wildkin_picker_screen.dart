import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wildkin.dart';
import '../models/wild_encounter.dart';
import '../providers/capture_flow_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/type_badge.dart';
import 'battle_screen.dart';

/// List of the player's own Wildkin, to pick who fights the wild
/// encounter that was just generated. Reached while a sighting is
/// still pending (confirmation window open): the countdown keeps
/// ticking in the background here too.
class WildkinPickerScreen extends ConsumerWidget {
  final WildEncounter wildEncounter;

  const WildkinPickerScreen({super.key, required this.wildEncounter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wildkinAsync = ref.watch(myWildkinProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('CHOOSE YOUR WILDKIN')),
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: wildkinAsync.when(
              data: (wildkinList) {
                final available =
                    wildkinList.where((w) => w.currentHp > 0).toList();
                if (available.isEmpty) {
                  return Center(
                    child: GbaDialogBox(
                      text: wildkinList.isEmpty
                          ? "You don't have any Wildkin yet. Catch one before you can battle!"
                          : 'All your Wildkin are worn out. Let one rest before heading back into battle.',
                      fontSize: 16,
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: available.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final wildkin = available[index];
                    return _WildkinTile(
                      wildkin: wildkin,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BattleScreen(
                            ownWildkin: wildkin,
                            initialWild: wildEncounter,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: GbaDialogBox(
                  text: 'Could not load your Wildkin: $error',
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WildkinTile extends StatelessWidget {
  final Wildkin wildkin;
  final VoidCallback onTap;

  const _WildkinTile({required this.wildkin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final maxHp = wildkin.computeStats().maxHp;
    final fraction =
        maxHp == 0 ? 0.0 : (wildkin.currentHp / maxHp).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panelCream,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 8,
                offset: Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Image.network(
                wildkin.frontSpriteUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.pets, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(wildkin.nickname,
                          style: AppFonts.pixelTitle(fontSize: 11)),
                      const SizedBox(width: 8),
                      Text('Lv.${wildkin.level}',
                          style: AppFonts.body(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TypeBadgeRow(types: wildkin.types),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(
                            height: 8,
                            color: AppColors.dialogBorderOuter
                                .withValues(alpha: 0.12)),
                        FractionallySizedBox(
                          widthFactor: fraction,
                          child: Container(
                            height: 8,
                            color: fraction > 0.5
                                ? AppColors.grassGreen
                                : (fraction > 0.2
                                    ? const Color(0xFFE0A62B)
                                    : AppColors.emberRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
