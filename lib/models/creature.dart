import 'capture_context.dart';

/// Rappresenta una creatura catturata: le due sprite generate
/// (fronte, mostrata nel "pokedex" e nel menu; retro, mostrata
/// quando la creatura è in campo durante una battaglia) più tutti
/// i metadati derivati dal contesto di cattura.
class Creature {
  final String id;
  final String nickname;
  final String originalPhotoUrl;
  final String frontSpriteUrl;
  final String backSpriteUrl;
  final List<String> types; // 1 o 2 tipi, es. ["fuoco", "roccia"]
  final CaptureContext context;
  final String? speciesHint; // es. "gatto", "cane", "gabbiano"

  const Creature({
    required this.id,
    required this.nickname,
    required this.originalPhotoUrl,
    required this.frontSpriteUrl,
    required this.backSpriteUrl,
    required this.types,
    required this.context,
    this.speciesHint,
  });

  factory Creature.fromJson(Map<String, dynamic> json) {
    return Creature(
      id: json['id'] as String,
      nickname: json['nickname'] as String? ?? '???',
      originalPhotoUrl: json['original_photo_url'] as String,
      frontSpriteUrl: json['front_sprite_url'] as String,
      backSpriteUrl: json['back_sprite_url'] as String,
      types: (json['assigned_type'] as List).cast<String>(),
      speciesHint: json['species_hint'] as String?,
      context: CaptureContext(
        capturedAt: DateTime.parse(json['captured_at'] as String),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        weatherCondition: json['weather_condition'] as String,
        temperatureCelsius: (json['temperature_c'] as num).toDouble(),
        humidityPercent: (json['humidity_percent'] as num?)?.toDouble() ?? 0,
        windSpeedKmh: (json['wind_speed_kmh'] as num?)?.toDouble() ?? 0,
        elevationMeters: (json['elevation_m'] as num?)?.toDouble(),
      ),
    );
  }
}
