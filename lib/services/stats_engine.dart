import 'dart:math';
import '../models/stats.dart';

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
  BaseStats boostForEvolution(BaseStats current) {
    int boosted(int v) => (v * (1.1 + _random.nextDouble() * 0.1)).round();
    return BaseStats(
      hp: boosted(current.hp),
      attack: boosted(current.attack),
      defense: boosted(current.defense),
      insight: boosted(current.insight),
      ward: boosted(current.ward),
      speed: boosted(current.speed),
    );
  }
}
