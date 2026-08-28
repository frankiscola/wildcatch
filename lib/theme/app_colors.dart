import 'package:flutter/material.dart';

/// Palette ispirata alle schermate di menu e ai dialog box
/// di Pokemon Ruby/Sapphire/Emerald (Game Boy Advance, gen 3).
class AppColors {
  AppColors._();

  // Sfondo "cielo da percorso" usato nelle schermate principali
  static const routeSkyTop = Color(0xFF7EC8E3);
  static const routeSkyBottom = Color(0xFFBFE6C8);

  // Dialog box (il classico riquadro di testo bianco/crema con bordo scuro)
  static const dialogBackground = Color(0xFFF8F4E3);
  static const dialogBorderOuter = Color(0xFF2B2320);
  static const dialogBorderInner = Color(0xFF8B5A2B);
  static const dialogText = Color(0xFF2B2320);

  // Accento "Ruby"
  static const rubyRed = Color(0xFFB0281E);
  static const rubyRedDark = Color(0xFF7A1B14);

  // Accento "Sapphire"
  static const sapphireBlue = Color(0xFF1E4FB0);
  static const sapphireBlueDark = Color(0xFF12327A);

  // Pokeball
  static const pokeballRed = Color(0xFFE23E3E);
  static const pokeballDark = Color(0xFF1F1F1F);
  static const pokeballWhite = Color(0xFFF5F5F5);

  // UI generale
  static const panelCream = Color(0xFFFFF7E6);
  static const panelBrown = Color(0xFF4A342A);
  static const grassGreen = Color(0xFF4E9C4E);
  static const shadowSoft = Color(0x33000000);

  // Testo su sfondi scuri
  static const textOnDark = Color(0xFFF8F4E3);
  static const textMuted = Color(0xFF6B5B4B);
}

/// Colori ufficiali (approssimati) associati a ciascun tipo,
/// usati per i badge e i bordi delle card.
class TypeColors {
  TypeColors._();

  static const Map<String, Color> byName = {
    'normale': Color(0xFFA8A878),
    'fuoco': Color(0xFFF08030),
    'acqua': Color(0xFF6890F0),
    'elettro': Color(0xFFF8D030),
    'erba': Color(0xFF78C850),
    'ghiaccio': Color(0xFF98D8D8),
    'lotta': Color(0xFFC03028),
    'veleno': Color(0xFFA040A0),
    'terra': Color(0xFFE0C068),
    'volante': Color(0xFFA890F0),
    'psico': Color(0xFFF85888),
    'coleottero': Color(0xFFA8B820),
    'roccia': Color(0xFFB8A038),
    'spettro': Color(0xFF705898),
    'drago': Color(0xFF7038F8),
    'buio': Color(0xFF705848),
    'acciaio': Color(0xFFB8B8D0),
  };

  static Color of(String type) =>
      byName[type.toLowerCase()] ?? AppColors.textMuted;
}
