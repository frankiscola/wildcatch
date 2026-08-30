import 'dart:math';
import '../models/stats.dart';

/// Genera le statistiche base di una creatura alla cattura.
///
/// Le stat base restano fisse per tutta la vita della creatura
/// (fanno da "IV impliciti"): quelle effettive a un certo livello
/// si calcolano con [Creature.computeStats].
///
/// Ogni tipo ha un piccolo bonus tematico (es. roccia -> più difesa,
/// elettro -> più velocità) sommato a una base casuale, così due
/// creature con lo stesso tipo non sono mai identiche.
class StatsEngine {
  final Random _random;

  StatsEngine({Random? random}) : _random = random ?? Random();

  static const Map<String, Map<String, int>> _typeBias = {
    'fuoco': {'attack': 6, 'spAttack': 6, 'speed': 3},
    'acqua': {'defense': 4, 'spDefense': 5, 'hp': 3},
    'erba': {'spAttack': 4, 'spDefense': 4, 'hp': 3},
    'elettro': {'speed': 8, 'spAttack': 4},
    'ghiaccio': {'spDefense': 5, 'defense': 3},
    'lotta': {'attack': 8, 'hp': 4},
    'veleno': {'spAttack': 3, 'speed': 2},
    'terra': {'attack': 5, 'defense': 5},
    'volante': {'speed': 7, 'spAttack': 3},
    'psico': {'spAttack': 8, 'spDefense': 3},
    'coleottero': {'attack': 3, 'speed': 4},
    'roccia': {'defense': 9, 'hp': 3},
    'spettro': {'spAttack': 5, 'spDefense': 5},
    'drago': {'attack': 6, 'spAttack': 6, 'hp': 3},
    'buio': {'attack': 5, 'speed': 5},
    'acciaio': {'defense': 9, 'spDefense': 4},
    'normale': {'hp': 5},
  };

  BaseStats generate(List<String> types) {
    final values = {
      'hp': 20 + _random.nextInt(15),
      'attack': 15 + _random.nextInt(15),
      'defense': 15 + _random.nextInt(15),
      'spAttack': 15 + _random.nextInt(15),
      'spDefense': 15 + _random.nextInt(15),
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
      spAttack: values['spAttack']!,
      spDefense: values['spDefense']!,
      speed: values['speed']!,
    );
  }

  /// Alla prima evoluzione le stat base aumentano un po' (come
  /// accade cambiando "specie" nei giochi originali): +10-20% su
  /// ogni valore, arrotondato.
  BaseStats boostForEvolution(BaseStats current) {
    int boosted(int v) => (v * (1.1 + _random.nextDouble() * 0.1)).round();
    return BaseStats(
      hp: boosted(current.hp),
      attack: boosted(current.attack),
      defense: boosted(current.defense),
      spAttack: boosted(current.spAttack),
      spDefense: boosted(current.spDefense),
      speed: boosted(current.speed),
    );
  }
}
