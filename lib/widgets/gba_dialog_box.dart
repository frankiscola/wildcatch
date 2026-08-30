import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Riquadro di testo in stile RSE: angoli arrotondati, bordo
/// sfumato blu-notte, sfondo crema chiaro e un'ombra morbida che
/// lo fa "galleggiare" sopra lo sfondo, invece del doppio bordo
/// squadrato/pixel usato nei giochi più vecchi.
class GbaDialogBox extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  final double fontSize;

  const GbaDialogBox({
    super.key,
    required this.text,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.sapphireBlue, AppColors.sapphireBlueDark],
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3.5),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.dialogBackground,
          borderRadius: BorderRadius.circular(17),
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
