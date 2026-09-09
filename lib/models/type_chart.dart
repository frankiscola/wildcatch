/// Tabella di efficacia tra i 12 tipi finali del gioco.
///
/// Ogni riga descrive, dal punto di vista del tipo DIFENSORE, come
/// reagisce se colpito da una mossa di un certo tipo:
///  - weakTo: tipi contro cui è debole (subisce 2x danno)
///  - resists: tipi contro cui resiste (subisce 0.5x danno)
///  - immuneTo: tipi a cui è immune (subisce 0x danno)
/// Se un tipo attaccante non compare in nessuna delle tre liste, il
/// moltiplicatore è 1x (nessun effetto).
///
/// NOTA: se una creatura ha due tipi, i moltiplicatori dei due tipi
/// si moltiplicano tra loro (esattamente come nei giochi originali):
/// una mossa Acqua contro un bersaglio Fuoco/Roccia fa 2x * 2x = 4x.
class TypeChart {
  static const List<String> orderedTypes = [
    'fuoco', 'acqua', 'elettro', 'erba', 'ghiaccio', 'veleno',
    'terra', 'volante', 'psico', 'coleottero', 'roccia', 'buio',
  ];

  static const Map<String, _TypeMatchups> _chart = {
    'fuoco': _TypeMatchups(
      weakTo: {'acqua', 'terra', 'roccia'},
      resists: {'fuoco', 'erba', 'ghiaccio', 'coleottero'},
    ),
    'acqua': _TypeMatchups(
      weakTo: {'elettro', 'erba', 'ghiaccio'},
      resists: {'fuoco', 'acqua'},
    ),
    'elettro': _TypeMatchups(
      weakTo: {'terra'},
      resists: {'elettro', 'volante'},
    ),
    'erba': _TypeMatchups(
      weakTo: {'fuoco', 'coleottero', 'veleno'},
      resists: {'acqua', 'elettro', 'erba', 'terra'},
    ),
    'ghiaccio': _TypeMatchups(
      weakTo: {'fuoco'},
      resists: {'ghiaccio'},
    ),
    'veleno': _TypeMatchups(
      weakTo: {'terra', 'psico'},
      resists: {'erba', 'veleno', 'coleottero', 'roccia'},
    ),
    'terra': _TypeMatchups(
      weakTo: {'acqua', 'erba', 'ghiaccio'},
      resists: {'veleno', 'roccia'},
      immuneTo: {'elettro'},
    ),
    'volante': _TypeMatchups(
      weakTo: {'elettro', 'ghiaccio'},
      immuneTo: {'terra'},
    ),
    'psico': _TypeMatchups(
      weakTo: {'buio', 'coleottero'},
      resists: {'psico'},
    ),
    'coleottero': _TypeMatchups(
      weakTo: {'fuoco', 'volante', 'roccia'},
      resists: {'erba', 'terra'},
    ),
    'roccia': _TypeMatchups(
      weakTo: {'acqua', 'erba'},
      resists: {'fuoco', 'veleno', 'volante'},
    ),
    'buio': _TypeMatchups(
      weakTo: {'psico'},
      resists: {'buio'},
    ),
  };

  /// Vista leggibile dei matchup, nell'ordine di [orderedTypes], per
  /// la schermata di aiuto in-app. `_chart` resta privata perché la
  /// usa solo [effectiveness]; questo getter è l'unica via pensata
  /// per il resto dell'app.
  static List<TypeMatchupInfo> get all => orderedTypes.map((type) {
        final matchups = _chart[type]!;
        return TypeMatchupInfo(
          type: type,
          weakTo: matchups.weakTo.toList()..sort(),
          resists: matchups.resists.toList()..sort(),
          immuneTo: matchups.immuneTo.toList()..sort(),
        );
      }).toList();

  /// Moltiplicatore di danno di una mossa di tipo [attackType] contro
  /// un bersaglio con i tipi [defenderTypes] (1 o 2 tipi).
  static double effectiveness(String attackType, List<String> defenderTypes) {
    var multiplier = 1.0;
    for (final defenderType in defenderTypes) {
      final matchups = _chart[defenderType.toLowerCase()];
      if (matchups == null) continue;

      final attack = attackType.toLowerCase();
      if (matchups.immuneTo.contains(attack)) {
        multiplier *= 0.0;
      } else if (matchups.weakTo.contains(attack)) {
        multiplier *= 2.0;
      } else if (matchups.resists.contains(attack)) {
        multiplier *= 0.5;
      }
      // altrimenti 1x, nessuna modifica
    }
    return multiplier;
  }
}

/// Un tipo con le sue relazioni (debole/resiste/immune), in forma
/// pubblica e leggibile: usata dalla schermata di aiuto per costruire
/// la tabella che vede il giocatore.
class TypeMatchupInfo {
  final String type;
  final List<String> weakTo;
  final List<String> resists;
  final List<String> immuneTo;

  const TypeMatchupInfo({
    required this.type,
    required this.weakTo,
    required this.resists,
    required this.immuneTo,
  });
}

class _TypeMatchups {
  final Set<String> weakTo;
  final Set<String> resists;
  final Set<String> immuneTo;

  const _TypeMatchups({
    this.weakTo = const {},
    this.resists = const {},
    this.immuneTo = const {},
  });
}
