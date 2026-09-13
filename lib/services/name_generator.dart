import 'dart:math';

/// Builds a name by blending the detected species from the photo
/// (e.g. "cat") with the elemental type assigned to the Wildkin
/// (e.g. "fire"), using the same portmanteau idea as classic
/// monster-collecting RPGs (e.g. Char + Salamander = Charmander) —
/// with wording of our own, not borrowed from any existing game.
///
/// Purely rule/list based: no external calls, no cost, instant result.
class NameGenerator {
  final Random _random;

  NameGenerator({Random? random}) : _random = random ?? Random();

  // "Before the name" (prefix) and "after the name" (suffix)
  // fragments evocative of each type. If a type isn't in the list,
  // 'normal' is used as a fallback.
  static const Map<String, List<String>> _prefixes = {
    'fire': ['Pyro', 'Ember', 'Blaze', 'Cinder'],
    'water': ['Hydro', 'Aqua', 'Tide', 'Wave'],
    'grass': ['Flora', 'Verdi', 'Chloro', 'Bramble'],
    'electric': ['Volt', 'Spark', 'Amp', 'Static'],
    'ice': ['Cryo', 'Frost', 'Rime', 'Glacia'],
    'fighting': ['Fury', 'Brawn', 'Rally', 'Scrap'],
    'poison': ['Toxi', 'Venom', 'Acid', 'Blight'],
    'ground': ['Terra', 'Clay', 'Dune', 'Geo'],
    'flying': ['Aero', 'Plume', 'Gale', 'Wing'],
    'psychic': ['Psy', 'Mind', 'Dream', 'Aura'],
    'bug': ['Chit', 'Antenn', 'Larv', 'Elytra'],
    'rock': ['Boulder', 'Petra', 'Basalt', 'Flint'],
    'ghost': ['Spectr', 'Shade', 'Phantom', 'Ether'],
    'dragon': ['Draco', 'Wyrm', 'Scale', 'Fang'],
    'dark': ['Umbra', 'Night', 'Murk', 'Gloom'],
    'steel': ['Iron', 'Metal', 'Alloy', 'Plate'],
    'normal': ['Common', 'Rover', 'Field', 'Wild'],
  };

  static const Map<String, List<String>> _suffixes = {
    'fire': ['blaze', 'ember', 'scorch', 'flare'],
    'water': ['tide', 'wave', 'brook', 'flow'],
    'grass': ['leaf', 'vine', 'bloom', 'moss'],
    'electric': ['volt', 'surge', 'amp', 'spark'],
    'ice': ['frost', 'rime', 'chill', 'crystal'],
    'fighting': ['fist', 'strike', 'fury', 'force'],
    'poison': ['venom', 'toxin', 'blight', 'acid'],
    'ground': ['dust', 'sand', 'clay', 'stone'],
    'flying': ['wing', 'plume', 'gale', 'glide'],
    'psychic': ['mind', 'dream', 'aura', 'trance'],
    'bug': ['wing', 'shell', 'larva', 'antenna'],
    'rock': ['stone', 'boulder', 'flint', 'shard'],
    'ghost': ['shade', 'spectre', 'wisp', 'ether'],
    'dragon': ['fang', 'scale', 'wyrm', 'maw'],
    'dark': ['shade', 'night', 'gloom', 'murk'],
    'steel': ['iron', 'steel', 'plate', 'alloy'],
    'normal': ['roamer', 'wild', 'rover', 'free'],
  };

  /// [species] is the detected species (e.g. "cat"); if null or
  /// empty, "wildkin" is used as a neutral base. [types] are the
  /// types already assigned (only the first, the one owned at
  /// capture, is used).
  String generate(String? species, List<String> types) {
    final base = (species == null || species.trim().isEmpty)
        ? 'wildkin'
        : species.trim().toLowerCase();
    final stem = _stemOf(base);

    final primaryType = types.isNotEmpty ? types.first.toLowerCase() : 'normal';
    final prefixes = _prefixes[primaryType] ?? _prefixes['normal']!;
    final suffixes = _suffixes[primaryType] ?? _suffixes['normal']!;

    // 50/50 between "SpeciesSuffix" (e.g. Catblaze) and
    // "PrefixSpecies" (e.g. Hydrocat), for some variety.
    if (_random.nextBool()) {
      final suffix = suffixes[_random.nextInt(suffixes.length)];
      return _capitalize(stem) + suffix;
    } else {
      final prefix = prefixes[_random.nextInt(prefixes.length)];
      return prefix + _lowerFirst(stem);
    }
  }

  /// Trims a common trailing letter that would make the blend look
  /// awkward when a suffix is appended (e.g. a repeated vowel).
  /// Otherwise returns the species word as-is: English words don't
  /// need the vowel-stripping trick some other languages do.
  String _stemOf(String species) {
    if (species.length <= 3) return species;
    return species;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _lowerFirst(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}
