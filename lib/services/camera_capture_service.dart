import 'dart:typed_data';
import 'package:camera/camera.dart';

/// Incapsula l'uso della fotocamera LIVE del dispositivo.
///
/// IMPORTANTE: questa è ora l'UNICA via per fornire una foto alla
/// cattura. Non esiste più, da nessuna parte nella UI, un pulsante
/// "scegli dalla galleria": è il prerequisito fondamentale di tutto
/// il resto del piano anti-cattura-da-internet (vedi liveness_service
/// e supabase/functions/resolve-sighting) — senza questo vincolo,
/// chiunque potrebbe semplicemente aggirare ogni controllo scegliendo
/// una foto già pronta invece di scattarne una dal vivo.
///
/// `image_picker` resta nel pubspec solo come dipendenza transitiva di
/// altri package; non va più usato con `ImageSource.gallery` in nessun
/// punto dell'app.
class CameraCaptureService {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  CameraController get controller {
    final c = _controller;
    if (c == null) {
      throw StateError('CameraCaptureService non inizializzato: chiama initialize() prima.');
    }
    return c;
  }

  Future<void> initialize() async {
    if (isInitialized) return;

    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw CameraCaptureException('Nessuna fotocamera disponibile su questo dispositivo.');
    }

    final back = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    final controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await controller.initialize();
    _controller = controller;
  }

  /// Scatta [frameCount] foto a distanza di [interval] l'una
  /// dall'altra, restituendole in ordine cronologico.
  ///
  /// Questo burst è la materia prima sia del punteggio di parallasse
  /// (LivenessService.analyzeParallax) sia della finestra temporale
  /// durante cui si campiona il giroscopio (LivenessService inizia a
  /// campionare subito prima di chiamare questo metodo e si ferma
  /// subito dopo: vedi CaptureFlowNotifier).
  ///
  /// Nota pratica: 3 frame con ~350ms di distanza sono un buon
  /// compromesso fra "abbastanza tempo perché il tremore naturale
  /// della mano produca parallasse" e "non far sembrare la cattura
  /// lenta all'utente". Va ricalibrato provando su device reali.
  Future<List<Uint8List>> captureBurst({
    int frameCount = 3,
    Duration interval = const Duration(milliseconds: 350),
  }) async {
    if (!isInitialized) {
      throw StateError('CameraCaptureService non inizializzato.');
    }
    if (frameCount < 2) {
      throw ArgumentError('Servono almeno 2 frame per calcolare la parallasse.');
    }

    final frames = <Uint8List>[];
    for (var i = 0; i < frameCount; i++) {
      final file = await controller.takePicture();
      frames.add(await file.readAsBytes());
      if (i < frameCount - 1) {
        await Future.delayed(interval);
      }
    }
    return frames;
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}

class CameraCaptureException implements Exception {
  final String message;
  CameraCaptureException(this.message);

  @override
  String toString() => message;
}
