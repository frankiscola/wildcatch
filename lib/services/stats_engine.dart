import 'dart:math';
import '../models/stats.dart';
import '../models/type_chart.dart';

/// Generates a Wildkin's base stats at capture time.
///
/// Base stats stay fixed for the Wildkin's whole life (they act as
/// an "implicit Potential Score"): the effective values at a given
/// level are computed by [Wildkin.computeStats].
///
/// Each type has a small thematic bonus (e.g. rock -> more defense,
/// electric -> more speed) added on top of a random baseline, so two
/// Wildkin of the same type are never identical.
class StatsEngine {
  final Random _random;

  StatsEngine({Random? random}) : _random = random ?? Random();

  static const Map<String, Map<String, int>> _typeBias = {
    'fire': {'attack': 6, 'insight': 6, 'speed': 3},
    'water': {'defense': 4, 'ward': 5, 'hp': 3},
    'grass': {'insight': 4, 'ward': 4, 'hp': 3},
    'electric': {'speed': 8, 'insight': 4},
    'ice': {'ward': 5, 'defense': 3},
    'poison': {'insight': 3, 'speed': 2},
    'ground': {'attack': 5, 'defense': 5},
    'flying': {'speed': 7, 'insight': 3},
    'psychic': {'insight': 8, 'ward': 3},
    'rock': {'defense': 9, 'hp': 3},
    'dark': {'attack': 5, 'speed': 5},
  };

  BaseStats generate(List<String> types) {
    final values = {
      'hp': 20 + _random.nextInt(15),
      'attack': 15 + _random.nextInt(15),
      'defense': 15 + _random.nextInt(15),
      'insight': 15 + _random.nextInt(15),
      'ward': 15 + _random.nextInt(15),
      'speed': 15 + _random.nextInt(15),
    };

    for (final type in types) {
      final bias = _typeBias[type.toLowerCase()];
      if (bias == null) continue;
      bias.forEach((stat, bonus) {
        values[stat] = (values[stat] ?? 0) + bonus;
      });
    }

    return BaseStats(
      hp: values['hp']!,
      attack: values['attack']!,
      defense: values['defense']!,
      insight: values['insight']!,
      ward: values['ward']!,
      speed: values['speed']!,
    );
  }

  /// At the first evolution, base stats increase a bit (as happens
  /// when "species" changes in the classic games): +10-20% on each
  /// value, rounded.
  ///
  /// If [types] is passed (the Wildkin's types AFTER this evolution)
  /// and [TypeChart.matchupsFor] finds a net defensive liability
  /// (more x4 weaknesses than x4 resistances — see
  /// [WildkinMatchups.hasNetQuadWeakness]), a small extra bonus is
  /// applied to the purely defensive stats (HP/defense/ward) only.
  /// This is deliberately NOT applied to attack/insight/speed: the
  /// goal is to help a Wildkin survive the hits it's especially
  /// vulnerable to, not to make it hit harder — and it's meant as a
  /// light compensation on top of [EvolutionEngine]'s own risk-aware
  /// selection, not a replacement for it. A combo can still end up
  /// risky (rarely, on purpose); this just softens the impact.
  BaseStats boostForEvolution(BaseStats current, {List<String>? types}) {
    int boosted(int v) => (v * (1.1 + _random.nextDouble() * 0.1)).round();

    var hp = boosted(current.hp);
    var attack = boosted(current.attack);
    var defense = boosted(current.defense);
    var insight = boosted(current.insight);
    var ward = boosted(current.ward);
    var speed = boosted(current.speed);

    if (types != null && TypeChart.matchupsFor(types).hasNetQuadWeakness) {
      const compensation = 1.08;
      hp = (hp * compensation).round();
      defense = (defense * compensation).round();
      ward = (ward * compensation).round();
    }

    return BaseStats(
      hp: hp,
      attack: attack,
      defense: defense,
      insight: insight,
      ward: ward,
      speed: speed,
    );
  }
}
