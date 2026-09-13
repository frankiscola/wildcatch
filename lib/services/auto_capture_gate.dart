import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Decides ON ITS OWN the right moment to take the shot, by watching
/// the gyroscope, instead of waiting for a player tap.
///
/// Works in two phases, not one, and the reason matters:
///
///  1. "Aiming" — waits for the phone to move at least a little,
///     above [_aimingThreshold]. Represents the natural gesture of
///     lifting and pointing the phone at the animal.
///  2. "Settling" — once that movement is detected, waits for the
///     phone to stay below [_stillThreshold] for a full continuous
///     window ([_stabilityWindow]) before giving the go-ahead.
///
/// Why phase 2 alone isn't enough ("just wait until it's still"): a
/// phone resting on a table, motionless from the very first instant,
/// would satisfy the stability condition almost immediately — that's
/// exactly the "flat surface/still photo" scenario that mechanism 3
/// in liveness_service.dart treats as suspicious. Requiring genuine
/// movement first (phase 1) ensures the player really picked up and
/// pointed the phone by hand, rather than the app auto-firing on
/// something left still in front of the camera.
///
/// NOTE FOR EMULATOR TESTING: the virtual gyroscope almost always
/// stays at zero unless driven manually from Extended Controls →
/// Virtual sensors, so the "aiming" phase may never trigger. That's
/// why capture_screen.dart still keeps a manual button as a
/// fallback, not just auto-capture.
class AutoCaptureGate {
  static const double _aimingThreshold = 0.5; // rad/s roughly, needs tuning on real devices
  static const double _stillThreshold = 0.12; // rad/s roughly, needs tuning on real devices
  static const Duration _stabilityWindow = Duration(milliseconds: 600);
  static const Duration _samplingTick = Duration(milliseconds: 50);

  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _tickTimer;

  bool _hasAimed = false;
  DateTime? _stillSince;

  final _progressController = StreamController<double>.broadcast();
  final _readyCompleter = Completer<void>();
  bool _stopped = false;

  /// From 0.0 to 1.0: how close we are to the next automatic shot.
  /// The UI uses it to fill a ring around the capture button.
  Stream<double> get progress => _progressController.stream;

  /// Completes when it's time to take the shot. Once completed, the
  /// gate stops itself (see _onEvent/_emitProgress): a new instance
  /// must be created for another attempt.
  Future<void> get onReady => _readyCompleter.future;

  void start() {
    _gyroSub = gyroscopeEvents.listen(
      _onEvent,
      onError: (_) {
        // Device without a gyroscope: no auto-capture, progress
        // stays at 0 and the player will use the manual button.
      },
      cancelOnError: true,
    );
    _tickTimer = Timer.periodic(_samplingTick, (_) => _emitProgress());
  }

  void _onEvent(GyroscopeEvent event) {
    if (_stopped) return;

    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (!_hasAimed) {
      if (magnitude > _aimingThreshold) {
        _hasAimed = true;
      }
      return;
    }

    if (magnitude > _stillThreshold) {
      // Moved again: the stability window restarts from zero.
      _stillSince = null;
    } else {
      _stillSince ??= DateTime.now();
    }
  }

  void _emitProgress() {
    if (_stopped || _readyCompleter.isCompleted) return;

    if (!_hasAimed || _stillSince == null) {
      _progressController.add(0);
      return;
    }

    final elapsed = DateTime.now().difference(_stillSince!);
    final value =
        (elapsed.inMilliseconds / _stabilityWindow.inMilliseconds).clamp(0.0, 1.0);
    _progressController.add(value);

    if (value >= 1.0) {
      _readyCompleter.complete();
      // Only one automatic shot per instance: callers create a new
      // one for the next attempt (see capture_screen.dart).
      stop();
    }
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _tickTimer?.cancel();
    await _gyroSub?.cancel();
  }

  Future<void> dispose() async {
    await stop();
    if (!_progressController.isClosed) {
      await _progressController.close();
    }
  }
}
