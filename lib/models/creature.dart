import 'capture_context.dart';
import 'evolution_plan.dart';
import 'move.dart';
import 'stats.dart';

/// Rappresenta una creatura catturata: le due sprite generate
/// (fronte, mostrata nel "pokedex" e nel menu; retro, mostrata
/// quando la creatura è in campo durante una battaglia), la sua
/// progressione (livello, esperienza, statistiche), la sua catena
/// evolutiva e il moveset, oltre ai metadati derivati dal contesto
/// di cattura (e, se già evoluta, dal contesto di evoluzione).
class Creature {
  final String id;
  final String nickname;
  final String originalPhotoUrl;
  final String frontSpriteUrl;
  final String backSpriteUrl;

  /// 1 tipo alla cattura, 2 a partire dalla prima evoluzione.
  final List<String> types;

  final int level; // 1-100, parte sempre da 5 alla cattura
  final int currentExp;
  final int currentHp; // può essere < maxHp se reduce da una battaglia

  final BaseStats baseStats;
  final List<LearnedMove> moves; // sempre al massimo 4
  final EvolutionPlan evolutionPlan;

  final CaptureContext captureContext;
  final CaptureContext? evolutionContext; // valorizzato solo dopo la 1a evoluzione

  final String? speciesHint; // es. "gatto", "cane", "gabbiano"

  const Creature({
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
  });

  ComputedStats computeStats() {
    // Formule ispirate a quelle ufficiali (semplificate: niente EV,
    // gli IV sono impliciti nei baseStats generati alla cattura).
    int statAt(int base) => (((2 * base) * level) / 100).floor() + 5;

    final maxHp = (((2 * baseStats.hp) * level) / 100).floor() + level + 10;

    return ComputedStats(
      maxHp: maxHp,
      attack: statAt(baseStats.attack),
      defense: statAt(baseStats.defense),
      spAttack: statAt(baseStats.spAttack),
      spDefense: statAt(baseStats.spDefense),
      speed: statAt(baseStats.speed),
    );
  }

  Creature copyWith({
    String? nickname,
    List<String>? types,
    int? level,
    int? currentExp,
    int? currentHp,
    List<LearnedMove>? moves,
    EvolutionPlan? evolutionPlan,
    CaptureContext? evolutionContext,
    String? frontSpriteUrl,
    String? backSpriteUrl,
  }) {
    return Creature(
      id: id,
      nickname: nickname ?? this.nickname,
      originalPhotoUrl: originalPhotoUrl,
      frontSpriteUrl: frontSpriteUrl ?? this.frontSpriteUrl,
      backSpriteUrl: backSpriteUrl ?? this.backSpriteUrl,
      types: types ?? this.types,
      level: level ?? this.level,
      currentExp: currentExp ?? this.currentExp,
      currentHp: currentHp ?? this.currentHp,
      baseStats: baseStats,
      moves: moves ?? this.moves,
      evolutionPlan: evolutionPlan ?? this.evolutionPlan,
      captureContext: captureContext,
      evolutionContext: evolutionContext ?? this.evolutionContext,
      speciesHint: speciesHint,
    );
  }

  factory Creature.fromJson(Map<String, dynamic> json) {
    return Creature(
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
