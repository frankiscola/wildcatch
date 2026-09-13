import 'dart:convert';
import 'package:http/http.dart' as http;

/// Minimal weather snapshot used by the typing engine.
class WeatherSnapshot {
  final String condition; // "clear", "cloudy", "rain", "snow", "storm", "fog"
  final double temperatureCelsius;
  final double humidityPercent;
  final double windSpeedKmh;

  const WeatherSnapshot({
    required this.condition,
    required this.temperatureCelsius,
    required this.humidityPercent,
    required this.windSpeedKmh,
  });
}

/// Fetches current weather from Open-Meteo, which is free and
/// requires no API key. OpenWeatherMap is a drop-in alternative if
/// more granular data is needed.
class WeatherService {
  Future<WeatherSnapshot> getCurrentWeather(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw WeatherServiceException('Could not read the current weather.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>;

    return WeatherSnapshot(
      condition: _mapWeatherCode(current['weather_code'] as int),
      temperatureCelsius: (current['temperature_2m'] as num).toDouble(),
      humidityPercent: (current['relative_humidity_2m'] as num).toDouble(),
      windSpeedKmh: (current['wind_speed_10m'] as num).toDouble(),
    );
  }

  /// Maps the WMO codes used by Open-Meteo into the simple
  /// categories used by the typing engine.
  /// Code reference: https://open-meteo.com/en/docs
  String _mapWeatherCode(int code) {
    if (code == 0) return 'clear';
    if (code <= 3) return 'cloudy';
    if (code == 45 || code == 48) return 'fog';
    if (code >= 51 && code <= 67) return 'rain';
    if (code >= 71 && code <= 77) return 'snow';
    if (code >= 80 && code <= 82) return 'rain';
    if (code >= 85 && code <= 86) return 'snow';
    if (code >= 95) return 'storm';
    return 'clear';
  }
}

class WeatherServiceException implements Exception {
  final String message;
  WeatherServiceException(this.message);

  @override
  String toString() => message;
}
