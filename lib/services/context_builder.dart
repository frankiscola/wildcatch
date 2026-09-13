import '../models/capture_context.dart';
import 'location_service.dart';
import 'weather_service.dart';

/// Collects GPS, weather, elevation, and biome estimate — used ONLY
/// to generate a wild-encounter preview before a battle (see
/// WildEncounterGenerator), when the player already has a sighting
/// in progress (CaptureFlowNotifier.pendingSighting) and doesn't
/// need a new photo, just a "right now" context.
///
/// NOTE: the same GPS/weather/biome collection already exists,
/// almost identically, inside
/// CaptureFlowNotifier._captureAndAnalyze() — it wasn't unified with
/// that one to avoid touching the already-tested double-sighting
/// pipeline. This is a deliberate small duplication, not an oversight.
class ContextBuilder {
  final LocationService _locationService;
  final WeatherService _weatherService;

  ContextBuilder({
    LocationService? locationService,
    WeatherService? weatherService,
  })  : _locationService = locationService ?? LocationService(),
        _weatherService = weatherService ?? WeatherService();

  Future<CaptureContext> buildCurrentContext() async {
    final position = await _locationService.getCurrentPosition();
    final weather = await _weatherService.getCurrentWeather(
      position.latitude,
      position.longitude,
    );
    final elevation = await _locationService.getElevation(
      position.latitude,
      position.longitude,
    );

    const placeholderDistanceFromCoastKm = 999.0;
    final biome = _locationService.estimateBiome(
      elevationMeters: elevation,
      distanceFromCoastKm: placeholderDistanceFromCoastKm,
    );

    return CaptureContext(
      capturedAt: DateTime.now(),
      latitude: position.latitude,
      longitude: position.longitude,
      elevationMeters: elevation,
      biome: biome,
      weatherCondition: weather.condition,
      temperatureCelsius: weather.temperatureCelsius,
      humidityPercent: weather.humidityPercent,
      windSpeedKmh: weather.windSpeedKmh,
    );
  }
}
