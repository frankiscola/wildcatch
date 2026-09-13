import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/capture_context.dart';

/// Wraps all geolocation logic: permissions, GPS position,
/// elevation, and biome estimation.
class LocationService {
  /// Requests permissions and returns the current position.
  /// Throws an exception if permissions are denied.
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException('GPS is turned off.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationServiceException('Location permission denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'Location permission permanently denied. Enable it from settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Fetches the elevation in meters for a lat/lon pair using
  /// Open-Elevation (a free service, no API key needed).
  Future<double?> getElevation(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-elevation.com/api/v1/lookup?locations=$lat,$lon',
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List;
      if (results.isEmpty) return null;
      return (results.first['elevation'] as num).toDouble();
    } catch (_) {
      // TODO: add logging/telemetry for network errors
      return null;
    }
  }

  /// Estimates the biome by combining elevation and reverse geocoding.
  ///
  /// This is a simple heuristic meant for the MVP. For a more
  /// accurate estimate, query OpenStreetMap's Overpass API for tags
  /// like natural=coastline, natural=water, landuse=forest,
  /// landuse=residential within a few km of the GPS point.
  Biome estimateBiome({
    required double? elevationMeters,
    required double distanceFromCoastKm,
  }) {
    if (distanceFromCoastKm < 2) return Biome.sea;
    if (elevationMeters != null && elevationMeters > 1200) return Biome.mountain;
    if (elevationMeters != null && elevationMeters > 600) return Biome.mountain;
    return Biome.unknown;
    // TODO: integrate the Overpass API to more reliably distinguish
    // forest, city, and plain.
  }
}

class LocationServiceException implements Exception {
  final String message;
  LocationServiceException(this.message);

  @override
  String toString() => message;
}
