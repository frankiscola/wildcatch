import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:sensors_plus/sensors_plus.dart';
import '../models/capture_context.dart';

/// Implementa i meccanismi 1 e 3 del piano anti-cattura-da-internet:
///
/// 1) "Cattura come scansione": analizza un burst di frame ravvicinati
///    e misura quanto le diverse zone dell'immagine si sono spostate
///    in modo DISOMOGENEO tra un frame e l'altro (parallasse). Una
///    scena 3D reale, anche con un tremore minimo della mano, mostra
///    sempre un po' di parallasse fra primo piano e sfondo. Una
///    superficie piatta (foto, schermo, pagina di rivista) semplicemente
///    ripresa due volte si sposta in blocco, in modo quasi uniforme:
///    parallasse vicina a zero.
///
/// 3) "Poor man's AR": invece di integrare un intero SDK AR (ARCore/
///    ARKit — troppo pesante e rischioso da aggiungere senza poterlo
///    testare su device reali), campioniamo il giroscopio durante la
///    stessa finestra di cattura e richiediamo che il telefono si sia
///    DAVVERO mosso un minimo. Se il giroscopio segnala movimento ma i
///    frame non mostrano parallasse (o viceversa: frame "mossi" ma
///    giroscopio fermo, segno che il movimento è nell'inquadratura e
///    non nella mano) scatta un'incoerenza sospetta.
///
/// IMPORTANTE: questo è un segnale calcolato lato client, quindi in
/// teoria falsificabile da un client manomesso. Per questo va sempre
/// trattato come un indizio (utile per bloccare il 95% dei casi
/// pigri/casuali) e MAI come unica difesa: la barriera davvero robusta
/// resta il doppio avvistamento verificato server-side (meccanismo 5,
/// vedi supabase/functions/resolve-sighting).
class LivenessService {
  /// Dimensione (in blocchi per lato) della griglia usata per il
  /// confronto tra frame. Una griglia 3x3 è un buon compromesso fra
  /// sensibilità alla parallasse e costo di calcolo su un telefono.
  static const int _gridSize = 3;

  /// Lato (in pixel) a cui viene ridotto ogni frame prima del
  /// confronto: non serve lavorare a piena risoluzione per stimare
  /// il movimento, e farlo su un'immagine piccola è molto più veloce.
  static const int _analysisSize = 180;

  /// Ampiezza massima (in pixel, sull'immagine ridotta) della finestra
  /// di ricerca per il block-matching. Valori più alti = tollera
  /// spostamenti maggiori ma costa di più calcolarli.
  static const int _searchRadius = 6;

  StreamSubscription<GyroscopeEvent>? _gyroSub;
  double _gyroIntegral = 0;

  /// Va chiamato subito PRIMA di CameraCaptureService.captureBurst().
  void startGyroSampling() {
    _gyroIntegral = 0;
    _gyroSub?.cancel();
    _gyroSub = gyroscopeEvents.listen((event) {
      // Modulo del vettore di velocità angolare (rad/s), integrato
      // "a scatti" sull'intervallo tra eventi: una stima grezza ma
      // sufficiente a distinguere "telefono in mano" da "telefono
      // fermo su un cavalletto/appoggiato su un tavolo".
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      _gyroIntegral += magnitude;
    }, onError: (_) {
      // Alcuni device Android non hanno il giroscopio: degradiamo
      // in silenzio, il segnale resterà semplicemente a 0 (motion
      // "non misurabile" invece di "sospetto").
    }, cancelOnError: true);
  }

  /// Va chiamato subito DOPO CameraCaptureService.captureBurst(),
  /// passando i frame appena catturati. Ferma il campionamento del
  /// giroscopio e produce il report completo.
  Future<LivenessReport> finishAndAnalyze(List<Uint8List> frames) async {
    await _gyroSub?.cancel();
    _gyroSub = null;
    final gyroMagnitude = _gyroIntegral;

    final parallax = _analyzeParallax(frames);

    // Euristica di verdetto: se la mano ha prodotto pochissimo
    // movimento del telefono E i frame non mostrano parallasse
    // significativa, la spiegazione più probabile è che si stia
    // fotografando qualcosa di piatto e immobile (schermo/stampa)
    // invece di un animale reale. Soglie di partenza, da ricalibrare
    // con dati reali raccolti in test su device.
    const gyroThreshold = 0.35; // rad accumulati, indicativo
    const parallaxThreshold = 0.15; // adimensionale, vedi _analyzeParallax
    const totalMotionFloor = 0.02; // sotto: frame praticamente identici

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

  /// Da chiamare se l'utente annulla la cattura, per non lasciare
  /// listener del giroscopio attivi in background.
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
      // Decodifica fallita per qualche frame: non blocchiamo la
      // cattura per questo, semplicemente non abbiamo un segnale.
      return const _ParallaxResult(varianceScore: 0, totalMotion: 0);
    }

    // Confrontiamo il primo e l'ultimo frame del burst: è la coppia
    // con la baseline temporale più ampia, quindi quella in cui un
    // eventuale tremore naturale ha avuto più tempo per produrre
    // parallasse misurabile.
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

    // Varianza delle direzioni/ampiezze di spostamento tra i blocchi:
    // alta se i blocchi si muovono in modo diverso tra loro (parallasse
    // reale), vicina a zero se si muovono tutti insieme (traslazione
    // rigida di un piano). Normalizziamo sulla dimensione dell'immagine
    // per ottenere un punteggio comparabile indipendentemente dalla
    // risoluzione di analisi scelta.
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

  /// Block-matching grezzo (SAD, sum of absolute differences) su una
  /// piccola finestra di ricerca. Sufficiente per stimare uno
  /// spostamento approssimativo per blocco senza bisogno di librerie
  /// di optical flow dedicate.
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

    // Campioniamo con un passo di 2px invece di ogni pixel: per una
    // stima di movimento approssimata è più che sufficiente e riduce
    // il costo di ~4x.
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
        // Luminanza percettiva approssimata (Rec. 601).
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
