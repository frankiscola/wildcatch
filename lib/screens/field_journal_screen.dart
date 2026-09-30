import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/battle_log_entry.dart';
import '../models/type_chart.dart';
import '../models/wildkin.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/type_badge.dart';
import '../widgets/sprite_image.dart';
import '../widgets/dropdown_filter.dart';
import '../widgets/option_icons.dart';
import '../providers/capture_flow_provider.dart';
import 'help_screen.dart';
import 'result_screen.dart';

enum _DateSort { newestFirst, oldestFirst }

/// Every Wildkin ever encountered: owned ones (from [myWildkinProvider])
/// shown in full color, plus wild ones that were fought but never
/// caught (from [battleLogsProvider]) shown as dimmed "seen" cards.
/// This is the app's default landing tab.
///
/// Deliberately leaner than the Collection: no level, no moves, no
/// "manage my team" actions — this is a log of encounters, not a
/// management screen. Tapping any card opens a small info popup
/// instead of the full detail screen; owned Wildkin get an extra
/// button in that popup to jump to the full screen if they want it,
/// merely-seen ones don't (there's nothing more to show for those).
class FieldJournalScreen extends ConsumerStatefulWidget {
  const FieldJournalScreen({super.key});

  @override
  ConsumerState<FieldJournalScreen> createState() => _FieldJournalScreenState();
}

class _FieldJournalScreenState extends ConsumerState<FieldJournalScreen> {
  String? _typeFilter;
  String? _speciesFilter;
  _DateSort _dateSort = _DateSort.newestFirst;

  @override
  Widget build(BuildContext context) {
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
          child: wildkinAsync.when(
            data: (wildkinList) => battleLogsAsync.when(
              data: (logs) => _buildBody(wildkinList, logs),
              loading: () => const Center(child: CircularProgressIndicator()),
              // A failure to load battle logs shouldn't hide the owned
              // Wildkin the player DOES have — degrade gracefully.
              error: (_, __) => _buildBody(wildkinList, const []),
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
    );
  }

  Widget _buildBody(List<Wildkin> wildkinList, List<BattleLogEntry> logs) {
    final allEntries = <_JournalEntry>[
      ...wildkinList.map(_JournalEntry.owned),
      ...logs.map(_JournalEntry.seen),
    ];

    if (allEntries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: GbaDialogBox(
            text: 'Nothing in your journal yet. '
                'Tap the camera button below to find your first Wildkin!',
            fontSize: 16,
          ),
        ),
      );
    }

    // Species options are derived from whatever data actually exists
    // (species isn't a fixed list — it comes from on-device animal
    // recognition), so the filter only ever offers choices that would
    // actually match something.
    final speciesOptions = allEntries
        .map((e) => e.speciesHint)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    var shown = allEntries;
    if (_typeFilter != null) {
      shown = shown.where((e) => e.types.contains(_typeFilter)).toList();
    }
    if (_speciesFilter != null) {
      shown = shown.where((e) => e.speciesHint == _speciesFilter).toList();
    }
    shown = [...shown]..sort((a, b) => _dateSort == _DateSort.newestFirst
        ? b.date.compareTo(a.date)
        : a.date.compareTo(b.date));

    return Column(
      children: [
        _JournalFilterBar(
          typeFilter: _typeFilter,
          onTypeChanged: (t) => setState(() => _typeFilter = t),
          speciesFilter: _speciesFilter,
          speciesOptions: speciesOptions,
          onSpeciesChanged: (s) => setState(() => _speciesFilter = s),
          dateSort: _dateSort,
          onDateSortChanged: (s) => setState(() => _dateSort = s),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(child: GbaDialogBox(text: 'Nothing matches this filter.', fontSize: 15))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (context, index) => _JournalCard(entry: shown[index]),
                ),
        ),
      ],
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
  List<String> get types => isOwned ? wildkin!.types : sighting!.types;
  String? get speciesHint => isOwned ? wildkin!.speciesHint : sighting!.speciesHint;
  DateTime get date => isOwned ? wildkin!.captureContext.capturedAt : sighting!.createdAt;
}

class _JournalFilterBar extends StatelessWidget {
  final String? typeFilter;
  final ValueChanged<String?> onTypeChanged;
  final String? speciesFilter;
  final List<String> speciesOptions;
  final ValueChanged<String?> onSpeciesChanged;
  final _DateSort dateSort;
  final ValueChanged<_DateSort> onDateSortChanged;

  const _JournalFilterBar({
    required this.typeFilter,
    required this.onTypeChanged,
    required this.speciesFilter,
    required this.speciesOptions,
    required this.onSpeciesChanged,
    required this.dateSort,
    required this.onDateSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.dialogBackground,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                DropdownFilter(
                  label: 'TYPE',
                  allLabel: 'All types',
                  selected: typeFilter,
                  options: TypeChart.orderedTypes,
                  colorFor: TypeColors.of,
                  iconBuilder: (type) => TypeOptionIcon(type: type),
                  onChanged: onTypeChanged,
                ),
                if (speciesOptions.isNotEmpty)
                  DropdownFilter(
                    label: 'ANIMAL',
                    allLabel: 'All animals',
                    selected: speciesFilter,
                    options: speciesOptions,
                    colorFor: (_) => AppColors.grassGreen,
                    iconBuilder: (species) => AnimalOptionIcon(species: species),
                    onChanged: onSpeciesChanged,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('SORT BY DATE', style: AppFonts.pixelTitle(fontSize: 9, color: AppColors.textMuted)),
                const SizedBox(width: 10),
                _Chip(
                  label: 'NEWEST',
                  selected: dateSort == _DateSort.newestFirst,
                  color: AppColors.tidalBlue,
                  onTap: () => onDateSortChanged(_DateSort.newestFirst),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'OLDEST',
                  selected: dateSort == _DateSort.oldestFirst,
                  color: AppColors.tidalBlue,
                  onTap: () => onDateSortChanged(_DateSort.oldestFirst),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final base = color ?? AppColors.panelBrown;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? base : base.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(label, style: AppFonts.pixelTitle(fontSize: 8, color: selected ? Colors.white : base)),
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final _JournalEntry entry;

  const _JournalCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final owned = entry.isOwned;

    return GestureDetector(
      onTap: () => _showInfoSheet(context),
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
            TypeBadgeRow(types: entry.types),
          ],
        ),
      ),
    );
  }

  /// The Journal's one and only tap destination: a short info popup,
  /// for BOTH owned and merely-seen entries. Owned ones get an extra
  /// button to open the full Collection-style detail screen; seen
  /// ones don't, because there's genuinely nothing more to show for
  /// an encounter you never caught.
  void _showInfoSheet(BuildContext context) {
    final owned = entry.isOwned;
    final outcomeLabel = owned
        ? null
        : switch (entry.sighting!.outcome) {
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
        title: Text(
          owned ? entry.wildkin!.nickname : 'Wild encounter',
          style: AppFonts.pixelTitle(fontSize: 13),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TypeBadgeRow(types: entry.types),
            const SizedBox(height: 10),
            Text(
              'Encountered ${_formatDate(entry.date)}',
              style: AppFonts.body(fontSize: 13, color: AppColors.textMuted),
            ),
            if (outcomeLabel != null) ...[
              const SizedBox(height: 8),
              Text(outcomeLabel, style: AppFonts.body(fontSize: 14)),
            ],
          ],
        ),
        actions: [
          if (owned)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ResultScreen(wildkin: entry.wildkin!)),
                );
              },
              child: const Text('FULL DETAILS'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
