import 'capture_context.dart';
import 'evolution_plan.dart';
import 'move.dart';
import 'stats.dart';
import 'biome_imprints.dart';
import 'wildkin_physique.dart';

/// Represents a captured Wildkin: its two generated sprites (front,
/// shown in the Field Journal and menus; back, shown when the
/// Wildkin is on the field during a battle), its progression
/// (level, experience, stats), its evolution chain and moveset,
/// plus the metadata derived from the capture context (and, once
/// evolved, from the evolution context).
class Wildkin {
  final String id;
  final String nickname;
  final String originalPhotoUrl;
  final String frontSpriteUrl;
  final String backSpriteUrl;

  /// 1 type at capture, 2 starting from the first evolution.
  final List<String> types;

  final int level; // 1-100, always starts at 5 on capture
  final int currentExp;
  final int currentHp; // can be < maxHp if it took damage in a battle

  final BaseStats baseStats;
  final List<LearnedMove> moves; // always 4 at most
  final EvolutionPlan evolutionPlan;

  final CaptureContext captureContext;
  final CaptureContext? evolutionContext; // set only after the 1st evolution

  final String? speciesHint; // e.g. "cat", "dog", "seagull"

  /// True if this Wildkin is one of the (at most 4) currently on the
  /// active team. Enforced both client-side (see TeamScreen) and by
  /// a DB trigger (captures.trg_enforce_max_team_size), so a race
  /// between two devices can't sneak in a 5th member.
  final bool isInTeam;

  /// Rolled once at capture from its biome's pair of options (see
  /// BiomeImprints). Permanent — never re-rolled, not even at
  /// evolution. Null if the biome couldn't be determined at capture.
  final BiomeImprint? imprint;

  const Wildkin({
    required this.id,
    required this.nickname,
    required this.originalPhotoUrl,
    required this.frontSpriteUrl,
    required this.backSpriteUrl,
    required this.types,
    required this.level,
    required this.currentExp,
    required this.currentHp,
    required this.baseStats,
    required this.moves,
    required this.evolutionPlan,
    required this.captureContext,
    this.evolutionContext,
    this.speciesHint,
    this.isInTeam = false,
    this.imprint,
  });

  /// Weight/size, always derived fresh from stats + evolution stage
  /// — see WildkinPhysique for why this is never stored.
  WildkinPhysique get physique =>
      WildkinPhysique.fromStats(baseStats, currentStage: evolutionPlan.currentStage);

  ComputedStats computeStats() {
    // Formulas inspired by the classic ones (simplified: no EVs,
    // the Potential Score is implicit in the baseStats generated at
    // capture).
    int statAt(int base) => (((2 * base) * level) / 100).floor() + 5;

    final maxHp = (((2 * baseStats.hp) * level) / 100).floor() + level + 10;

    return ComputedStats(
      maxHp: maxHp,
      attack: statAt(baseStats.attack),
      defense: statAt(baseStats.defense),
      elementalAttack: statAt(baseStats.elementalAttack),
      elementalDefense: statAt(baseStats.elementalDefense),
      speed: statAt(baseStats.speed),
    );
  }

  Wildkin copyWith({
    String? nickname,
    List<String>? types,
    int? level,
    int? currentExp,
    int? currentHp,
    BaseStats? baseStats,
    List<LearnedMove>? moves,
    EvolutionPlan? evolutionPlan,
    CaptureContext? evolutionContext,
    String? frontSpriteUrl,
    String? backSpriteUrl,
    bool? isInTeam,
  }) {
    return Wildkin(
      id: id,
      nickname: nickname ?? this.nickname,
      originalPhotoUrl: originalPhotoUrl,
      frontSpriteUrl: frontSpriteUrl ?? this.frontSpriteUrl,
      backSpriteUrl: backSpriteUrl ?? this.backSpriteUrl,
      types: types ?? this.types,
      level: level ?? this.level,
      currentExp: currentExp ?? this.currentExp,
      currentHp: currentHp ?? this.currentHp,
      baseStats: baseStats ?? this.baseStats,
      moves: moves ?? this.moves,
      evolutionPlan: evolutionPlan ?? this.evolutionPlan,
      captureContext: captureContext,
      evolutionContext: evolutionContext ?? this.evolutionContext,
      speciesHint: speciesHint,
      isInTeam: isInTeam ?? this.isInTeam,
      imprint: imprint,
    );
  }

  factory Wildkin.fromJson(Map<String, dynamic> json) {
    return Wildkin(
      id: json['id'] as String,
      nickname: json['nickname'] as String? ?? '???',
      originalPhotoUrl: json['original_photo_url'] as String,
      frontSpriteUrl: json['front_sprite_url'] as String,
      backSpriteUrl: json['back_sprite_url'] as String,
      types: (json['assigned_type'] as List).cast<String>(),
      level: json['level'] as int? ?? 5,
      currentExp: json['current_exp'] as int? ?? 0,
      currentHp: json['current_hp'] as int? ?? 1,
      baseStats: BaseStats.fromJson(json['base_stats'] as Map<String, dynamic>),
      moves: (json['moves'] as List)
          .map((m) => LearnedMove.fromJson(m as Map<String, dynamic>))
          .toList(),
      evolutionPlan:
          EvolutionPlan.fromJson(json['evolution_plan'] as Map<String, dynamic>),
      speciesHint: json['species_hint'] as String?,
      isInTeam: json['is_in_team'] as bool? ?? false,
      imprint: json['biome_imprint'] == null
          ? null
          : BiomeImprint.fromJson(json['biome_imprint'] as Map<String, dynamic>),
      captureContext: CaptureContext(
        capturedAt: DateTime.parse(json['captured_at'] as String),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        weatherCondition: json['weather_condition'] as String,
        temperatureCelsius: (json['temperature_c'] as num).toDouble(),
        humidityPercent: (json['humidity_percent'] as num?)?.toDouble() ?? 0,
        windSpeedKmh: (json['wind_speed_kmh'] as num?)?.toDouble() ?? 0,
        elevationMeters: (json['elevation_m'] as num?)?.toDouble(),
      ),
      evolutionContext: json['evolution_context'] == null
          ? null
          : CaptureContext(
              capturedAt: DateTime.parse(json['evolution_context']['captured_at']),
              latitude: (json['evolution_context']['latitude'] as num).toDouble(),
              longitude: (json['evolution_context']['longitude'] as num).toDouble(),
              weatherCondition: json['evolution_context']['weather_condition'],
              temperatureCelsius:
                  (json['evolution_context']['temperature_c'] as num).toDouble(),
              humidityPercent:
                  (json['evolution_context']['humidity_percent'] as num?)
                          ?.toDouble() ??
                      0,
              windSpeedKmh:
                  (json['evolution_context']['wind_speed_kmh'] as num?)
                          ?.toDouble() ??
                      0,
              elevationMeters:
                  (json['evolution_context']['elevation_m'] as num?)?.toDouble(),
            ),
    );
  }
}
