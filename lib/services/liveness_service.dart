import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:sensors_plus/sensors_plus.dart';
import '../models/capture_context.dart';

/// Implements mechanisms 1 and 3 of the anti-photo-of-a-screen plan:
///
/// 1) "Capture as a scan": analyzes a burst of closely spaced frames
///    and measures how UNEVENLY different areas of the image shifted
///    from one frame to the next (parallax). A real 3D scene, even
///    with minimal hand tremor, always shows a bit of parallax
///    between foreground and background. A flat surface (a photo, a
///    screen, a magazine page) simply re-shot twice moves as a block,
///    almost uniformly: parallax near zero.
///
/// 3) "Poor man's AR": instead of integrating a full AR SDK (ARCore/
///    ARKit — too heavy and risky to add without a real device to
///    test on), we sample the gyroscope during the same capture
///    window and require that the phone REALLY moved at least a
///    little. If the gyroscope reports movement but the frames show
///    no parallax (or vice versa: "moved" frames but a still
///    gyroscope, a sign the movement is in the frame and not in the
///    hand), a suspicious inconsistency is flagged.
///
/// IMPORTANT: this is a client-computed signal, so in theory it can
/// be faked by a tampered client. It should therefore always be
/// treated as a clue (useful for blocking 95% of lazy/casual cases)
/// and NEVER as the sole defense: the truly robust barrier remains
/// the server-side-verified double sighting (mechanism 5, see
/// supabase/functions/resolve-sighting).
class LivenessService {
  /// Size (in blocks per side) of the grid used to compare frames. A
  /// 3x3 grid is a good compromise between sensitivity to parallax
  /// and compute cost on a phone.
  static const int _gridSize = 3;

  /// Side length (in pixels) each frame is downscaled to before
  /// comparison: there's no need to work at full resolution to
  /// estimate motion, and doing it on a small image is much faster.
  static const int _analysisSize = 180;

  /// Max size (in pixels, on the downscaled image) of the search
  /// window for block-matching. Higher values = tolerates larger
  /// displacements but costs more to compute.
  static const int _searchRadius = 6;

  StreamSubscription<GyroscopeEvent>? _gyroSub;
  double _gyroIntegral = 0;

  /// Must be called right BEFORE CameraCaptureService.captureBurst().
  void startGyroSampling() {
    _gyroIntegral = 0;
    _gyroSub?.cancel();
    _gyroSub = gyroscopeEvents.listen((event) {
      // Magnitude of the angular velocity vector (rad/s), integrated
      // "in ticks" over the interval between events: a rough but
      // sufficient estimate to tell "phone in hand" apart from
      // "phone still on a tripod/resting on a table".
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      _gyroIntegral += magnitude;
    }, onError: (_) {
      // Some Android devices have no gyroscope: we degrade silently,
      // the signal will simply stay at 0 (motion "not measurable"
      // rather than "suspicious").
    }, cancelOnError: true);
  }

  /// Must be called right AFTER CameraCaptureService.captureBurst(),
  /// passing the frames that were just captured. Stops gyroscope
  /// sampling and produces the full report.
  Future<LivenessReport> finishAndAnalyze(List<Uint8List> frames) async {
    await _gyroSub?.cancel();
    _gyroSub = null;
    final gyroMagnitude = _gyroIntegral;

    final parallax = _analyzeParallax(frames);

    // Verdict heuristic: if the hand produced very little phone
    // movement AND the frames show no significant parallax, the most
    // likely explanation is that a flat, motionless subject
    // (screen/print) is being photographed instead of a real animal.
    // Starting thresholds, to be re-tuned with real data collected
    // from device testing.
    const gyroThreshold = 0.35; // accumulated radians, indicative
    const parallaxThreshold = 0.15; // dimensionless, see _analyzeParallax
    const totalMotionFloor = 0.02; // below this: frames are practically identical

    final tooStill = parallax.totalMotion < totalMotionFloor;
    final noParallaxDespiteMotion =
        gyroMagnitude > gyroThreshold && parallax.varianceScore < parallaxThreshold;

    final looksFlat = tooStill || noParallaxDespiteMotion;

    return LivenessReport(
      parallaxVarianceScore: parallax.varianceScore,
      totalMotionScore: parallax.totalMotion,
      gyroMotionMagnitude: gyroMagnitude,
      looksLikeFlatSurface: looksFlat,
    );
  }

  /// Call this if the player cancels the capture, so no gyroscope
  /// listener is left running in the background.
  void cancel() {
    _gyroSub?.cancel();
    _gyroSub = null;
  }

  _ParallaxResult _analyzeParallax(List<Uint8List> frames) {
    if (frames.length < 2) {
      return const _ParallaxResult(varianceScore: 0, totalMotion: 0);
    }

    final decoded = frames
        .map((bytes) => img.decodeImage(bytes))
        .whereType<img.Image>()
        .map((image) => img.copyResize(
              image,
              width: _analysisSize,
              height: _analysisSize,
              interpolation: img.Interpolation.average,
            ))
        .map(_toGrayscaleBuffer)
        .toList();

    if (decoded.length < 2) {
      // Decoding failed for some frame: we don't block the capture
      // over this, we simply don't have a signal.
      return const _ParallaxResult(varianceScore: 0, totalMotion: 0);
    }

    // We compare the first and last frame of the burst: it's the
    // pair with the widest time baseline, so the one where any
    // natural hand tremor had the most time to produce measurable
    // parallax.
    final first = decoded.first;
    final last = decoded.last;

    final blockSize = _analysisSize ~/ _gridSize;
    final displacements = <_Vector2>[];
    double totalMotion = 0;

    for (var gy = 0; gy < _gridSize; gy++) {
      for (var gx = 0; gx < _gridSize; gx++) {
        final originX = gx * blockSize;
        final originY = gy * blockSize;
        final best = _bestMatch(
          reference: first,
          target: last,
          originX: originX,
          originY: originY,
          blockSize: blockSize,
          searchRadius: _searchRadius,
        );
        displacements.add(best);
        totalMotion += best.magnitude;
      }
    }

    totalMotion /= displacements.length;

    // Variance of the displacement directions/magnitudes across
    // blocks: high if the blocks move differently from each other
    // (real parallax), close to zero if they all move together
    // (rigid translation of a plane). We normalize by the analysis
    // size to get a score comparable regardless of the chosen
    // analysis resolution.
    final meanX = displacements.map((d) => d.dx).reduce((a, b) => a + b) / displacements.length;
    final meanY = displacements.map((d) => d.dy).reduce((a, b) => a + b) / displacements.length;

    double varianceSum = 0;
    for (final d in displacements) {
      final ex = d.dx - meanX;
      final ey = d.dy - meanY;
      varianceSum += ex * ex + ey * ey;
    }
    final variance = varianceSum / displacements.length;
    final normalizedVariance = variance / (_searchRadius * _searchRadius);

    return _ParallaxResult(
      varianceScore: normalizedVariance,
      totalMotion: totalMotion / _searchRadius,
    );
  }

  /// Rough block-matching (SAD, sum of absolute differences) over a
  /// small search window. Good enough to estimate an approximate
  /// per-block displacement without needing dedicated optical-flow
  /// libraries.
  _Vector2 _bestMatch({
    required List<int> reference,
    required List<int> target,
    required int originX,
    required int originY,
    required int blockSize,
    required int searchRadius,
  }) {
    var bestScore = double.infinity;
    var bestDx = 0;
    var bestDy = 0;

    for (var dy = -searchRadius; dy <= searchRadius; dy++) {
      for (var dx = -searchRadius; dx <= searchRadius; dx++) {
        final score = _sadForOffset(
          reference: reference,
          target: target,
          originX: originX,
          originY: originY,
          blockSize: blockSize,
          offsetX: dx,
          offsetY: dy,
        );
        if (score < bestScore) {
          bestScore = score;
          bestDx = dx;
          bestDy = dy;
        }
      }
    }

    return _Vector2(bestDx.toDouble(), bestDy.toDouble());
  }

  double _sadForOffset({
    required List<int> reference,
    required List<int> target,
    required int originX,
    required int originY,
    required int blockSize,
    required int offsetX,
    required int offsetY,
  }) {
    var sum = 0;
    var samples = 0;

    // We sample with a 2px step instead of every pixel: more than
    // enough for an approximate motion estimate, and it cuts the
    // cost by ~4x.
    for (var y = 0; y < blockSize; y += 2) {
      final refY = originY + y;
      final tgtY = refY + offsetY;
      if (tgtY < 0 || tgtY >= _analysisSize) continue;

      for (var x = 0; x < blockSize; x += 2) {
        final refX = originX + x;
        final tgtX = refX + offsetX;
        if (tgtX < 0 || tgtX >= _analysisSize) continue;

        final refValue = reference[refY * _analysisSize + refX];
        final tgtValue = target[tgtY * _analysisSize + tgtX];
        sum += (refValue - tgtValue).abs();
        samples++;
      }
    }

    if (samples == 0) return double.infinity;
    return sum / samples;
  }

  List<int> _toGrayscaleBuffer(img.Image image) {
    final buffer = List<int>.filled(_analysisSize * _analysisSize, 0);
    for (var y = 0; y < _analysisSize; y++) {
      for (var x = 0; x < _analysisSize; x++) {
        final pixel = image.getPixel(x, y);
        // Approximate perceptual luminance (Rec. 601).
        final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).round();
        buffer[y * _analysisSize + x] = gray;
      }
    }
    return buffer;
  }
}

class _Vector2 {
  final double dx;
  final double dy;
  const _Vector2(this.dx, this.dy);
  double get magnitude => sqrt(dx * dx + dy * dy);
}

class _ParallaxResult {
  final double varianceScore;
  final double totalMotion;
  const _ParallaxResult({required this.varianceScore, required this.totalMotion});
}
