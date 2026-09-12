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
/// NOTE: if a creature has two types, the multipliers from both types
/// are multiplied together (exactly like in the original games): a
/// Water move against a Fire/Rock target deals 2x * 2x = 4x damage.
class TypeChart {
  static const List<String> orderedTypes = [
    'fuoco', 'acqua', 'elettro', 'erba', 'ghiaccio', 'veleno',
    'terra', 'volante', 'psico', 'roccia', 'buio',
  ];

  static const Map<String, _TypeMatchups> _chart = {
    'fuoco': _TypeMatchups(
      weakTo: {'acqua', 'terra', 'roccia'},
      resists: {'fuoco', 'erba', 'ghiaccio'},
    ),
    'acqua': _TypeMatchups(
      weakTo: {'elettro', 'erba', 'ghiaccio'},
      resists: {'fuoco', 'acqua'},
    ),
    'elettro': _TypeMatchups(
      weakTo: {'terra'},
      resists: {'elettro', 'volante'},
    ),
    'erba': _TypeMatchups(
      weakTo: {'fuoco', 'veleno', 'volante'},
      resists: {'acqua', 'elettro', 'erba', 'terra'},
    ),
    'ghiaccio': _TypeMatchups(
      weakTo: {'fuoco', 'volante'},
      resists: {'ghiaccio'},
    ),
    'veleno': _TypeMatchups(
      weakTo: {'terra', 'psico'},
      resists: {'erba', 'veleno', 'roccia'},
    ),
    'terra': _TypeMatchups(
      weakTo: {'acqua', 'erba', 'ghiaccio'},
      resists: {'veleno', 'roccia'},
      immuneTo: {'elettro'},
    ),
    'volante': _TypeMatchups(
      weakTo: {'elettro', 'ghiaccio'},
      immuneTo: {'terra'},
    ),
    'psico': _TypeMatchups(
      weakTo: {'buio', 'fuoco'},
      resists: {'psico', 'terra'},
    ),
    'roccia': _TypeMatchups(
      weakTo: {'acqua', 'erba'},
      resists: {'fuoco', 'volante'},
    ),
    'buio': _TypeMatchups(
      weakTo: {'psico'},
      resists: {'buio'},
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
