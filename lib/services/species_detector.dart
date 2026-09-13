import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Recognizes the animal in a photo using Google ML Kit Image
/// Labeling: runs entirely on-device, free, no network call or API
/// key needed. The model is generic (not animal-specialized), so
/// labels are broad English words ("Cat", "Dog", "Bird"...) — we
/// just lowercase/trim them here for consistent use downstream.
class SpeciesDetector {
  final ImageLabeler _labeler;

  SpeciesDetector()
      : _labeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.5),
        );

  /// Returns the name of the highest-confidence animal label, or
  /// null if the model doesn't recognize anything above the
  /// confidence threshold.
  Future<String?> detectFromFile(File file) async {
    try {
      final inputImage = InputImage.fromFile(file);
      final labels = await _labeler.processImage(inputImage);
      if (labels.isEmpty) return null;

      labels.sort((a, b) => b.confidence.compareTo(a.confidence));
      return _clean(labels.first.label);
    } catch (e) {
      // Should never block the capture flow: if the model fails, we
      // just proceed without a species hint.
      return null;
    }
  }

  /// Same as [detectFromFile], but for bytes already in memory (the
  /// burst frames from CameraCaptureService no longer come from an
  /// XFile picked via ImagePicker). ML Kit in this version needs a
  /// path on disk, so we write a disposable temp file.
  Future<String?> detectFromBytes(Uint8List bytes) async {
    File? tempFile;
    try {
      tempFile = await File(
        '${Directory.systemTemp.path}/wildkin_species_${DateTime.now().microsecondsSinceEpoch}.jpg',
      ).create();
      await tempFile.writeAsBytes(bytes);
      return await detectFromFile(tempFile);
    } catch (e) {
      return null;
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  void dispose() => _labeler.close();

  String _clean(String label) => label.toLowerCase().trim();
}
