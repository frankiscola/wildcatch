/// Path to the badge image for each type. Internal type keys stay in
/// Italian (matching the rest of the data model and the Supabase
/// schema), but the asset filenames themselves are in English to
/// match the source icon set. See assets/type_badges/.
class TypeBadgeAssets {
  TypeBadgeAssets._();

  static const Map<String, String> byName = {
    'fuoco': 'assets/type_badges/fire.png',
    'acqua': 'assets/type_badges/water.png',
    'elettro': 'assets/type_badges/electric.png',
    'erba': 'assets/type_badges/grass.png',
    'ghiaccio': 'assets/type_badges/ice.png',
    'veleno': 'assets/type_badges/poison.png',
    'terra': 'assets/type_badges/ground.png',
    'volante': 'assets/type_badges/flying.png',
    'psico': 'assets/type_badges/psychic.png',
    'roccia': 'assets/type_badges/rock.png',
    'buio': 'assets/type_badges/dark.png',
  };

  /// Returns the asset path, or null if the type isn't one of the 11
  /// (in that case the caller can fall back to TypeIcons/TypeColors).
  static String? of(String type) => byName[type.toLowerCase()];
}
