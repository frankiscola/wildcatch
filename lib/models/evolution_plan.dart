/// Qualitative category shown to the player instead of the exact
/// evolution level, to keep a bit of suspense.
enum EvolutionTiming { early, average, late }

/// Level range (min/max). We use a record with NAMED fields
/// (the `{int min, int max}` curly-brace syntax): it's important to
/// write the type this way everywhere it's used, because a
/// positional record `(int min, int max)` (without braces) is a
/// different type — the names in that case are just documentation
/// and `.min`/`.max` don't exist.
typedef LevelRange = ({int min, int max});

/// Single source of truth for the level ranges at which evolution
/// jumps can happen. Defined here (in the model) and reused by both
/// [EvolutionPlan.timingHint] and `EvolutionEngine`, so they can
/// never drift out of sync with each other.
class EvolutionRanges {
  EvolutionRanges._();

  /// First jump of a 3-stage line (base -> stage 2).
  static const LevelRange firstJumpOfThreeStage = (min: 15, max: 30);

  /// Second jump of a 3-stage line (stage 2 -> stage 3).
  static const LevelRange secondJumpOfThreeStage = (min: 30, max: 50);

  /// Only jump of a 2-stage line (base -> evolution).
  static const LevelRange onlyJumpOfTwoStage = (min: 30, max: 50);
}

/// A Wildkin's evolutionary "fate", decided (partly at random) at
/// capture time and never fully revealed: the player only sees
/// [totalStages] and a qualitative hint about how close the next
/// evolution is, never the exact levels.
class EvolutionPlan {
  /// 2 = a single following stage (base -> evolution).
  /// 3 = two following stages (base -> stage 2 -> stage 3).
  final int totalStages;

  /// Current stage, 1-based (1 = base form, just captured).
  final int currentStage;

  /// Level at which the next evolution will happen. Null if the
  /// Wildkin has already reached its final stage.
  final int? nextEvolutionLevel;

  /// Level at which the evolution *after* the next one will happen
  /// (only relevant for 3-stage lines, while still at stage 1).
  /// Used to compute the second jump's hint without having to
  /// regenerate it at the moment of the first evolution.
  final int? secondEvolutionLevel;

  const EvolutionPlan({
    required this.totalStages,
    required this.currentStage,
    this.nextEvolutionLevel,
    this.secondEvolutionLevel,
  });

  bool get isFinalStage => currentStage >= totalStages;

  /// Qualitative hint about the next evolution, computed from where
  /// [nextEvolutionLevel] falls within the possible range for the
  /// current stage. Never reveals the exact number.
  EvolutionTiming? timingHint() {
    final level = nextEvolutionLevel;
    if (level == null) return null;

    final range = currentStage == 1 && totalStages == 3
        ? EvolutionRanges.firstJumpOfThreeStage
        : EvolutionRanges.onlyJumpOfTwoStage;

    final span = range.max - range.min;
    final position = (level - range.min) / span;

    if (position <= 0.33) return EvolutionTiming.early;
    if (position <= 0.66) return EvolutionTiming.average;
    return EvolutionTiming.late;
  }

  String timingLabel() {
    switch (timingHint()) {
      case EvolutionTiming.early:
        return 'Looks ready to evolve soon';
      case EvolutionTiming.average:
        return 'Will evolve with an average amount of training';
      case EvolutionTiming.late:
        return 'It will take a lot of training before it evolves';
      case null:
        return isFinalStage
            ? 'It has reached its final form'
            : 'Its evolutionary fate is a mystery';
    }
  }

  EvolutionPlan copyWith({
    int? currentStage,
    int? nextEvolutionLevel,
    int? secondEvolutionLevel,
    bool clearNextEvolution = false,
  }) {
    return EvolutionPlan(
      totalStages: totalStages,
      currentStage: currentStage ?? this.currentStage,
      nextEvolutionLevel:
          clearNextEvolution ? null : (nextEvolutionLevel ?? this.nextEvolutionLevel),
      secondEvolutionLevel: secondEvolutionLevel ?? this.secondEvolutionLevel,
    );
  }

  Map<String, dynamic> toJson() => {
        'total_stages': totalStages,
        'current_stage': currentStage,
        'next_evolution_level': nextEvolutionLevel,
        'second_evolution_level': secondEvolutionLevel,
      };

  factory EvolutionPlan.fromJson(Map<String, dynamic> json) => EvolutionPlan(
        totalStages: json['total_stages'] as int,
        currentStage: json['current_stage'] as int,
        nextEvolutionLevel: json['next_evolution_level'] as int?,
        secondEvolutionLevel: json['second_evolution_level'] as int?,
      );
}
