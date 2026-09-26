import 'package:flutter/material.dart';

/// Wildkin palette: a cool/warm split (forest/river blue on one
/// side, ember orange on the other) inspired by the app's logo, with
/// the low-res RPG "dialog box" look kept for text.
class AppColors {
  AppColors._();

  // "Route sky" background used in the main screens
  static const routeSkyTop = Color(0xFF4FB3E8);
  static const routeSkyBottom = Color(0xFFBFE6C8);

  // Dialog box (the classic light text box with a dark border)
  static const dialogBackground = Color(0xFFF8F4E3);
  static const dialogBorderOuter = Color(0xFF2B2320);
  static const dialogBorderInner = Color(0xFF8B5A2B);
  static const dialogText = Color(0xFF2B2320);

  // "Ember" accent (warm/orange side of the logo): urgent states,
  // errors, rejections.
  static const emberRed = Color(0xFFE8590C);
  static const emberRedDark = Color(0xFFB8420A);

  // "River" accent (cool/blue side of the logo): neutral/waiting
  // states.
  static const tidalBlue = Color(0xFF1C7ED6);
  static const tidalBlueDark = Color(0xFF14568F);

  // Capture scanner (a generic "capture orb" icon, an original
  // design, not modeled on any existing game's item)
  static const captureOrbRed = Color(0xFF2FA6A0);
  static const captureOrbDark = Color(0xFF1F1F1F);
  static const captureOrbWhite = Color(0xFFF5F5F5);
  static const captureOrbGold = Color(0xFFE8B23D);

  // General UI
  static const panelCream = Color(0xFFFFF7E6);
  static const panelBrown = Color(0xFF4A342A);
  static const grassGreen = Color(0xFF5CB338);
  static const shadowSoft = Color(0x33000000);

  // Text on dark backgrounds
  static const textOnDark = Color(0xFFF8F4E3);
  static const textMuted = Color(0xFF6B5B4B);

  /// The logo's diagonal cool→warm gradient, for "brand" screens
  /// (splash, onboarding, help header) where it makes sense to echo
  /// the app icon instead of the neutral dialog-box tones.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tidalBlue, emberRed],
  );
}

/// Original colors associated with each of the 11 types in the game,
/// used for badges and card borders. Deliberately NOT the same hex
/// values used by any existing game's type colors — this is our own
/// palette, chosen only to feel thematically fitting (fire = warm
/// orange, water = blue, etc.).
class TypeColors {
  TypeColors._();

  static const Map<String, Color> byName = {
    'fire': Color(0xFFE0632C),
    'water': Color(0xFF3E7FD1),
    'electric': Color(0xFFF2C230),
    'grass': Color(0xFF5FAE4A),
    'ice': Color(0xFF7ED4D6),
    'poison': Color(0xFF8E4A9E),
    'ground': Color(0xFFC9A24E),
    'flying': Color(0xFF8E9EE8),
    'psychic': Color(0xFFE0568F),
    'rock': Color(0xFF9E8C4A),
    'dark': Color(0xFF5A4C3E),
  };

  static Color of(String type) =>
      byName[type.toLowerCase()] ?? AppColors.textMuted;

  /// Soft themed background for the sprite stage — a light wash of
  /// the Wildkin's own type color(s) instead of a neutral panel, so
  /// e.g. an Ice Wildkin sits on a pale icy blue and an Electric one
  /// sits on a stormier, more saturated tone. Blends both colors
  /// diagonally when there are two types.
  static Gradient backgroundGradient(List<String> types) {
    if (types.isEmpty) {
      return const LinearGradient(colors: [AppColors.panelCream, AppColors.panelCream]);
    }
    final first = of(types.first);
    final second = types.length > 1 ? of(types[1]) : first;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(first, Colors.white, 0.72)!,
        Color.lerp(second, Colors.white, 0.32)!,
      ],
    );
  }
}
