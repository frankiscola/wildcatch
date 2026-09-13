import 'dart:typed_data';
import 'package:camera/camera.dart';

/// Wraps use of the device's LIVE camera.
///
/// IMPORTANT: this is now the ONLY way to provide a photo for a
/// capture. There's no longer, anywhere in the UI, a "choose from
/// gallery" button: that's the fundamental prerequisite for the rest
/// of the anti-photo-of-a-screen plan (see liveness_service and
/// supabase/functions/resolve-sighting) — without this constraint,
/// anyone could simply bypass every check by picking an already-made
/// photo instead of taking a live one.
///
/// `image_picker` stays in the pubspec only as a transitive
/// dependency of other packages; it must no longer be used with
/// `ImageSource.gallery` anywhere in the app.
class CameraCaptureService {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  CameraController get controller {
    final c = _controller;
    if (c == null) {
      throw StateError('CameraCaptureService not initialized: call initialize() first.');
    }
    return c;
  }

  Future<void> initialize() async {
    if (isInitialized) return;

    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw CameraCaptureException('No camera available on this device.');
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

  /// Takes [frameCount] photos spaced [interval] apart, returning
  /// them in chronological order.
  ///
  /// This burst is the raw material for both the parallax score
  /// (LivenessService.analyzeParallax) and the time window during
  /// which the gyroscope is sampled (LivenessService starts sampling
  /// right before calling this method and stops right after: see
  /// CaptureFlowNotifier).
  ///
  /// Practical note: 3 frames ~350ms apart is a good compromise
  /// between "enough time for natural hand tremor to produce
  /// parallax" and "not making the capture feel slow to the player".
  /// Should be re-tuned by testing on real devices.
  Future<List<Uint8List>> captureBurst({
    int frameCount = 3,
    Duration interval = const Duration(milliseconds: 350),
  }) async {
    if (!isInitialized) {
      throw StateError('CameraCaptureService not initialized.');
    }
    if (frameCount < 2) {
      throw ArgumentError('At least 2 frames are needed to compute parallax.');
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
