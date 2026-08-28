import 'dart:math';
import '../models/capture_context.dart';

/// Motore di regole che assegna 1 o 2 tipi a una creatura in base
/// al contesto di cattura (meteo, ora, stagione, bioma).
///
/// NOTA: questa implementazione vive anche lato client solo per poter
/// mostrare un'anteprima istantanea ("stai per incontrare un tipo
/// [fuoco]...") mentre si aspetta la generazione vera e propria.
/// La versione autorevole, che determina il tipo *definitivo* salvato
/// nel database, DEVE vivere nella edge function Supabase, per poter
/// essere aggiornata senza rilasciare una nuova build dell'app e per
/// evitare che un client manomesso possa forzare un tipo.
class TypingEngine {
  final Random _random;

  TypingEngine({Random? random}) : _random = random ?? Random();

  /// Calcola i punteggi grezzi per ciascun tipo, poi ne estrae 1 o 2
  /// tramite selezione pesata casuale (weighted random pick).
  List<String> assignTypes(CaptureContext context) {
    final scores = _baseScores();

    _applyTemperature(scores, context.temperatureCelsius);
    _applyWeather(scores, context.weatherCondition);
    _applySeason(scores, context.season);
    _applyBiome(scores, context.biome);
    _applyTimeOfDay(scores, context.isNightTime);

    final primary = _weightedPick(scores);
    scores.remove(primary);

    // ~35% di probabilità di avere un doppio tipo
    final hasSecondType = _random.nextDouble() < 0.35;
    if (!hasSecondType || scores.isEmpty) return [primary];

    final secondary = _weightedPick(scores);
    return [primary, secondary];
  }

  Map<String, double> _baseScores() => {
        'normale': 5,
        'fuoco': 3,
        'acqua': 3,
        'elettro': 3,
        'erba': 3,
        'ghiaccio': 2,
        'terra': 3,
        'roccia': 3,
        'volante': 3,
        'spettro': 2,
        'buio': 2,
        'coleottero': 3,
      };

  void _applyTemperature(Map<String, double> scores, double celsius) {
    if (celsius >= 30) {
      scores['fuoco'] = (scores['fuoco'] ?? 0) + 6;
      scores['terra'] = (scores['terra'] ?? 0) + 3;
    } else if (celsius >= 22) {
      scores['erba'] = (scores['erba'] ?? 0) + 3;
      scores['coleottero'] = (scores['coleottero'] ?? 0) + 2;
    } else if (celsius <= 5) {
      scores['ghiaccio'] = (scores['ghiaccio'] ?? 0) + 6;
    } else if (celsius <= 12) {
      scores['ghiaccio'] = (scores['ghiaccio'] ?? 0) + 2;
    }
  }

  void _applyWeather(Map<String, double> scores, String condition) {
    switch (condition) {
      case 'rain':
        scores['acqua'] = (scores['acqua'] ?? 0) + 6;
        break;
      case 'storm':
        scores['elettro'] = (scores['elettro'] ?? 0) + 7;
        scores['volante'] = (scores['volante'] ?? 0) + 2;
        break;
      case 'snow':
        scores['ghiaccio'] = (scores['ghiaccio'] ?? 0) + 7;
        break;
      case 'fog':
        scores['spettro'] = (scores['spettro'] ?? 0) + 5;
        scores['veleno'] = (scores['veleno'] ?? 0) + 3;
        break;
      case 'clear':
        scores['fuoco'] = (scores['fuoco'] ?? 0) + 1;
        scores['volante'] = (scores['volante'] ?? 0) + 2;
        break;
    }
  }

  void _applySeason(Map<String, double> scores, String season) {
    switch (season) {
      case 'estate':
        scores['fuoco'] = (scores['fuoco'] ?? 0) + 2;
        scores['terra'] = (scores['terra'] ?? 0) + 1;
        break;
      case 'inverno':
        scores['ghiaccio'] = (scores['ghiaccio'] ?? 0) + 2;
        break;
      case 'primavera':
        scores['erba'] = (scores['erba'] ?? 0) + 3;
        scores['coleottero'] = (scores['coleottero'] ?? 0) + 2;
        break;
      case 'autunno':
        scores['terra'] = (scores['terra'] ?? 0) + 2;
        scores['buio'] = (scores['buio'] ?? 0) + 1;
        break;
    }
  }

  void _applyBiome(Map<String, double> scores, Biome biome) {
    switch (biome) {
      case Biome.mare:
        scores['acqua'] = (scores['acqua'] ?? 0) + 8;
        break;
      case Biome.montagna:
        scores['roccia'] = (scores['roccia'] ?? 0) + 8;
        scores['terra'] = (scores['terra'] ?? 0) + 3;
        break;
      case Biome.foresta:
        scores['erba'] = (scores['erba'] ?? 0) + 6;
        scores['coleottero'] = (scores['coleottero'] ?? 0) + 4;
        break;
      case Biome.cittaUrbana:
        scores['acciaio'] = (scores['acciaio'] ?? 0) + 5;
        scores['normale'] = (scores['normale'] ?? 0) + 3;
        break;
      case Biome.pianura:
        scores['normale'] = (scores['normale'] ?? 0) + 3;
        scores['erba'] = (scores['erba'] ?? 0) + 2;
        break;
      case Biome.deserto:
        scores['terra'] = (scores['terra'] ?? 0) + 7;
        scores['fuoco'] = (scores['fuoco'] ?? 0) + 2;
        break;
      case Biome.sconosciuto:
        break;
    }
  }

  void _applyTimeOfDay(Map<String, double> scores, bool isNight) {
    if (isNight) {
      scores['spettro'] = (scores['spettro'] ?? 0) + 4;
      scores['buio'] = (scores['buio'] ?? 0) + 5;
      scores['psico'] = (scores['psico'] ?? 0) + 2;
    } else {
      scores['normale'] = (scores['normale'] ?? 0) + 1;
      scores['volante'] = (scores['volante'] ?? 0) + 1;
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
