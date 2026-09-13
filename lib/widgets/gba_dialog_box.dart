import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A retro-styled text box: rounded corners, a night-blue gradient
/// border, a light cream background, and a soft shadow that makes it
/// "float" above the background, instead of the squared/pixel
/// double border used in older games.
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
          colors: [AppColors.tidalBlue, AppColors.tidalBlueDark],
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
