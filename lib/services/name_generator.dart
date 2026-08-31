import 'dart:math';

/// Compone un nome in stile Pokemon fondendo la specie rilevata
/// dalla foto (es. "gatto") con il tipo elementale assegnato alla
/// creatura (es. "fuoco"), con la stessa logica dei nomi portmanteau
/// dei giochi originali (Char + Salamander = Charmander).
///
/// Puramente basato su regole/liste di frammenti: nessuna chiamata
/// esterna, nessun costo, risultato immediato.
class NameGenerator {
  final Random _random;

  NameGenerator({Random? random}) : _random = random ?? Random();

  // Frammenti "prima del nome" (prefissi) e "dopo il nome" (suffissi)
  // evocativi di ciascun tipo. Se un tipo non è in lista si usa
  // 'normale' come fallback.
  static const Map<String, List<String>> _prefixes = {
    'fuoco': ['Piro', 'Brace', 'Infer', 'Ember'],
    'acqua': ['Idro', 'Aqua', 'Marea', 'Onda'],
    'erba': ['Fillo', 'Verde', 'Clorofil', 'Rampi'],
    'elettro': ['Volt', 'Elettro', 'Fulmo', 'Ampe'],
    'ghiaccio': ['Crio', 'Gelo', 'Brina', 'Glacio'],
    'lotta': ['Furio', 'Pugno', 'Marzia', 'Rissa'],
    'veleno': ['Tossi', 'Veleno', 'Acido', 'Bava'],
    'terra': ['Terra', 'Argil', 'Sabbio', 'Geo'],
    'volante': ['Aero', 'Piuma', 'Vento', 'Ali'],
    'psico': ['Psiche', 'Mente', 'Onir', 'Telepa'],
    'coleottero': ['Chitino', 'Antenna', 'Larva', 'Elitro'],
    'roccia': ['Roccia', 'Petra', 'Basalt', 'Silice'],
    'spettro': ['Spettro', 'Ombra', 'Fantasma', 'Etere'],
    'drago': ['Draco', 'Wyrm', 'Squama', 'Rettil'],
    'buio': ['Ombra', 'Notte', 'Oscuro', 'Tenebra'],
    'acciaio': ['Ferro', 'Metal', 'Lega', 'Corazza'],
    'normale': ['Comu', 'Vaga', 'Terr', 'Selva'],
  };

  static const Map<String, List<String>> _suffixes = {
    'fuoco': ['ardente', 'fiamma', 'brace', 'ustio'],
    'acqua': ['acqua', 'onda', 'marino', 'fluido'],
    'erba': ['foglia', 'rampicante', 'fiore', 'verde'],
    'elettro': ['volt', 'scarica', 'elettro', 'ampere'],
    'ghiaccio': ['gelo', 'glacio', 'brina', 'cristallo'],
    'lotta': ['pugno', 'colpo', 'furia', 'forza'],
    'veleno': ['veleno', 'tossina', 'bava', 'acido'],
    'terra': ['terra', 'sabbia', 'argilla', 'roccioso'],
    'volante': ['ali', 'piuma', 'vento', 'volo'],
    'psico': ['mente', 'psiche', 'sogno', 'aura'],
    'coleottero': ['elitra', 'chitina', 'larva', 'antenna'],
    'roccia': ['roccia', 'pietra', 'basalto', 'selce'],
    'spettro': ['ombra', 'spettro', 'fantasma', 'etere'],
    'drago': ['drago', 'squama', 'wyrm', 'fauci'],
    'buio': ['ombra', 'notte', 'tenebra', 'oscurità'],
    'acciaio': ['ferro', 'acciaio', 'corazza', 'lega'],
    'normale': ['selvatico', 'comune', 'vagante', 'libero'],
  };

  /// [species] è la specie rilevata (es. "gatto"); se null o vuota
  /// si usa "creatura" come base neutra. [types] sono i tipi già
  /// assegnati alla creatura (basta il primo, quello posseduto alla
  /// cattura).
  String generate(String? species, List<String> types) {
    final base = (species == null || species.trim().isEmpty)
        ? 'creatura'
        : species.trim().toLowerCase();
    final stem = _stemOf(base);

    final primaryType = types.isNotEmpty ? types.first.toLowerCase() : 'normale';
    final prefixes = _prefixes[primaryType] ?? _prefixes['normale']!;
    final suffixes = _suffixes[primaryType] ?? _suffixes['normale']!;

    // 50/50 tra "SpecieSuffisso" (es. Gattardente) e
    // "PrefissoSpecie" (es. Idrogatto), per un po' di varietà.
    if (_random.nextBool()) {
      final suffix = suffixes[_random.nextInt(suffixes.length)];
      return _capitalize(stem) + suffix;
    } else {
      final prefix = prefixes[_random.nextInt(prefixes.length)];
      return prefix + _lowerFirst(stem);
    }
  }

  /// Toglie la vocale finale (o/a/e) dalla specie per rendere la
  /// fusione più naturale: "gatto" -> "gatt", "farfalla" -> "farfall".
  String _stemOf(String species) {
    if (species.length <= 3) return species;
    final lastChar = species[species.length - 1];
    if (lastChar == 'o' || lastChar == 'a' || lastChar == 'e') {
      return species.substring(0, species.length - 1);
    }
    return species;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _lowerFirst(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}
