import 'dart:math';
import '../models/capture_context.dart';

/// Rule-based engine that assigns 1 or 2 types to a Wildkin based on
/// the capture context (weather, time, season, biome). Restricted to
/// the 11 types currently in the game (see TypeChart).
///
/// NOTE: this implementation also lives client-side purely to show an
/// instant preview ("you're about to meet a [fire]-type...") while
/// waiting for the real generation to finish. The authoritative
/// version, which determines the *final* type saved to the database,
/// MUST live in the Supabase edge function, so it can be updated
/// without shipping a new app build and so a tampered client can't
/// force a type.
class TypingEngine {
  final Random _random;

  TypingEngine({Random? random}) : _random = random ?? Random();

  /// Computes raw scores for each type, then draws 1 or 2 of them via
  /// weighted random selection.
  List<String> assignTypes(CaptureContext context) {
    final scores = _baseScores();

    _applyTemperature(scores, context.temperatureCelsius);
    _applyWeather(scores, context.weatherCondition);
    _applySeason(scores, context.season);
    _applyBiome(scores, context.biome);
    _applyTimeOfDay(scores, context.isNightTime);

    final primary = _weightedPick(scores);
    scores.remove(primary);

    // ~35% chance of getting a dual type
    final hasSecondType = _random.nextDouble() < 0.35;
    if (!hasSecondType || scores.isEmpty) return [primary];

    final secondary = _weightedPick(scores);
    return [primary, secondary];
  }

  Map<String, double> _baseScores() => {
        'fire': 3,
        'water': 3,
        'electric': 3,
        'grass': 3,
        'ice': 2,
        'poison': 2,
        'ground': 3,
        'flying': 3,
        'psychic': 2,
        'rock': 3,
        'dark': 2,
      };

  void _applyTemperature(Map<String, double> scores, double celsius) {
    if (celsius >= 30) {
      scores['fire'] = (scores['fire'] ?? 0) + 6;
      scores['ground'] = (scores['ground'] ?? 0) + 3;
    } else if (celsius >= 22) {
      scores['grass'] = (scores['grass'] ?? 0) + 3;
    } else if (celsius <= 5) {
      scores['ice'] = (scores['ice'] ?? 0) + 6;
    } else if (celsius <= 12) {
      scores['ice'] = (scores['ice'] ?? 0) + 2;
    }
  }

  void _applyWeather(Map<String, double> scores, String condition) {
    switch (condition) {
      case 'rain':
        scores['water'] = (scores['water'] ?? 0) + 6;
        break;
      case 'storm':
        scores['electric'] = (scores['electric'] ?? 0) + 7;
        scores['flying'] = (scores['flying'] ?? 0) + 2;
        break;
      case 'snow':
        scores['ice'] = (scores['ice'] ?? 0) + 7;
        break;
      case 'fog':
        scores['psychic'] = (scores['psychic'] ?? 0) + 4;
        scores['poison'] = (scores['poison'] ?? 0) + 3;
        break;
      case 'clear':
        scores['fire'] = (scores['fire'] ?? 0) + 1;
        scores['flying'] = (scores['flying'] ?? 0) + 2;
        break;
    }
  }

  void _applySeason(Map<String, double> scores, String season) {
    switch (season) {
      case 'summer':
        scores['fire'] = (scores['fire'] ?? 0) + 2;
        scores['ground'] = (scores['ground'] ?? 0) + 1;
        break;
      case 'winter':
        scores['ice'] = (scores['ice'] ?? 0) + 2;
        break;
      case 'spring':
        scores['grass'] = (scores['grass'] ?? 0) + 3;
        break;
      case 'fall':
        scores['ground'] = (scores['ground'] ?? 0) + 2;
        scores['dark'] = (scores['dark'] ?? 0) + 1;
        break;
    }
  }

  void _applyBiome(Map<String, double> scores, Biome biome) {
    switch (biome) {
      case Biome.sea:
        scores['water'] = (scores['water'] ?? 0) + 8;
        break;
      case Biome.mountain:
        scores['rock'] = (scores['rock'] ?? 0) + 8;
        scores['ground'] = (scores['ground'] ?? 0) + 3;
        break;
      case Biome.forest:
        scores['grass'] = (scores['grass'] ?? 0) + 6;
        break;
      case Biome.urbanCity:
        scores['electric'] = (scores['electric'] ?? 0) + 5;
        scores['rock'] = (scores['rock'] ?? 0) + 3;
        break;
      case Biome.plain:
        scores['grass'] = (scores['grass'] ?? 0) + 4;
        scores['ground'] = (scores['ground'] ?? 0) + 2;
        break;
      case Biome.desert:
        scores['ground'] = (scores['ground'] ?? 0) + 7;
        scores['fire'] = (scores['fire'] ?? 0) + 2;
        break;
      case Biome.unknown:
        break;
    }
  }

  void _applyTimeOfDay(Map<String, double> scores, bool isNight) {
    if (isNight) {
      scores['dark'] = (scores['dark'] ?? 0) + 6;
      scores['psychic'] = (scores['psychic'] ?? 0) + 4;
    } else {
      scores['flying'] = (scores['flying'] ?? 0) + 1;
    }
  }

  String _weightedPick(Map<String, double> scores) {
    final total = scores.values.fold<double>(0, (a, b) => a + b);
    var roll = _random.nextDouble() * total;
    for (final entry in scores.entries) {
      roll -= entry.value;
      if (roll <= 0) return entry.key;
    }
    return scores.keys.first;
  }
}
