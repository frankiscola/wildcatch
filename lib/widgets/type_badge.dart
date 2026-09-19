import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A rounded, colored pill with the type's name — a soft badge
/// style rather than a squared pixel-bordered one.
class TypeBadge extends StatelessWidget {
  final String type;

  const TypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = TypeColors.of(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        type.toUpperCase(),
        style: AppFonts.pixelTitle(fontSize: 8, color: Colors.white),
      ),
    );
  }
}

/// A type badge annotated with a damage multiplier (e.g. "FIRE x4"),
/// used to show a Wildkin's weaknesses/resistances. The x4/x0.25
/// entries (only possible with two types) get a bold outline so they
/// stand out from the plain x2/x0.5 ones at a glance.
class TypeMatchupBadge extends StatelessWidget {
  final String type;
  final String multiplierLabel; // e.g. "x2", "x4", "x0.5", "x0.25", "IMMUNE"
  final bool isDoubledUp; // true for x4 / x0.25, the two-type-only cases

  const TypeMatchupBadge({
    super.key,
    required this.type,
    required this.multiplierLabel,
    this.isDoubledUp = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = TypeColors.of(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
        border: isDoubledUp ? Border.all(color: Colors.white, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: isDoubledUp ? 6 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '${type.toUpperCase()} $multiplierLabel',
        style: AppFonts.pixelTitle(fontSize: 8, color: Colors.white),
      ),
    );
  }
}

/// A row of badges, used to show 1 or 2 types together.
class TypeBadgeRow extends StatelessWidget {
  final List<String> types;

  const TypeBadgeRow({super.key, required this.types});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: types.map((t) => TypeBadge(type: t)).toList(),
    );
  }
}
