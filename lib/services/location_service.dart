import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/capture_context.dart';

/// Incapsula tutta la logica di geolocalizzazione:
/// permessi, posizione GPS, elevazione e stima del bioma.
class LocationService {
  /// Chiede i permessi e restituisce la posizione corrente.
  /// Lancia un'eccezione se i permessi vengono negati.
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException('Il GPS è disattivato.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationServiceException('Permesso GPS negato.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'Permesso GPS negato permanentemente. Abilitalo dalle impostazioni.',
      );
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Recupera l'elevazione in metri per una coppia lat/long
  /// usando Open-Elevation (servizio gratuito, nessuna API key).
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
      // TODO: aggiungere logging/telemetria degli errori di rete
      return null;
    }
  }

  /// Stima il bioma combinando elevazione e reverse geocoding.
  ///
  /// Questa è un'euristica semplice pensata per l'MVP.
  /// Per una stima più accurata si può interrogare la Overpass API
  /// di OpenStreetMap cercando tag come natural=coastline,
  /// natural=water, landuse=forest, landuse=residential nel raggio
  /// di qualche km dal punto GPS.
  Biome estimateBiome({
    required double? elevationMeters,
    required double distanceFromCoastKm,
  }) {
    if (distanceFromCoastKm < 2) return Biome.mare;
    if (elevationMeters != null && elevationMeters > 1200) return Biome.montagna;
    if (elevationMeters != null && elevationMeters > 600) return Biome.montagna;
    return Biome.sconosciuto;
    // TODO: integrare Overpass API per distinguere foresta,
    // città e pianura in modo più affidabile.
  }
}

class LocationServiceException implements Exception {
  final String message;
  LocationServiceException(this.message);

  @override
  String toString() => message;
}
