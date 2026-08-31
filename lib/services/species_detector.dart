import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Riconosce l'animale in una foto usando Google ML Kit Image
/// Labeling: gira interamente sul dispositivo, gratuito, nessuna
/// chiamata di rete né API key. Il modello è generico (non
/// specializzato in animali), quindi le etichette sono in inglese
/// e piuttosto ampie ("Cat", "Dog", "Bird"...) — le traduciamo e
/// semplifichiamo qui in un piccolo dizionario, con fallback
/// sull'etichetta originale se non la conosciamo.
class SpeciesDetector {
  final ImageLabeler _labeler;

  SpeciesDetector()
      : _labeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.5),
        );

  /// Ritorna il nome (in italiano se lo conosciamo) dell'animale con
  /// confidenza più alta, o null se il modello non riconosce nulla
  /// sopra la soglia di confidenza.
  Future<String?> detectFromFile(File file) async {
    try {
      final inputImage = InputImage.fromFile(file);
      final labels = await _labeler.processImage(inputImage);
      if (labels.isEmpty) return null;

      labels.sort((a, b) => b.confidence.compareTo(a.confidence));
      return _translate(labels.first.label);
    } catch (e) {
      // Non deve mai bloccare la cattura: se il modello fallisce,
      // si procede senza suggerimento di specie.
      return null;
    }
  }

  void dispose() => _labeler.close();

  static const Map<String, String> _translations = {
    'cat': 'gatto',
    'dog': 'cane',
    'bird': 'uccello',
    'pigeon': 'piccione',
    'seagull': 'gabbiano',
    'duck': 'anatra',
    'goose': 'oca',
    'owl': 'gufo',
    'squirrel': 'scoiattolo',
    'rabbit': 'coniglio',
    'hamster': 'criceto',
    'horse': 'cavallo',
    'fish': 'pesce',
    'goldfish': 'pesce rosso',
    'butterfly': 'farfalla',
    'insect': 'insetto',
    'bee': 'ape',
    'ladybug': 'coccinella',
    'turtle': 'tartaruga',
    'lizard': 'lucertola',
    'frog': 'rana',
    'snake': 'serpente',
    'sheep': 'pecora',
    'cow': 'mucca',
    'goat': 'capra',
    'chicken': 'gallina',
    'mouse': 'topo',
    'hedgehog': 'riccio',
    'deer': 'cervo',
    'fox': 'volpe',
  };

  String _translate(String label) {
    final key = label.toLowerCase().trim();
    return _translations[key] ?? key;
  }
}
