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

  /// Segnali anti-spoofing calcolati sul dispositivo durante lo scatto
  /// (vedi LivenessService). Il server li tratta come indizi, MAI come
  /// verità assoluta: un client manomesso potrebbe sempre inviare valori
  /// falsi. Il controllo davvero robusto resta il doppio avvistamento
  /// server-side (vedi resolve-sighting), che non dipende da quello che
  /// il client dichiara di aver misurato.
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
    this.biome = Biome.sconosciuto,
    this.liveness,
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
        'liveness': liveness?.toJson(),
      };
}

/// Esito dell'analisi di "vivezza" dello scatto (meccanismi 1+3 del
/// piano anti-cattura-da-internet): un punteggio di parallasse tra i
/// frame del burst e la conferma che il telefono si sia fisicamente
/// mosso durante la cattura. Vedi LivenessService per il calcolo.
class LivenessReport {
  /// Quanto i "blocchi" dell'immagine si sono mossi in modo
  /// disomogeneo tra un frame e l'altro del burst. Alto = scena 3D
  /// reale (parallasse presente). Vicino a zero = molto probabilmente
  /// una superficie piatta (foto, schermo, rivista) semplicemente
  /// traslata rigidamente davanti alla camera.
  final double parallaxVarianceScore;

  /// Motion totale rilevato tra i frame, indipendentemente dalla sua
  /// distribuzione. Serve a scartare il caso limite di un telefono
  /// tenuto perfettamente fermo (es. su un supporto) che punta a
  /// un'immagine statica: lì la parallasse sarebbe comunque ~0 ma
  /// vogliamo distinguerlo esplicitamente da "nessun movimento affatto".
  final double totalMotionScore;

  /// Integrale del modulo della velocità angolare (giroscopio) durante
  /// la finestra di cattura. Un vero scatto a mano libera produce
  /// sempre un minimo di micro-tremore; un telefono fissato su un
  /// cavalletto puntato su un poster, molto meno.
  final double gyroMotionMagnitude;

  /// True se, incrociando i tre segnali sopra, la cattura sembra
  /// avvenuta davanti a una superficie piatta invece che a una scena
  /// 3D reale. Calcolato lato client in LivenessService, RICALCOLATO
  /// anche lato server dove possibile: qui viaggia solo come indizio.
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
