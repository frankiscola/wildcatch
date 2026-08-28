import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Pillola colorata con il nome del tipo, come quelle mostrate
/// nella schermata riassuntiva del Pokemon nei giochi gen 3.
class TypeBadge extends StatelessWidget {
  final String type;

  const TypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = TypeColors.of(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppColors.dialogBorderOuter, width: 2),
      ),
      child: Text(
        type.toUpperCase(),
        style: AppFonts.pixelTitle(fontSize: 9, color: Colors.white),
      ),
    );
  }
}

/// Riga di badge, usata per mostrare 1 o 2 tipi assieme.
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
