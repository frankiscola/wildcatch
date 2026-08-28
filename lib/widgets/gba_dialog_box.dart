import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Riquadro di testo con il doppio bordo tipico dei dialoghi
/// dei giochi GBA: bordo esterno scuro spesso, bordo interno
/// più chiaro, sfondo crema, angoli squadrati (non arrotondati).
class GbaDialogBox extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  final double fontSize;

  const GbaDialogBox({
    super.key,
    required this.text,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.dialogBackground,
        border: Border.all(color: AppColors.dialogBorderOuter, width: 4),
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.dialogBorderInner, width: 2),
        ),
        padding: padding,
        child: Text(
          text,
          style: AppFonts.body(fontSize: fontSize),
        ),
      ),
    );
  }
}
