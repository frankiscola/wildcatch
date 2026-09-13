import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/capture_context.dart';
import '../models/wildkin.dart';
import '../models/sighting.dart';
import '../services/camera_capture_service.dart';
import '../services/depth_check_service.dart';
import '../services/liveness_service.dart';
import '../services/location_service.dart';
import '../services/species_detector.dart';
import '../services/supabase_service.dart';
import '../services/weather_service.dart';
import '../services/name_generator.dart';

/// The phases of the capture flow, now with TWO shots (see mechanism
/// 5, double sighting) instead of just one.
enum CaptureStep {
  idle,
  requestingContext, // GPS + weather + elevation
  capturingBurst, // mechanisms 1+3: frame burst + gyroscope
  uploadingPhoto,
  recordingSighting, // first shot: records the sighting
  awaitingConfirmation, // waiting for the second shot, with a countdown (mechanism 4)
  confirmingSighting, // second shot: verify + finalize
  naming,
  done,
  sightingExpired, // the window expired before confirmation
  rejected, // the server rejected the confirmation (different species, too far, duplicate image...)
  error,
}

/// How long the player has to come back and photograph the same
/// animal after the first sighting. Tunable: shorter makes it harder
/// to "prepare" with an image found online; longer is more
/// convenient for someone genuinely following a real animal that's
/// slowly moving away.
const kSightingWindowDuration = Duration(minutes: 20);

class CaptureFlowState {
  final CaptureStep step;
  final String? errorMessage;
  final SightingRejectionReason? rejectionReason;
  final Wildkin? result;
  final SightingRecorded? pendingSighting;
  final Duration? remaining; // countdown for the UI during awaitingConfirmation
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
    Wildkin? result,
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

  /// Initializes the live camera. Must be called when the capture
  /// screen comes into view, before captureFirstSighting/
  /// captureConfirmation can be called.
  Future<void> initializeCamera() => _camera.initialize();

  CameraCaptureService get camera => _camera;

  /// First shot: records the sighting and opens the time window
  /// (mechanism 4) within which it must be confirmed.
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

  /// Second shot: attempts to confirm the sighting in progress.
  Future<void> captureConfirmation({required String userId}) async {
    final pending = state.pendingSighting;
    if (pending == null) {
      state = state.copyWith(
        step: CaptureStep.error,
        errorMessage: 'No sighting in progress to confirm.',
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
      final wildkin = await _supabaseService.confirmSighting(
        sightingId: pending.sightingId,
        originalPhotoUrl: photoUrl,
        context: capture.context,
        speciesHint: capture.speciesHint,
      );

      _countdownTimer?.cancel();

      state = state.copyWith(step: CaptureStep.naming);
      final name = _nameGenerator.generate(
        capture.speciesHint ?? state.detectedSpeciesHint,
        wildkin.types,
      );
      final renamed = await _supabaseService.renameWildkin(id: wildkin.id, nickname: name);

      state = state.copyWith(step: CaptureStep.done, result: renamed);
    } on SightingRejectedException catch (e) {
      // Server-side rejection: if the window hasn't expired, the
      // player remains free to immediately try another shot
      // (pendingSighting isn't cleared). If it has expired, the
      // countdown itself will already have moved the state to
      // sightingExpired before we even get here.
      state = state.copyWith(step: CaptureStep.rejected, rejectionReason: e.reason);
    } catch (e) {
      state = state.copyWith(step: CaptureStep.error, errorMessage: e.toString());
    }
  }

  /// Mechanisms 1+2+3: frame burst + gyroscope (+ depth if available)
  /// and building the full CaptureContext, used by both the first
  /// shot and the confirmation.
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

    // TODO: replace with a real estimate of distance from the coast
    // (a coastline dataset or the Overpass API) instead of this
    // placeholder.
    const placeholderDistanceFromCoastKm = 999.0;
    final biome = _locationService.estimateBiome(
      elevationMeters: elevation,
      distanceFromCoastKm: placeholderDistanceFromCoastKm,
    );

    state = state.copyWith(step: CaptureStep.capturingBurst);
    _liveness.startGyroSampling();
    final frames = await _camera.captureBurst();
    final livenessReport = await _liveness.finishAndAnalyze(frames);

    // Best-effort signal, degrades to null on the vast majority of
    // devices until the native code is written (see
    // DepthCheckService). Never blocks the capture on its own: we
    // read it here, but the decision on whether to warn the player
    // stays entirely server-side, which can safely ignore it if null.
    await _depth.sampleCenterDepthVariance();

    // Middle frame of the burst: less prone to motion blur than the
    // first/last, which often capture the start/end of the small
    // hand movement used for the parallax calculation.
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

/// List of the Wildkin the player has caught, for the Field Journal.
final myWildkinProvider = FutureProvider<List<Wildkin>>((ref) async {
  return SupabaseService().getMyWildkin();
});
