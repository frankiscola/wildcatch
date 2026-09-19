import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wildkin.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/type_badge.dart';
import '../widgets/sprite_image.dart';
import '../providers/capture_flow_provider.dart';
import '../services/supabase_service.dart';
import 'result_screen.dart';

const int kMaxTeamSize = 4;

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wildkinAsync = ref.watch(myWildkinProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('MY TEAM')),
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: wildkinAsync.when(
              data: (all) {
                if (all.isEmpty) {
                  return const Center(
                    child: GbaDialogBox(
                      text: "You haven't caught any Wildkin yet. "
                          'Head back to the menu and take your first photo!',
                      fontSize: 16,
                    ),
                  );
                }

                final team = all.where((w) => w.isInTeam).toList();
                final bench = all.where((w) => !w.isInTeam).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TEAM (${team.length}/$kMaxTeamSize)',
                      style: AppFonts.pixelTitle(
                          fontSize: 12, color: AppColors.panelBrown),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'These are the Wildkin that will fight for you when you '
                      'run into an animal in the wild.',
                      style: AppFonts.body(
                          fontSize: 13, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: kMaxTeamSize,
                        itemBuilder: (context, index) {
                          if (index < team.length) {
                            return _TeamSlotCard(wildkin: team[index]);
                          }
                          return _EmptySlotCard(
                            onTap: bench.isEmpty
                                ? null
                                : () => _openPicker(context, ref, bench),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: GbaDialogBox(
                    text: 'Could not load your team: $error', fontSize: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPicker(BuildContext context, WidgetRef ref, List<Wildkin> bench) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _BenchPickerSheet(bench: bench, ref: ref),
    );
  }
}

class _TeamSlotCard extends StatelessWidget {
  final Wildkin wildkin;
  const _TeamSlotCard({required this.wildkin});

  @override
  Widget build(BuildContext context) {
    final stats = wildkin.computeStats();
    final fraction = stats.maxHp == 0
        ? 0.0
        : (wildkin.currentHp / stats.maxHp).clamp(0.0, 1.0);
    final hpColor = fraction > 0.5
        ? AppColors.grassGreen
        : (fraction > 0.2 ? const Color(0xFFE0A62B) : AppColors.emberRed);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(wildkin: wildkin, isNewCapture: false),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panelCream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.tidalBlue, width: 2),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 8,
                offset: Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: SpriteImage(url: wildkin.frontSpriteUrl),
            ),
            const SizedBox(height: 6),
            Text(
              '${wildkin.nickname}  ·  Lv.${wildkin.level}',
              style:
                  AppFonts.pixelTitle(fontSize: 8, color: AppColors.panelBrown),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            TypeBadgeRow(types: wildkin.types),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: AppColors.panelBrown.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(hpColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySlotCard extends StatelessWidget {
  final VoidCallback? onTap;
  const _EmptySlotCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panelCream.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.panelBrown.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                onTap == null ? Icons.lock_outline : Icons.add_circle_outline,
                size: 32,
                color: AppColors.panelBrown.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 6),
              Text(
                onTap == null ? 'Nothing to add' : 'Add Wildkin',
                style: AppFonts.body(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing every caught Wildkin NOT currently on the
/// team, so the player can fill an empty slot. Tapping one calls
/// [SupabaseService.setTeamMembership] and refreshes [myWildkinProvider];
/// if the trigger rejects it as full (a race with another device),
/// shows [TeamFullException]'s message instead of crashing.
class _BenchPickerSheet extends StatefulWidget {
  final List<Wildkin> bench;
  final WidgetRef ref;
  const _BenchPickerSheet({required this.bench, required this.ref});

  @override
  State<_BenchPickerSheet> createState() => _BenchPickerSheetState();
}

class _BenchPickerSheetState extends State<_BenchPickerSheet> {
  String? _pendingId;
  String? _errorMessage;

  Future<void> _add(Wildkin wildkin) async {
    setState(() {
      _pendingId = wildkin.id;
      _errorMessage = null;
    });
    try {
      await SupabaseService().setTeamMembership(id: wildkin.id, isInTeam: true);
      widget.ref.invalidate(myWildkinProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _pendingId = null;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CHOOSE A WILDKIN',
              style:
                  AppFonts.pixelTitle(fontSize: 12, color: AppColors.emberRed),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!,
                  style:
                      AppFonts.body(fontSize: 13, color: AppColors.emberRed)),
            ],
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.bench.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final wildkin = widget.bench[index];
                  return ListTile(
                    tileColor: AppColors.panelCream,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    leading: SizedBox(
                      width: 40,
                      height: 40,
                      child: SpriteImage(url: wildkin.frontSpriteUrl),
                    ),
                    title: Text('${wildkin.nickname} · Lv.${wildkin.level}'),
                    trailing: TypeBadgeRow(types: wildkin.types),
                    enabled: _pendingId == null,
                    onTap: () => _add(wildkin),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
