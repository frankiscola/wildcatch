import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A single-select filter shown as a small pill that opens a bottom
/// sheet listing every option, instead of a horizontally scrolling
/// row of chips.
///
/// Chosen over inline chips for filters with many options (all types,
/// or a species list that keeps growing as the player photographs
/// more animals): a bottom sheet shows everything at once without
/// needing horizontal scrolling to discover options, and scales
/// gracefully as the option list grows.
///
/// Each option can show its own icon (the type's badge art, an animal
/// emoji...) via [iconBuilder] — falls back to a plain colored dot
/// from [colorFor] if no icon builder is given.
class DropdownFilter extends StatelessWidget {
  final String label;
  final String allLabel;
  final String? selected;
  final List<String> options;
  final Color Function(String option)? colorFor;
  final Widget Function(String option)? iconBuilder;
  final ValueChanged<String?> onChanged;

  const DropdownFilter({
    super.key,
    required this.label,
    required this.allLabel,
    required this.selected,
    required this.options,
    required this.onChanged,
    this.colorFor,
    this.iconBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor =
        selected != null && colorFor != null ? colorFor!(selected!) : AppColors.panelBrown;
    final displayLabel = selected == null
        ? allLabel
        : selected![0].toUpperCase() + selected!.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: displayColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: displayColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openPicker(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppFonts.pixelTitle(fontSize: 8, color: AppColors.textMuted)),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 100),
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
          ),
          // The clear ("x") button is its own tap target, separate
          // from the one that opens the sheet, and only shows once a
          // filter is actually active — resetting shouldn't require
          // opening the sheet just to tap "All" again.
          if (selected != null)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(null),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close, size: 15, color: displayColor),
              ),
            ),
        ],
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
                leading: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.panelBrown.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.apps, size: 16, color: AppColors.panelBrown),
                ),
                selected: selected == null,
                accentColor: AppColors.panelBrown,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onChanged(null);
                },
              ),
              const Divider(height: 1),
              for (final option in options)
                _OptionTile(
                  label: option[0].toUpperCase() + option.substring(1),
                  leading: iconBuilder != null
                      ? iconBuilder!(option)
                      : Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: colorFor?.call(option) ?? AppColors.panelBrown,
                            shape: BoxShape.circle,
                          ),
                        ),
                  selected: selected == option,
                  accentColor: colorFor?.call(option) ?? AppColors.panelBrown,
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
  final Widget leading;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.leading,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: leading,
      title: Text(label, style: AppFonts.body(fontSize: 15, color: AppColors.dialogText)),
      trailing: selected ? Icon(Icons.check, color: accentColor) : null,
    );
  }
}
