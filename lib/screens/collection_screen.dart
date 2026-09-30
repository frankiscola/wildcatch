import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'result_screen.dart';

enum _SortMode { name, level }

/// Every Wildkin the player currently owns (team + bench together) —
/// distinct from the Field Journal, which also includes wild
/// encounters that were fought but never caught.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  String? _typeFilter; // null = all types
  _SortMode _sortMode = _SortMode.name;

  List<Wildkin> _applyFilterAndSort(List<Wildkin> source) {
    final filtered = _typeFilter == null
        ? source
        : source.where((w) => w.types.contains(_typeFilter)).toList();

    final sorted = [...filtered];
    switch (_sortMode) {
      case _SortMode.name:
        sorted.sort((a, b) => a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()));
      case _SortMode.level:
        sorted.sort((a, b) => b.level.compareTo(a.level)); // highest level first
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final wildkinAsync = ref.watch(myWildkinProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('COLLECTION')),
      body: RouteBackground(
        child: SafeArea(
          child: wildkinAsync.when(
            data: (wildkinList) {
              if (wildkinList.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: GbaDialogBox(
                      text: 'You haven\'t caught any Wildkin yet. '
                          'Tap the camera button below to take your first photo!',
                      fontSize: 16,
                    ),
                  ),
                );
              }

              final shown = _applyFilterAndSort(wildkinList);

              return Column(
                children: [
                  _FilterAndSortBar(
                    selectedType: _typeFilter,
                    onTypeSelected: (t) => setState(() => _typeFilter = t),
                    sortMode: _sortMode,
                    onSortChanged: (m) => setState(() => _sortMode = m),
                  ),
                  Expanded(
                    child: shown.isEmpty
                        ? Center(
                            child: GbaDialogBox(
                              text: 'No Wildkin match this filter.',
                              fontSize: 15,
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: shown.length,
                            itemBuilder: (context, index) => _WildkinCard(wildkin: shown[index]),
                          ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: GbaDialogBox(
                text: 'Could not load the Collection: $error',
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Type filter chips (scrollable, "All" + one per type) plus a
/// name/level sort toggle, shared visual language with the type
/// badges used everywhere else in the app.
class _FilterAndSortBar extends StatelessWidget {
  final String? selectedType;
  final ValueChanged<String?> onTypeSelected;
  final _SortMode sortMode;
  final ValueChanged<_SortMode> onSortChanged;

  const _FilterAndSortBar({
    required this.selectedType,
    required this.onTypeSelected,
    required this.sortMode,
    required this.onSortChanged,
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
        child: Row(
          children: [
            DropdownFilter(
              label: 'TYPE',
              allLabel: 'All types',
              selected: selectedType,
              options: TypeChart.orderedTypes,
              colorFor: TypeColors.of,
              iconBuilder: (type) => TypeOptionIcon(type: type),
              onChanged: onTypeSelected,
            ),
            const Spacer(),
            Text('SORT', style: AppFonts.pixelTitle(fontSize: 9, color: AppColors.textMuted)),
            const SizedBox(width: 10),
            _SortToggle(
              label: 'A–Z',
              selected: sortMode == _SortMode.name,
              onTap: () => onSortChanged(_SortMode.name),
            ),
            const SizedBox(width: 8),
            _SortToggle(
              label: 'LEVEL',
              selected: sortMode == _SortMode.level,
              onTap: () => onSortChanged(_SortMode.level),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortToggle({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.tidalBlue : AppColors.tidalBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: AppFonts.pixelTitle(fontSize: 8, color: selected ? Colors.white : AppColors.tidalBlue),
        ),
      ),
    );
  }
}

class _WildkinCard extends StatelessWidget {
  final Wildkin wildkin;

  const _WildkinCard({required this.wildkin});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultScreen(wildkin: wildkin)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panelCream,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 4)),
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
              wildkin.nickname,
              style: AppFonts.pixelTitle(fontSize: 9, color: AppColors.panelBrown),
            ),
            const SizedBox(height: 4),
            TypeBadgeRow(types: wildkin.types),
          ],
        ),
      ),
    );
  }
}
