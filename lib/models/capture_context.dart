/// Enum dei "biomi" rilevati dalla posizione GPS.
/// Usato dal motore di tipizzazione per pesare le probabilità.
enum Biome { mare, montagna, foresta, cittaUrbana, pianura, deserto, sconosciuto }

/// Tutti i dati contestuali raccolti al momento dello scatto.
/// Questo oggetto viene inviato integralmente alla edge function
/// Supabase, che lo usa per determinare il tipo della creatura.
class CaptureContext {
  final DateTime capturedAt;
  final double latitude;
  final double longitude;
  final double? elevationMeters;
  final Biome biome;

  final String weatherCondition; // es. "clear", "rain", "snow", "storm"
  final double temperatureCelsius;
  final double humidityPercent;
  final double windSpeedKmh;

  const CaptureContext({
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
    required this.weatherCondition,
    required this.temperatureCelsius,
    required this.humidityPercent,
    required this.windSpeedKmh,
    this.elevationMeters,
    this.biome = Biome.sconosciuto,
  });

  /// true se lo scatto è avvenuto tra il tramonto e l'alba.
  bool get isNightTime {
    final hour = capturedAt.hour;
    return hour >= 20 || hour < 6;
  }

  String get season {
    final month = capturedAt.month;
    if (month == 12 || month <= 2) return 'inverno';
    if (month <= 5) return 'primavera';
    if (month <= 8) return 'estate';
    return 'autunno';
  }

  Map<String, dynamic> toJson() => {
        'captured_at': capturedAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'elevation_meters': elevationMeters,
        'biome': biome.name,
        'weather_condition': weatherCondition,
        'temperature_celsius': temperatureCelsius,
        'humidity_percent': humidityPercent,
        'wind_speed_kmh': windSpeedKmh,
        'is_night_time': isNightTime,
        'season': season,
      };
}
