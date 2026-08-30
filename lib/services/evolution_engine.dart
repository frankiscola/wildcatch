import 'dart:math';
import '../models/capture_context.dart';
import '../models/evolution_plan.dart';
import 'typing_engine.dart';

/// Decide, alla cattura, se una creatura avrà 1 o 2 evoluzioni
/// future (linea a 2 o 3 stadi) e a quale livello scatterà la
/// prossima. Gestisce anche l'assegnazione del secondo tipo quando
/// avviene la prima evoluzione, combinando il contesto di cattura
/// con quello del momento esatto dell'evoluzione.
///
/// I range di livello usati qui vivono in un unico posto:
/// [EvolutionRanges], dentro evolution_plan.dart. Così l'indizio
/// qualitativo mostrato al giocatore (calcolato in
/// [EvolutionPlan.timingHint]) e le soglie generate qui non possono
/// mai desincronizzarsi.
class EvolutionEngine {
  final Random _random;
  final TypingEngine _typingEngine;

  EvolutionEngine({Random? random, TypingEngine? typingEngine})
      : _random = random ?? Random(),
        _typingEngine = typingEngine ?? TypingEngine();

  /// Genera il piano evolutivo completo al momento della cattura.
  /// Il livello massimo è sempre 100; le soglie generate qui
  /// restano nascoste al giocatore (si mostra solo [EvolutionPlan.timingLabel]).
  EvolutionPlan createInitialPlan() {
    final totalStages = _random.nextBool() ? 2 : 3; // 50/50, personalizzabile

    if (totalStages == 2) {
      final level = _randomInRange(EvolutionRanges.onlyJumpOfTwoStage);
      return EvolutionPlan(
        totalStages: 2,
        currentStage: 1,
        nextEvolutionLevel: level,
      );
    }

    final firstLevel = _randomInRange(EvolutionRanges.firstJumpOfThreeStage);
    final secondLevel = _randomInRange(EvolutionRanges.secondJumpOfThreeStage);
    final adjustedSecond = max(secondLevel, firstLevel + 5);

    return EvolutionPlan(
      totalStages: 3,
      currentStage: 1,
      nextEvolutionLevel: firstLevel,
      secondEvolutionLevel: adjustedSecond,
    );
  }

  /// NOTA sul tipo del parametro: [LevelRange] è un record con campi
  /// NOMINATI (`{int min, int max}` tra graffe). Va sempre usato
  /// questo alias, e mai riscritto a mano come `(int min, int max)`
  /// senza graffe: quest'ultimo è un record POSIZIONALE diverso, dove
  /// `min`/`max` sono solo nomi documentali e `.min`/`.max` non sono
  /// campi accessibili (si accede con `.$1`/`.$2`). Scrivendolo senza
  /// graffe il codice compila comunque finché non lo si chiama con un
  /// valore come `(min: 15, max: 30)`, che invece È named: lì scatta
  /// il mismatch di tipo.
  int _randomInRange(LevelRange range) =>
      range.min + _random.nextInt(range.max - range.min + 1);

  /// true se, dato il livello raggiunto, la creatura deve evolvere ora.
  bool shouldEvolveNow(EvolutionPlan plan, int currentLevel) {
    final threshold = plan.nextEvolutionLevel;
    if (threshold == null) return false;
    return currentLevel >= threshold;
  }

  /// Determina il secondo tipo al momento dell'evoluzione, combinando:
  /// - i tipi già posseduti dalla creatura
  /// - il contesto della cattura originale
  /// - il contesto ATTUALE (meteo/posizione/ora di quando evolve)
  ///
  /// Il motore di tipizzazione viene interrogato due volte (una per
  /// il contesto di cattura, una per quello di evoluzione); i tipi
  /// candidati vengono poi ponderati e si sceglie il migliore tra
  /// quelli non già posseduti, dando peso a entrambi i momenti della
  /// vita della creatura, non solo all'ultimo.
  String determineSecondType({
    required List<String> existingTypes,
    required CaptureContext captureContext,
    required CaptureContext evolutionContext,
  }) {
    final captureTypes = _typingEngine.assignTypes(captureContext);
    final evolutionTypes = _typingEngine.assignTypes(evolutionContext);

    // 1 punto se il tipo compare tra i candidati del contesto di
    // cattura, 1.5 punti se compare in quello di evoluzione (pesiamo
    // leggermente di più il presente, perché è il momento in cui la
    // trasformazione avviene davvero).
    final scores = <String, double>{};
    for (final t in captureTypes) {
      if (existingTypes.contains(t)) continue;
      scores[t] = (scores[t] ?? 0) + 1.0;
    }
    for (final t in evolutionTypes) {
      if (existingTypes.contains(t)) continue;
      scores[t] = (scores[t] ?? 0) + 1.5;
    }

    if (scores.isEmpty) {
      // Fallback raro: nessun candidato nuovo, si ripesca dal motore
      // di tipizzazione usando solo il contesto di evoluzione finché
      // non esce un tipo diverso da quelli già posseduti.
      String candidate;
      do {
        candidate = _typingEngine.assignTypes(evolutionContext).first;
      } while (existingTypes.contains(candidate));
      return candidate;
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  /// Avanza il piano evolutivo di uno stadio dopo un'evoluzione.
  EvolutionPlan advance(EvolutionPlan plan) {
    final newStage = plan.currentStage + 1;
    if (newStage >= plan.totalStages) {
      return plan.copyWith(currentStage: newStage, clearNextEvolution: true);
    }
    return plan.copyWith(
      currentStage: newStage,
      nextEvolutionLevel: plan.secondEvolutionLevel,
    );
  }
}
