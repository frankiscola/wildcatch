/// Effectiveness table for the 11 final types in the game.
///
/// Each entry describes, from the DEFENDING type's point of view, how
/// it reacts when hit by a move of a given type:
///  - weakTo: types it's weak against (takes 2x damage)
///  - resists: types it resists (takes 0.5x damage)
///  - immuneTo: types it's immune to (takes 0x damage)
/// If an attacking type doesn't appear in any of the three lists, the
/// multiplier is 1x (no effect).
///
/// NOTE: if a Wildkin has two types, the multipliers from both types
/// are multiplied together (exactly like in the original games): a
/// Water move against a Fire/Rock target deals 2x * 2x = 4x damage.
class TypeChart {
  static const List<String> orderedTypes = [
    'fire', 'water', 'electric', 'grass', 'ice', 'poison',
    'ground', 'flying', 'psychic', 'rock', 'dark',
  ];

  static const Map<String, _TypeMatchups> _chart = {
    'fire': _TypeMatchups(
      weakTo: {'water', 'ground', 'rock'},
      resists: {'fire', 'grass', 'ice'},
    ),
    'water': _TypeMatchups(
      weakTo: {'electric', 'grass', 'ice'},
      resists: {'fire', 'water'},
    ),
    'electric': _TypeMatchups(
      weakTo: {'ground'},
      resists: {'electric', 'flying'},
    ),
    'grass': _TypeMatchups(
      weakTo: {'fire', 'poison', 'flying'},
      resists: {'water', 'electric', 'grass', 'ground'},
    ),
    'ice': _TypeMatchups(
      weakTo: {'fire', 'flying'},
      resists: {'ice'},
    ),
    'poison': _TypeMatchups(
      weakTo: {'ground', 'psychic'},
      resists: {'grass', 'poison', 'rock'},
    ),
    'ground': _TypeMatchups(
      weakTo: {'water', 'grass', 'ice'},
      resists: {'poison', 'rock'},
      immuneTo: {'electric'},
    ),
    'flying': _TypeMatchups(
      weakTo: {'electric', 'ice'},
      immuneTo: {'ground'},
    ),
    'psychic': _TypeMatchups(
      weakTo: {'dark', 'fire'},
      resists: {'psychic', 'ground'},
    ),
    'rock': _TypeMatchups(
      weakTo: {'water', 'grass'},
      resists: {'fire', 'flying'},
    ),
    'dark': _TypeMatchups(
      weakTo: {'psychic'},
      resists: {'dark'},
    ),
  };

  /// Readable view of the matchups, in [orderedTypes] order, for the
  /// in-app help screen. `_chart` stays private because only
  /// [effectiveness] uses it directly; this getter is the intended
  /// way for the rest of the app to read matchup data.
  static List<TypeMatchupInfo> get all => orderedTypes.map((type) {
        final matchups = _chart[type]!;
        return TypeMatchupInfo(
          type: type,
          weakTo: matchups.weakTo.toList()..sort(),
          resists: matchups.resists.toList()..sort(),
          immuneTo: matchups.immuneTo.toList()..sort(),
        );
      }).toList();

  /// Damage multiplier for a move of type [attackType] against a
  /// target with types [defenderTypes] (1 or 2 types).
  static double effectiveness(String attackType, List<String> defenderTypes) {
    var multiplier = 1.0;
    for (final defenderType in defenderTypes) {
      final matchups = _chart[defenderType.toLowerCase()];
      if (matchups == null) continue;

      final attack = attackType.toLowerCase();
      if (matchups.immuneTo.contains(attack)) {
        multiplier *= 0.0;
      } else if (matchups.weakTo.contains(attack)) {
        multiplier *= 2.0;
      } else if (matchups.resists.contains(attack)) {
        multiplier *= 0.5;
      }
      // otherwise 1x, no change
    }
    return multiplier;
  }

  /// Full matchup breakdown for a Wildkin with 1 or 2 types: which
  /// attacking types deal double/quadruple damage, which are
  /// resisted at half/quarter, and which are a full immunity.
  ///
  /// This is the single source of truth for anything that cares
  /// about x4 weaknesses/resistances (only possible with two types,
  /// when both are weak/resistant to the same attacking type):
  /// [EvolutionEngine] uses it to steer second-type selection away
  /// from the worst combos, [StatsEngine] uses it to grant a small
  /// defensive compensation, and the Field Journal UI uses it to
  /// show the player why a Wildkin struggles against certain types.
  static WildkinMatchups matchupsFor(List<String> defenderTypes) {
    final weakX2 = <String>[];
    final weakX4 = <String>[];
    final resistX2 = <String>[];
    final resistX4 = <String>[];
    final immune = <String>[];

    for (final attacker in orderedTypes) {
      final multiplier = effectiveness(attacker, defenderTypes);
      if (multiplier == 0.0) {
        immune.add(attacker);
      } else if (multiplier == 4.0) {
        weakX4.add(attacker);
      } else if (multiplier == 2.0) {
        weakX2.add(attacker);
      } else if (multiplier == 0.25) {
        resistX4.add(attacker);
      } else if (multiplier == 0.5) {
        resistX2.add(attacker);
      }
    }

    return WildkinMatchups(
      weakX2: weakX2,
      weakX4: weakX4,
      resistX2: resistX2,
      resistX4: resistX4,
      immune: immune,
    );
  }
}

/// Result of [TypeChart.matchupsFor]: every attacking type sorted
/// into the bucket that matches its multiplier against a given
/// Wildkin. `weakX4` and `resistX4` are only ever non-empty for
/// dual-type Wildkin.
class WildkinMatchups {
  final List<String> weakX2;
  final List<String> weakX4;
  final List<String> resistX2;
  final List<String> resistX4;
  final List<String> immune;

  const WildkinMatchups({
    required this.weakX2,
    required this.weakX4,
    required this.resistX2,
    required this.resistX4,
    required this.immune,
  });

  /// True if this type combination is a net defensive liability (more
  /// quadruple weaknesses than quadruple resistances to offset them).
  /// Used to decide whether a Wildkin deserves the small defensive
  /// compensation bonus on evolution.
  bool get hasNetQuadWeakness => weakX4.length > resistX4.length;
}

/// A type with its relationships (weak/resists/immune), in a public,
/// readable form: used by the help screen to build the table the
/// player sees.
class TypeMatchupInfo {
  final String type;
  final List<String> weakTo;
  final List<String> resists;
  final List<String> immuneTo;

  const TypeMatchupInfo({
    required this.type,
    required this.weakTo,
    required this.resists,
    required this.immuneTo,
  });
}

class _TypeMatchups {
  final Set<String> weakTo;
  final Set<String> resists;
  final Set<String> immuneTo;

  const _TypeMatchups({
    this.weakTo = const {},
    this.resists = const {},
    this.immuneTo = const {},
  });
}
