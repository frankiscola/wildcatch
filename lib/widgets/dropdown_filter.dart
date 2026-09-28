import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A single-select filter shown as a small colored pill that opens a
/// bottom sheet listing every option, instead of a horizontally
/// scrolling row of chips.
///
/// Chosen over inline chips for filters with many options (all types,
/// or a species list that keeps growing as the player photographs
/// more animals): a bottom sheet shows everything at once without
/// needing horizontal scrolling to discover options, and scales
/// gracefully as the option list grows. The one thing it trades away
/// is seeing every option's color at a glance — partially recovered
/// here by coloring both the closed pill (by the current selection)
/// and every row inside the sheet.
class DropdownFilter extends StatelessWidget {
  final String label;
  final String allLabel;
  final String? selected;
  final List<String> options;
  final Color Function(String option)? colorFor;
  final ValueChanged<String?> onChanged;

  const DropdownFilter({
    super.key,
    required this.label,
    required this.allLabel,
    required this.selected,
    required this.options,
    required this.onChanged,
    this.colorFor,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor =
        selected != null && colorFor != null ? colorFor!(selected!) : AppColors.panelBrown;
    final displayLabel = selected == null
        ? allLabel
        : selected![0].toUpperCase() + selected!.substring(1);

    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: displayColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: displayColor.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppFonts.pixelTitle(fontSize: 8, color: AppColors.textMuted)),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                displayLabel.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: AppFonts.pixelTitle(fontSize: 9, color: displayColor),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, size: 16, color: displayColor),
          ],
        ),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _OptionTile(
                label: allLabel,
                color: AppColors.panelBrown,
                selected: selected == null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onChanged(null);
                },
              ),
              const Divider(height: 1),
              for (final option in options)
                _OptionTile(
                  label: option[0].toUpperCase() + option.substring(1),
                  color: colorFor?.call(option) ?? AppColors.panelBrown,
                  selected: selected == option,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onChanged(option);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(label, style: AppFonts.body(fontSize: 15, color: AppColors.dialogText)),
      trailing: selected ? Icon(Icons.check, color: color) : null,
    );
  }
}
