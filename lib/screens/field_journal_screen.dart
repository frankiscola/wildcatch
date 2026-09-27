import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/battle_log_entry.dart';
import '../models/wildkin.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/type_badge.dart';
import '../widgets/sprite_image.dart';
import '../providers/capture_flow_provider.dart';
import 'help_screen.dart';
import 'result_screen.dart';

/// Every Wildkin ever encountered: owned ones (from [myWildkinProvider])
/// shown in full color, plus wild ones that were fought but never
/// caught (from [battleLogsProvider]) shown as dimmed "seen" cards.
/// This is the app's default landing tab.
class FieldJournalScreen extends ConsumerWidget {
  const FieldJournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wildkinAsync = ref.watch(myWildkinProvider);
    final battleLogsAsync = ref.watch(battleLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FIELD JOURNAL'),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
        ],
      ),
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: wildkinAsync.when(
              data: (wildkinList) => battleLogsAsync.when(
                data: (logs) => _JournalGrid(wildkinList: wildkinList, logs: logs),
                loading: () => const Center(child: CircularProgressIndicator()),
                // A failure to load battle logs shouldn't hide the owned
                // Wildkin the player DOES have — degrade gracefully.
                error: (_, __) => _JournalGrid(wildkinList: wildkinList, logs: const []),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: GbaDialogBox(
                  text: 'Could not load the Field Journal: $error',
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

class _JournalGrid extends StatelessWidget {
  final List<Wildkin> wildkinList;
  final List<BattleLogEntry> logs;

  const _JournalGrid({required this.wildkinList, required this.logs});

  @override
  Widget build(BuildContext context) {
    final entries = <_JournalEntry>[
      ...wildkinList.map(_JournalEntry.owned),
      ...logs.map(_JournalEntry.seen),
    ];

    if (entries.isEmpty) {
      return const Center(
        child: GbaDialogBox(
          text: 'Nothing in your journal yet. '
              'Tap the camera button below to find your first Wildkin!',
          fontSize: 16,
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.85,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _JournalCard(entry: entries[index]),
    );
  }
}

/// Either an owned Wildkin or a merely-seen wild encounter — the grid
/// treats both uniformly, but renders them differently.
class _JournalEntry {
  final Wildkin? wildkin;
  final BattleLogEntry? sighting;

  const _JournalEntry.owned(Wildkin this.wildkin) : sighting = null;
  const _JournalEntry.seen(BattleLogEntry this.sighting) : wildkin = null;

  bool get isOwned => wildkin != null;
}

class _JournalCard extends StatelessWidget {
  final _JournalEntry entry;

  const _JournalCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final owned = entry.isOwned;

    return GestureDetector(
      onTap: owned
          ? () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ResultScreen(wildkin: entry.wildkin!)),
              )
          : () => _showSeenDialog(context, entry.sighting!),
      child: Container(
        decoration: BoxDecoration(
          color: owned ? AppColors.panelCream : AppColors.panelCream.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: owned ? null : Border.all(color: AppColors.textMuted, width: 1.5),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: owned
                  ? SpriteImage(url: entry.wildkin!.frontSpriteUrl)
                  : Opacity(
                      opacity: 0.5,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                        child: SpriteImage(url: entry.sighting!.photoUrl),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              owned ? entry.wildkin!.nickname : 'SEEN',
              style: AppFonts.pixelTitle(
                fontSize: 9,
                color: owned ? AppColors.panelBrown : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            TypeBadgeRow(types: owned ? entry.wildkin!.types : entry.sighting!.types),
          ],
        ),
      ),
    );
  }

  void _showSeenDialog(BuildContext context, BattleLogEntry log) {
    final outcomeLabel = switch (log.outcome) {
      'won' => 'You won the battle, but it got away before you could catch it.',
      'catch_failed' => 'You tried to catch it, but it broke free.',
      'fled' => 'You backed away from this one without a fight.',
      'lost' => 'This one bested you in battle.',
      _ => 'You crossed paths with this Wildkin.',
    };
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        title: Text('Lv.${log.level} Wildkin', style: AppFonts.pixelTitle(fontSize: 13)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TypeBadgeRow(types: log.types),
            const SizedBox(height: 10),
            Text(outcomeLabel, style: AppFonts.body(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}
