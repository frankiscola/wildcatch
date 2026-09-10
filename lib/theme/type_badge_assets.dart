/// Percorso dell'immagine del badge per ciascun tipo. I file sono
/// ritagli dall'immagine fornita dall'utente (badge "lucidi" stile
/// smalto), isolati su sfondo trasparente. Vedi assets/type_badges/.
///
/// NOTA: l'immagine originale copriva 18 tipi in stile molto vicino
/// all'iconografia di un franchise commerciale noto; qui sono stati
/// tenuti SOLO i 12 che corrispondono al roster di WildKin. È una
/// scelta consapevole dell'utente, che si assume la responsabilità
/// del rischio IP legato a queste immagini specifiche.
class TypeBadgeAssets {
  TypeBadgeAssets._();

  static const Map<String, String> byName = {
    'fuoco': 'assets/type_badges/fuoco.png',
    'acqua': 'assets/type_badges/acqua.png',
    'elettro': 'assets/type_badges/elettro.png',
    'erba': 'assets/type_badges/erba.png',
    'ghiaccio': 'assets/type_badges/ghiaccio.png',
    'veleno': 'assets/type_badges/veleno.png',
    'terra': 'assets/type_badges/terra.png',
    'volante': 'assets/type_badges/volante.png',
    'psico': 'assets/type_badges/psico.png',
    'coleottero': 'assets/type_badges/coleottero.png',
    'roccia': 'assets/type_badges/roccia.png',
    'buio': 'assets/type_badges/buio.png',
  };

  /// Ritorna il path dell'asset, o null se il tipo non è tra i 12
  /// (in quel caso il chiamante può ripiegare su TypeIcons/TypeColors).
  static String? of(String type) => byName[type.toLowerCase()];
}
