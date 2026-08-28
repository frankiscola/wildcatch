import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Font "titolo" in stile pixel, usato per titoli, pulsanti e badge.
/// Font "corpo" più leggibile per i testi lunghi nei dialog box.
class AppFonts {
  AppFonts._();

  static TextStyle pixelTitle({double fontSize = 16, Color? color}) =>
      GoogleFonts.pressStart2p(
        fontSize: fontSize,
        color: color ?? AppColors.dialogText,
        height: 1.4,
      );

  static TextStyle body({double fontSize = 16, Color? color, FontWeight? weight}) =>
      GoogleFonts.vt323(
        fontSize: fontSize,
        color: color ?? AppColors.dialogText,
        fontWeight: weight,
        height: 1.3,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.routeSkyBottom,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.sapphireBlue,
        secondary: AppColors.rubyRed,
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
          fontSize: 14,
          color: AppColors.textOnDark,
        ),
      ),
    );
  }
}
