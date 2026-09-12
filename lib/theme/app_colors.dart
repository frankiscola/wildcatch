import 'package:flutter/material.dart';

/// Palette WildKin: uno split freddo/caldo (blu foresta/fiume da un
/// lato, arancio brace dall'altro) ispirato al logo dell'app, con lo
/// stile "dialog box" da RPG a schermo basso mantenuto per i testi.
class AppColors {
  AppColors._();

  // Sfondo "cielo da percorso" usato nelle schermate principali
  static const routeSkyTop = Color(0xFF4FB3E8);
  static const routeSkyBottom = Color(0xFFBFE6C8);

  // Dialog box (il classico riquadro di testo chiaro con bordo scuro)
  static const dialogBackground = Color(0xFFF8F4E3);
  static const dialogBorderOuter = Color(0xFF2B2320);
  static const dialogBorderInner = Color(0xFF8B5A2B);
  static const dialogText = Color(0xFF2B2320);

  // Accento "brace" (lato caldo/arancio del logo): stati urgenti,
  // errori, rifiuti — tenuto sul nome storico rubyRed per non dover
  // toccare ogni punto della UI che già lo referenzia.
  static const rubyRed = Color(0xFFE8590C);
  static const rubyRedDark = Color(0xFFB8420A);

  // Accento "fiume" (lato freddo/blu del logo): stati neutri/di
  // attesa. Stesso discorso sul nome storico sapphireBlue.
  static const sapphireBlue = Color(0xFF1C7ED6);
  static const sapphireBlueDark = Color(0xFF14568F);

  // Pokeball (icona generica "sfera di cattura", nessun riferimento a
  // design esistenti: solo tre colori base rosso/bianco/nero)
  static const pokeballRed = Color(0xFFE23E3E);
  static const pokeballDark = Color(0xFF1F1F1F);
  static const pokeballWhite = Color(0xFFF5F5F5);

  // UI generale
  static const panelCream = Color(0xFFFFF7E6);
  static const panelBrown = Color(0xFF4A342A);
  static const grassGreen = Color(0xFF5CB338);
  static const shadowSoft = Color(0x33000000);

  // Testo su sfondi scuri
  static const textOnDark = Color(0xFFF8F4E3);
  static const textMuted = Color(0xFF6B5B4B);

  /// Il gradiente diagonale freddo→caldo del logo, per schermate
  /// "di marca" (splash, onboarding, header dell'help) dove ha senso
  /// richiamare l'icona dell'app invece dei toni neutri da dialog box.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sapphireBlue, rubyRed],
  );
}

/// Colori ufficiali (approssimati) associati a ciascun tipo,
/// usati per i badge e i bordi delle card.
class TypeColors {
  TypeColors._();

  static const Map<String, Color> byName = {
    'fuoco': Color(0xFFF08030),
    'acqua': Color(0xFF6890F0),
    'elettro': Color(0xFFF8D030),
    'erba': Color(0xFF78C850),
    'ghiaccio': Color(0xFF98D8D8),
    'veleno': Color(0xFFA040A0),
    'terra': Color(0xFFE0C068),
    'volante': Color(0xFFA890F0),
    'psico': Color(0xFFF85888),
    'roccia': Color(0xFFB8A038),
    'buio': Color(0xFF705848),
  };

  static Color of(String type) =>
      byName[type.toLowerCase()] ?? AppColors.textMuted;
}
