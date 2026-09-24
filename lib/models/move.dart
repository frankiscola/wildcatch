/// A move's category, as in the original games.
enum MoveCategory { physical, special, status }

/// A move a Wildkin can know. The stats (power, accuracy, PP)
/// mirror the classic format, extended with a few original
/// mechanics that lean on this app's real-world context (weather,
/// time of day) and on the Wildkin's own physique — see the
/// nullable fields below. A move has at most one of these active.
class Move {
  final String name;
  final String type;
  final MoveCategory category;
  final int power; // 0 for status moves
  final int accuracy; // 0-100
  final int maxPp;
  final int tier; // 1 (weakest) .. 5 (strongest)
  final int minLevel; // level at which this move can first be learned

  /// If set, this move deals [weatherBonusPct]% more damage when the
  /// REAL weather at battle time matches this affinity (resolved by
  /// the battle engine against live weather data, not stored here).
  final String? weatherAffinity;
  final int? weatherBonusPct;

  /// If set, boosted by [timeBonusPct]% when the battle happens at
  /// that real time of day ("night" or "dawn").
  final String? timeAffinity;
  final int? timeBonusPct;

  /// If set, this move has a [statusChancePct]% chance to inflict
  /// the named status (see StatusEffect) on the target.
  final String? inflictsStatus;
  final int? statusChancePct;

  /// If true, this move's damage scales up against heavier targets
  /// (see WildkinPhysique.weightKg).
  final bool scalesWithTargetWeight;

  const Move({
    required this.name,
    required this.type,
    required this.category,
    required this.power,
    required this.accuracy,
    required this.maxPp,
    required this.tier,
    this.minLevel = 1,
    this.weatherAffinity,
    this.weatherBonusPct,
    this.timeAffinity,
    this.timeBonusPct,
    this.inflictsStatus,
    this.statusChancePct,
    this.scalesWithTargetWeight = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'category': category.name,
        'power': power,
        'accuracy': accuracy,
        'max_pp': maxPp,
        'tier': tier,
        'min_level': minLevel,
        if (weatherAffinity != null) 'weather_affinity': weatherAffinity,
        if (weatherBonusPct != null) 'weather_bonus_pct': weatherBonusPct,
        if (timeAffinity != null) 'time_affinity': timeAffinity,
        if (timeBonusPct != null) 'time_bonus_pct': timeBonusPct,
        if (inflictsStatus != null) 'inflicts_status': inflictsStatus,
        if (statusChancePct != null) 'status_chance_pct': statusChancePct,
        if (scalesWithTargetWeight) 'scales_with_target_weight': true,
      };

  factory Move.fromJson(Map<String, dynamic> json) => Move(
        name: json['name'] as String,
        type: json['type'] as String,
        category: MoveCategory.values.byName(json['category'] as String),
        power: json['power'] as int,
        accuracy: json['accuracy'] as int,
        maxPp: json['max_pp'] as int,
        tier: json['tier'] as int,
        minLevel: json['min_level'] as int? ?? 1,
        weatherAffinity: json['weather_affinity'] as String?,
        weatherBonusPct: json['weather_bonus_pct'] as int?,
        timeAffinity: json['time_affinity'] as String?,
        timeBonusPct: json['time_bonus_pct'] as int?,
        inflictsStatus: json['inflicts_status'] as String?,
        statusChancePct: json['status_chance_pct'] as int?,
        scalesWithTargetWeight: json['scales_with_target_weight'] as bool? ?? false,
      );
}

/// A move as owned by a Wildkin: a reference to the base move +
/// current PP (consumed by use in battle).
class LearnedMove {
  final Move move;
  final int currentPp;

  const LearnedMove({required this.move, required this.currentPp});

  LearnedMove copyWith({int? currentPp}) =>
      LearnedMove(move: move, currentPp: currentPp ?? this.currentPp);

  Map<String, dynamic> toJson() => {
        'move': move.toJson(),
        'current_pp': currentPp,
      };

  factory LearnedMove.fromJson(Map<String, dynamic> json) => LearnedMove(
        move: Move.fromJson(json['move'] as Map<String, dynamic>),
        currentPp: json['current_pp'] as int,
      );
}
