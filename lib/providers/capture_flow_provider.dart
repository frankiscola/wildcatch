import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/capture_context.dart';
import '../models/creature.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../services/supabase_service.dart';

/// Le fasi del flusso di cattura, in ordine.
enum CaptureStep {
  idle,
  requestingContext, // GPS + meteo + elevazione
  uploadingPhoto,
  generatingCreature, // chiamata alla edge function
  done,
  error,
}

class CaptureFlowState {
  final CaptureStep step;
  final String? errorMessage;
  final Creature? result;

  const CaptureFlowState({
    this.step = CaptureStep.idle,
    this.errorMessage,
    this.result,
  });

  CaptureFlowState copyWith({
    CaptureStep? step,
    String? errorMessage,
    Creature? result,
  }) {
    return CaptureFlowState(
      step: step ?? this.step,
      errorMessage: errorMessage,
      result: result ?? this.result,
    );
  }
}

class CaptureFlowNotifier extends StateNotifier<CaptureFlowState> {
  final LocationService _locationService;
  final WeatherService _weatherService;
  final SupabaseService _supabaseService;

  CaptureFlowNotifier({
    LocationService? locationService,
    WeatherService? weatherService,
    SupabaseService? supabaseService,
  })  : _locationService = locationService ?? LocationService(),
        _weatherService = weatherService ?? WeatherService(),
        _supabaseService = supabaseService ?? SupabaseService(),
        super(const CaptureFlowState());

  /// Orchestratore principale: dalla foto appena scattata
  /// fino alla creatura generata.
  Future<void> startCapture({
    required Uint8List photoBytes,
    required String userId,
  }) async {
    try {
      state = state.copyWith(step: CaptureStep.requestingContext);
      final context = await _buildCaptureContext();

      state = state.copyWith(step: CaptureStep.uploadingPhoto);
      final photoUrl = await _supabaseService.uploadOriginalPhoto(
        userId: userId,
        photoBytes: photoBytes,
      );

      state = state.copyWith(step: CaptureStep.generatingCreature);
      final creature = await _supabaseService.generateCreature(
        originalPhotoUrl: photoUrl,
        context: context,
      );

      state = state.copyWith(step: CaptureStep.done, result: creature);
    } catch (e) {
      state = state.copyWith(
        step: CaptureStep.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<CaptureContext> _buildCaptureContext() async {
    final position = await _locationService.getCurrentPosition();
    final weather = await _weatherService.getCurrentWeather(
      position.latitude,
      position.longitude,
    );
    final elevation = await _locationService.getElevation(
      position.latitude,
      position.longitude,
    );

    // TODO: sostituire con una stima reale della distanza dalla costa
    // (dataset costiero o Overpass API) invece di questo placeholder.
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

  void reset() => state = const CaptureFlowState();
}

final captureFlowProvider =
    StateNotifierProvider<CaptureFlowNotifier, CaptureFlowState>(
  (ref) => CaptureFlowNotifier(),
);

/// Elenco delle creature catturate dall'utente, per il pokedex.
final myCreaturesProvider = FutureProvider<List<Creature>>((ref) async {
  return SupabaseService().getMyCreatures();
});
