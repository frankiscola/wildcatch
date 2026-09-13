import 'dart:math';
import '../models/capture_context.dart';
import '../models/evolution_plan.dart';
import 'typing_engine.dart';

/// Decides, at capture time, whether a Wildkin will have 1 or 2
/// future evolutions (a 2- or 3-stage line) and at which level the
/// next one will trigger. Also handles assigning the second type
/// when the first evolution happens, combining the capture context
/// with the context of the exact moment of evolution.
///
/// The level ranges used here live in a single place:
/// [EvolutionRanges], inside evolution_plan.dart. That way the
/// qualitative hint shown to the player (computed in
/// [EvolutionPlan.timingHint]) and the thresholds generated here can
/// never drift out of sync.
class EvolutionEngine {
  final Random _random;
  final TypingEngine _typingEngine;

  EvolutionEngine({Random? random, TypingEngine? typingEngine})
      : _random = random ?? Random(),
        _typingEngine = typingEngine ?? TypingEngine();

  /// Generates the full evolution plan at the moment of capture.
  /// The level cap is always 100; the thresholds generated here stay
  /// hidden from the player (only [EvolutionPlan.timingLabel] is shown).
  EvolutionPlan createInitialPlan() {
    final totalStages = _random.nextBool() ? 2 : 3; // 50/50, configurable

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

  /// NOTE on the parameter type: [LevelRange] is a record with NAMED
  /// fields (`{int min, int max}` in curly braces). Always use this
  /// alias, and never rewrite it by hand as `(int min, int max)`
  /// without braces: the latter is a different, POSITIONAL record,
  /// where `min`/`max` are just documentation and `.min`/`.max` are
  /// not accessible fields (you'd use `.$1`/`.$2` instead). Written
  /// without braces the code still compiles until it's called with a
  /// value like `(min: 15, max: 30)`, which IS named: that's where
  /// the type mismatch shows up.
  int _randomInRange(LevelRange range) =>
      range.min + _random.nextInt(range.max - range.min + 1);

  /// true if, given the level reached, the Wildkin should evolve now.
  bool shouldEvolveNow(EvolutionPlan plan, int currentLevel) {
    final threshold = plan.nextEvolutionLevel;
    if (threshold == null) return false;
    return currentLevel >= threshold;
  }

  /// Determines the second type at the moment of evolution, combining:
  /// - the types the Wildkin already has
  /// - the original capture context
  /// - the CURRENT context (weather/location/time at the moment it evolves)
  ///
  /// The typing engine is queried twice (once for the capture
  /// context, once for the evolution context); the candidate types
  /// are then weighted and the best one is picked among those not
  /// already owned, giving weight to both moments in the Wildkin's
  /// life, not just the most recent one.
  String determineSecondType({
    required List<String> existingTypes,
    required CaptureContext captureContext,
    required CaptureContext evolutionContext,
  }) {
    final captureTypes = _typingEngine.assignTypes(captureContext);
    final evolutionTypes = _typingEngine.assignTypes(evolutionContext);

    // 1 point if the type appears among the capture-context
    // candidates, 1.5 points if it appears in the evolution-context
    // ones (we weight the present moment slightly more, since that's
    // when the transformation actually happens).
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
      // Rare fallback: no new candidates, so we keep drawing from the
      // typing engine using only the evolution context until we get
      // a type different from the ones already owned.
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

  /// Advances the evolution plan by one stage after an evolution.
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
