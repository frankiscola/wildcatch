import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Font "titolo": rotondo, giocoso, in stile menu di Ruby/Sapphire/
/// Emerald — non un font pixel 8-bit, ma qualcosa di morbido e
/// leggibile che comunque "sa di videogioco".
/// Font "corpo": più discorsivo, usato nei dialog box e nei testi lunghi.
///
/// Il nome del metodo è rimasto `pixelTitle` per non dover toccare
/// tutti i punti in cui viene già richiamato nell'app: concettualmente
/// ora indica semplicemente "il font dei titoli/UI", non più pixel.
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
          fontSize: 13,
          color: AppColors.textOnDark,
        ),
      ),
    );
  }
}
