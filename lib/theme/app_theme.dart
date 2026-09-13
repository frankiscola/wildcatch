import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// "Title" font: rounded, playful, retro menu style — not an 8-bit
/// pixel font, but something soft and readable that still "feels
/// like a game".
/// "Body" font: more conversational, used in dialog boxes and longer text.
///
/// The method is still called `pixelTitle` to avoid touching every
/// place in the app that already calls it: conceptually it now just
/// means "the titles/UI font", no longer literally pixel-styled.
class AppFonts {
  AppFonts._();

  static TextStyle pixelTitle({double fontSize = 16, Color? color}) =>
      GoogleFonts.baloo2(
        fontSize: fontSize * 1.25,
        color: color ?? AppColors.dialogText,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: 0.1,
      );

  static TextStyle body({double fontSize = 16, Color? color, FontWeight? weight}) =>
      GoogleFonts.nunito(
        fontSize: fontSize,
        color: color ?? AppColors.dialogText,
        fontWeight: weight ?? FontWeight.w600,
        height: 1.35,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.routeSkyBottom,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.tidalBlue,
        secondary: AppColors.emberRed,
        surface: AppColors.panelCream,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.dialogText,
        displayColor: AppColors.dialogText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.panelBrown,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppFonts.pixelTitle(
          fontSize: 13,
          color: AppColors.textOnDark,
        ),
      ),
    );
  }
}
