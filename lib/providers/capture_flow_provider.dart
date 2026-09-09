import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/capture_context.dart';
import '../models/creature.dart';
import '../models/sighting.dart';
import '../services/camera_capture_service.dart';
import '../services/depth_check_service.dart';
import '../services/liveness_service.dart';
import '../services/location_service.dart';
import '../services/species_detector.dart';
import '../services/supabase_service.dart';
import '../services/weather_service.dart';
import '../services/name_generator.dart';

/// Le fasi del flusso di cattura, ora a DUE scatti (vedi meccanismo 5,
/// doppio avvistamento) invece di uno solo.
enum CaptureStep {
  idle,
  requestingContext, // GPS + meteo + elevazione
  capturingBurst, // meccanismi 1+3: raffica di frame + giroscopio
  uploadingPhoto,
  recordingSighting, // primo scatto: registra l'avvistamento
  awaitingConfirmation, // in attesa del secondo scatto, con countdown (meccanismo 4)
  confirmingSighting, // secondo scatto: verifica + finalizza
  naming,
  done,
  sightingExpired, // la finestra è scaduta prima della conferma
  rejected, // il server ha rifiutato la conferma (specie diversa, troppo lontano, immagine duplicata...)
  error,
}

/// Quanto tempo l'utente ha per tornare a fotografare lo stesso
/// animale dopo il primo avvistamento. Ricalibrabile: più è corto,
/// più è difficile "prepararsi" con un'immagine trovata online; più è
/// lungo, più è comodo per chi sta davvero seguendo un animale reale
/// che si allontana lentamente.
const kSightingWindowDuration = Duration(minutes: 20);

class CaptureFlowState {
  final CaptureStep step;
  final String? errorMessage;
  final SightingRejectionReason? rejectionReason;
  final Creature? result;
  final SightingRecorded? pendingSighting;
  final Duration? remaining; // countdown per la UI durante awaitingConfirmation
  final String? detectedSpeciesHint;

  const CaptureFlowState({
    this.step = CaptureStep.idle,
    this.errorMessage,
    this.rejectionReason,
    this.result,
    this.pendingSighting,
    this.remaining,
    this.detectedSpeciesHint,
  });

  CaptureFlowState copyWith({
    CaptureStep? step,
    String? errorMessage,
    SightingRejectionReason? rejectionReason,
    Creature? result,
    SightingRecorded? pendingSighting,
    Duration? remaining,
    String? detectedSpeciesHint,
    bool clearPendingSighting = false,
  }) {
    return CaptureFlowState(
      step: step ?? this.step,
      errorMessage: errorMessage,
      rejectionReason: rejectionReason,
      result: result ?? this.result,
      pendingSighting:
          clearPendingSighting ? null : (pendingSighting ?? this.pendingSighting),
      remaining: remaining,
      detectedSpeciesHint: detectedSpeciesHint ?? this.detectedSpeciesHint,
    );
  }
}

class CaptureFlowNotifier extends StateNotifier<CaptureFlowState> {
  final CameraCaptureService _camera;
  final LivenessService _liveness;
  final DepthCheckService _depth;
  final LocationService _locationService;
  final WeatherService _weatherService;
  final SupabaseService _supabaseService;
  final SpeciesDetector _speciesDetector;
  final NameGenerator _nameGenerator;

  Timer? _countdownTimer;

  CaptureFlowNotifier({
    CameraCaptureService? camera,
    LivenessService? liveness,
    DepthCheckService? depth,
    LocationService? locationService,
    WeatherService? weatherService,
    SupabaseService? supabaseService,
    SpeciesDetector? speciesDetector,
    NameGenerator? nameGenerator,
  })  : _camera = camera ?? CameraCaptureService(),
        _liveness = liveness ?? LivenessService(),
        _depth = depth ?? DepthCheckService(),
        _locationService = locationService ?? LocationService(),
        _weatherService = weatherService ?? WeatherService(),
        _supabaseService = supabaseService ?? SupabaseService(),
        _speciesDetector = speciesDetector ?? SpeciesDetector(),
        _nameGenerator = nameGenerator ?? NameGenerator(),
        super(const CaptureFlowState());

  /// Inizializza la fotocamera live. Va chiamato quando la schermata
  /// di cattura entra in scena, prima di poter chiamare
  /// captureFirstSighting/captureConfirmation.
  Future<void> initializeCamera() => _camera.initialize();

  CameraCaptureService get camera => _camera;

  /// Primo scatto: registra l'avvistamento e apre la finestra
  /// temporale (meccanismo 4) entro cui va confermato.
  Future<void> captureFirstSighting({required String userId}) async {
    try {
      final capture = await _captureAndAnalyze();

      state = state.copyWith(
        step: CaptureStep.uploadingPhoto,
        detectedSpeciesHint: capture.speciesHint,
      );
      final photoUrl = await _supabaseService.uploadOriginalPhoto(
        userId: userId,
        photoBytes: capture.photoBytes,
      );

      state = state.copyWith(step: CaptureStep.recordingSighting);
      final sighting = await _supabaseService.recordSighting(
        originalPhotoUrl: photoUrl,
        context: capture.context,
        speciesHint: capture.speciesHint,
      );

      _startCountdown(sighting.expiresAt);
      state = state.copyWith(
        step: CaptureStep.awaitingConfirmation,
        pendingSighting: sighting,
      );
    } catch (e) {
      state = state.copyWith(step: CaptureStep.error, errorMessage: e.toString());
    }
  }

  /// Secondo scatto: prova a confermare l'avvistamento in corso.
  Future<void> captureConfirmation({required String userId}) async {
    final pending = state.pendingSighting;
    if (pending == null) {
      state = state.copyWith(
        step: CaptureStep.error,
        errorMessage: 'Nessun avvistamento in corso da confermare.',
      );
      return;
    }

    try {
      final capture = await _captureAndAnalyze();

      state = state.copyWith(step: CaptureStep.uploadingPhoto);
      final photoUrl = await _supabaseService.uploadOriginalPhoto(
        userId: userId,
        photoBytes: capture.photoBytes,
      );

      state = state.copyWith(step: CaptureStep.confirmingSighting);
      final creature = await _supabaseService.confirmSighting(
        sightingId: pending.sightingId,
        originalPhotoUrl: photoUrl,
        context: capture.context,
        speciesHint: capture.speciesHint,
      );

      _countdownTimer?.cancel();

      state = state.copyWith(step: CaptureStep.naming);
      final name = _nameGenerator.generate(
        capture.speciesHint ?? state.detectedSpeciesHint,
        creature.types,
      );
      final renamed = await _supabaseService.renameCreature(id: creature.id, nickname: name);

      state = state.copyWith(step: CaptureStep.done, result: renamed);
    } on SightingRejectedException catch (e) {
      // Rifiuto motivato dal server: se la finestra non è scaduta,
      // l'utente resta libero di riprovare subito un altro scatto
      // (pendingSighting non viene azzerato). Se è scaduta, il
      // countdown stesso avrà già portato lo stato a
      // sightingExpired prima ancora di arrivare qui.
      state = state.copyWith(step: CaptureStep.rejected, rejectionReason: e.reason);
    } catch (e) {
      state = state.copyWith(step: CaptureStep.error, errorMessage: e.toString());
    }
  }

  /// Meccanismo 1+2+3: raffica di frame + giroscopio (+ profondità se
  /// disponibile) e costruzione del CaptureContext completo, usato
  /// sia dal primo scatto sia dalla conferma.
  Future<_CapturedMoment> _captureAndAnalyze() async {
    state = state.copyWith(step: CaptureStep.requestingContext);
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

    state = state.copyWith(step: CaptureStep.capturingBurst);
    _liveness.startGyroSampling();
    final frames = await _camera.captureBurst();
    final livenessReport = await _liveness.finishAndAnalyze(frames);

    // Segnale best-effort, degrada a null sulla stragrande
    // maggioranza dei device finché non si scrive il codice nativo
    // (vedi DepthCheckService). Non blocca mai la cattura da solo:
    // qui lo leggiamo ma la decisione se avvisare l'utente resta
    // interamente lato server, che può scegliere di ignorarlo con
    // sicurezza se è null.
    await _depth.sampleCenterDepthVariance();

    // Frame centrale del burst: meno soggetto a mosso rispetto al
    // primo/ultimo, che spesso catturano l'inizio/fine del piccolo
    // movimento della mano usato per il calcolo della parallasse.
    final photoBytes = frames[frames.length ~/ 2];

    String? speciesHint;
    try {
      speciesHint = await _speciesDetector.detectFromBytes(photoBytes);
    } catch (_) {
      speciesHint = null;
    }

    final context = CaptureContext(
      capturedAt: DateTime.now(),
      latitude: position.latitude,
      longitude: position.longitude,
      elevationMeters: elevation,
      biome: biome,
      weatherCondition: weather.condition,
      temperatureCelsius: weather.temperatureCelsius,
      humidityPercent: weather.humidityPercent,
      windSpeedKmh: weather.windSpeedKmh,
      liveness: livenessReport,
    );

    return _CapturedMoment(
      photoBytes: photoBytes,
      context: context,
      speciesHint: speciesHint,
    );
  }

  void _startCountdown(DateTime expiresAt) {
    _countdownTimer?.cancel();
    _tickCountdown(expiresAt);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickCountdown(expiresAt));
  }

  void _tickCountdown(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      _countdownTimer?.cancel();
      state = state.copyWith(step: CaptureStep.sightingExpired, clearPendingSighting: true);
      return;
    }
    state = state.copyWith(remaining: remaining);
  }

  void reset() {
    _countdownTimer?.cancel();
    _liveness.cancel();
    state = const CaptureFlowState();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _liveness.cancel();
    _camera.dispose();
    _speciesDetector.dispose();
    super.dispose();
  }
}

class _CapturedMoment {
  final Uint8List photoBytes;
  final CaptureContext context;
  final String? speciesHint;

  const _CapturedMoment({
    required this.photoBytes,
    required this.context,
    required this.speciesHint,
  });
}

final captureFlowProvider = StateNotifierProvider<CaptureFlowNotifier, CaptureFlowState>(
  (ref) => CaptureFlowNotifier(),
);

/// Elenco delle creature catturate dall'utente, per il pokedex.
final myCreaturesProvider = FutureProvider<List<Creature>>((ref) async {
  return SupabaseService().getMyCreatures();
});
