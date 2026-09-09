import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Decide DA SOLO il momento giusto per scattare, osservando il
/// giroscopio, invece di aspettare un tap dell'utente.
///
/// Funziona a due fasi, non una sola, e il motivo è importante:
///
///  1. "Aiming" — aspetta che il telefono si muova un minimo, sopra
///     [_aimingThreshold]. Rappresenta il gesto naturale di alzare e
///     puntare il telefono verso l'animale.
///  2. "Settling" — una volta rilevato quel movimento, aspetta che il
///     telefono resti sotto [_stillThreshold] per un'intera finestra
///     continua ([_stabilityWindow]) prima di dare il via libera.
///
/// Perché non basta la sola fase 2 (solo "aspetta che sia fermo"): un
/// telefono appoggiato su un tavolo, immobile fin dal primo istante,
/// soddisferebbe la condizione di stabilità quasi subito — è
/// esattamente lo scenario "superficie piatta/foto ferma" che il
/// meccanismo 3 in liveness_service.dart considera sospetto.
/// Richiedere prima un movimento vero (fase 1) assicura che l'utente
/// abbia davvero impugnato e puntato il telefono a mano, non che l'app
/// scatti da sola su qualcosa lasciato fermo davanti alla fotocamera.
///
/// NOTA PER I TEST SU EMULATORE: il giroscopio virtuale resta quasi
/// sempre a zero a meno di pilotarlo manualmente da Extended Controls
/// → Virtual sensors, quindi la fase "aiming" potrebbe non scattare
/// mai. Per questo capture_screen.dart tiene comunque un pulsante
/// manuale come alternativa, non solo l'auto-scatto.
class AutoCaptureGate {
  static const double _aimingThreshold = 0.5; // rad/s circa, da ricalibrare su device reali
  static const double _stillThreshold = 0.12; // rad/s circa, da ricalibrare su device reali
  static const Duration _stabilityWindow = Duration(milliseconds: 600);
  static const Duration _samplingTick = Duration(milliseconds: 50);

  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _tickTimer;

  bool _hasAimed = false;
  DateTime? _stillSince;

  final _progressController = StreamController<double>.broadcast();
  final _readyCompleter = Completer<void>();
  bool _stopped = false;

  /// Da 0.0 a 1.0: quanto manca al prossimo scatto automatico. La UI
  /// lo usa per riempire un anello attorno al pulsante di cattura.
  Stream<double> get progress => _progressController.stream;

  /// Si completa quando è il momento di scattare. Una volta
  /// completato, il gate si ferma da solo (vedi _onEvent/_emitProgress):
  /// per un nuovo tentativo va creata una nuova istanza.
  Future<void> get onReady => _readyCompleter.future;

  void start() {
    _gyroSub = gyroscopeEvents.listen(
      _onEvent,
      onError: (_) {
        // Device senza giroscopio: niente auto-scatto, il progress
        // resta sempre a 0 e l'utente userà il pulsante manuale.
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
      // Si è mosso di nuovo: la finestra di stabilità riparte da zero.
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
      // Un solo scatto automatico per istanza: chi lo usa ne crea una
      // nuova per il tentativo successivo (vedi capture_screen.dart).
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
