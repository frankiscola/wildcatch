/// Path to the badge image for each of the 11 types in the game.
/// See assets/type_badges/.
class TypeBadgeAssets {
  TypeBadgeAssets._();

  static const Map<String, String> byName = {
    'fire': 'assets/type_badges/fire.png',
    'water': 'assets/type_badges/water.png',
    'electric': 'assets/type_badges/electric.png',
    'grass': 'assets/type_badges/grass.png',
    'ice': 'assets/type_badges/ice.png',
    'poison': 'assets/type_badges/poison.png',
    'ground': 'assets/type_badges/ground.png',
    'flying': 'assets/type_badges/flying.png',
    'psychic': 'assets/type_badges/psychic.png',
    'rock': 'assets/type_badges/rock.png',
    'dark': 'assets/type_badges/dark.png',
  };

  /// Returns the asset path, or null if the type isn't one of the 11
  /// (in that case the caller can fall back to TypeIcons/TypeColors).
  static String? of(String type) => byName[type.toLowerCase()];
}
