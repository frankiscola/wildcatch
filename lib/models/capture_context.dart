/// Enum of the "biomes" detected from GPS location.
/// Used by the typing engine to weight type probabilities.
enum Biome { sea, mountain, forest, urbanCity, plain, desert, unknown }

/// All contextual data collected at the moment the photo is taken.
/// This object is sent in full to the Supabase edge function, which
/// uses it to determine the Wildkin's type.
class CaptureContext {
  final DateTime capturedAt;
  final double latitude;
  final double longitude;
  final double? elevationMeters;
  final Biome biome;

  final String weatherCondition; // e.g. "clear", "rain", "snow", "storm"
  final double temperatureCelsius;
  final double humidityPercent;
  final double windSpeedKmh;

  /// Anti-spoofing signals computed on-device at capture time (see
  /// LivenessService). The server treats them as clues, NEVER as
  /// absolute truth: a tampered client could always send fake
  /// values. The truly robust check remains the server-side double
  /// sighting (see resolve-sighting), which doesn't depend on what
  /// the client claims to have measured.
  final LivenessReport? liveness;

  const CaptureContext({
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
    required this.weatherCondition,
    required this.temperatureCelsius,
    required this.humidityPercent,
    required this.windSpeedKmh,
    this.elevationMeters,
    this.biome = Biome.unknown,
    this.liveness,
  });

  /// true if the photo was taken between sunset and sunrise.
  bool get isNightTime {
    final hour = capturedAt.hour;
    return hour >= 20 || hour < 6;
  }

  String get season {
    final month = capturedAt.month;
    if (month == 12 || month <= 2) return 'winter';
    if (month <= 5) return 'spring';
    if (month <= 8) return 'summer';
    return 'fall';
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
        'liveness': liveness?.toJson(),
      };
}

/// Result of the shot's "liveness" analysis (mechanisms 1+3 of the
/// anti-photo-of-a-screen plan): a parallax score across the burst
/// frames, plus confirmation that the phone physically moved during
/// capture. See LivenessService for the calculation.
class LivenessReport {
  /// How unevenly the image "blocks" moved from one burst frame to
  /// the next. High = a real 3D scene (parallax present). Near zero
  /// = most likely a flat surface (a photo, a screen, a magazine)
  /// simply translated rigidly in front of the camera.
  final double parallaxVarianceScore;

  /// Total motion detected across the frames, regardless of how it's
  /// distributed. Used to rule out the edge case of a phone held
  /// perfectly still (e.g. on a stand) pointed at a static image:
  /// there the parallax would still be ~0, but we want to tell that
  /// apart explicitly from "no movement at all".
  final double totalMotionScore;

  /// Integral of the angular velocity magnitude (gyroscope) during
  /// the capture window. A genuine handheld shot always produces at
  /// least a little micro-tremor; a phone mounted on a tripod
  /// pointed at a poster, much less.
  final double gyroMotionMagnitude;

  /// True if, combining the three signals above, the capture looks
  /// like it happened in front of a flat surface rather than a real
  /// 3D scene. Computed client-side in LivenessService, RECOMPUTED
  /// server-side where possible: here it only travels as a hint.
  final bool looksLikeFlatSurface;

  const LivenessReport({
    required this.parallaxVarianceScore,
    required this.totalMotionScore,
    required this.gyroMotionMagnitude,
    required this.looksLikeFlatSurface,
  });

  Map<String, dynamic> toJson() => {
        'parallax_variance_score': parallaxVarianceScore,
        'total_motion_score': totalMotionScore,
        'gyro_motion_magnitude': gyroMotionMagnitude,
        'looks_like_flat_surface': looksLikeFlatSurface,
      };
}
