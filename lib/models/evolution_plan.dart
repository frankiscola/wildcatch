/// Categoria qualitativa mostrata al giocatore al posto del livello
/// esatto di evoluzione, per mantenere un po' di suspense.
enum EvolutionTiming { precoce, media, tardiva }

/// Range di livello (min/max). Usiamo un record con campi NOMINATI
/// (sintassi `{int min, int max}` tra graffe): è importante scrivere
/// il tipo così ovunque venga usato, perché un record posizionale
/// `(int min, int max)` (senza graffe) è un tipo diverso — i nomi in
/// quel caso sono solo documentazione e `.min`/`.max` non esistono.
typedef LevelRange = ({int min, int max});

/// Unica fonte di verità per i range di livello a cui possono
/// avvenire i salti evolutivi. Definiti qui (nel modello) e riusati
/// sia da [EvolutionPlan.timingHint] sia da `EvolutionEngine`, così
/// da non poterli mai desincronizzare tra loro.
class EvolutionRanges {
  EvolutionRanges._();

  /// Primo salto di una linea a 3 stadi (base -> stadio 2).
  static const LevelRange firstJumpOfThreeStage = (min: 15, max: 30);

  /// Secondo salto di una linea a 3 stadi (stadio 2 -> stadio 3).
  static const LevelRange secondJumpOfThreeStage = (min: 30, max: 50);

  /// Unico salto di una linea a 2 stadi (base -> evoluzione).
  static const LevelRange onlyJumpOfTwoStage = (min: 30, max: 50);
}

/// Il "destino" evolutivo di una creatura, deciso (in parte
/// casualmente) al momento della cattura e mai mostrato per intero:
/// il giocatore vede solo [totalStages] e un indizio qualitativo
/// sulla vicinanza della prossima evoluzione, non i livelli esatti.
class EvolutionPlan {
  /// 2 = un solo stadio successivo (base -> evoluzione).
  /// 3 = due stadi successivi (base -> stadio 2 -> stadio 3).
  final int totalStages;

  /// Stadio attuale, 1-based (1 = forma base appena catturata).
  final int currentStage;

  /// Livello a cui avverrà la prossima evoluzione. Null se la
  /// creatura ha già raggiunto lo stadio finale.
  final int? nextEvolutionLevel;

  /// Livello a cui avverrà l'evoluzione successiva alla prossima
  /// (rilevante solo per le linee a 3 stadi, quando si è ancora
  /// allo stadio 1). Serve per calcolare l'indizio del secondo salto
  /// senza doverlo rigenerare al momento della prima evoluzione.
  final int? secondEvolutionLevel;

  const EvolutionPlan({
    required this.totalStages,
    required this.currentStage,
    this.nextEvolutionLevel,
    this.secondEvolutionLevel,
  });

  bool get isFinalStage => currentStage >= totalStages;

  /// Indizio qualitativo sulla prossima evoluzione, calcolato in
  /// base a dove cade [nextEvolutionLevel] nel range possibile per
  /// lo stadio corrente. Non rivela mai il numero esatto.
  EvolutionTiming? timingHint() {
    final level = nextEvolutionLevel;
    if (level == null) return null;

    final range = currentStage == 1 && totalStages == 3
        ? EvolutionRanges.firstJumpOfThreeStage
        : EvolutionRanges.onlyJumpOfTwoStage;

    final span = range.max - range.min;
    final position = (level - range.min) / span;

    if (position <= 0.33) return EvolutionTiming.precoce;
    if (position <= 0.66) return EvolutionTiming.media;
    return EvolutionTiming.tardiva;
  }

  String timingLabel() {
    switch (timingHint()) {
      case EvolutionTiming.precoce:
        return 'Sembra pronto a evolversi presto';
      case EvolutionTiming.media:
        return 'Evolverà con un allenamento nella media';
      case EvolutionTiming.tardiva:
        return 'Ci vorrà parecchio allenamento prima che evolva';
      case null:
        return isFinalStage
            ? 'Ha raggiunto la sua forma finale'
            : 'Il suo destino evolutivo è un mistero';
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
