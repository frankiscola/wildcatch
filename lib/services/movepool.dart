import 'dart:math';
import '../models/move.dart';

/// Tabella statica delle mosse disponibili per ciascun tipo, divisa
/// in 3 "tier" di potenza crescente. Il tier 1 è quello da cui si
/// pescano le mosse iniziali (livello 5), il tier 2 si sblocca
/// verso metà carriera, il tier 3 con creature già navigate.
///
/// NOTA: questa è una versione MVP con poche mosse per tipo, pensata
/// per essere ampliata facilmente aggiungendo voci alla lista.
/// In produzione conviene spostare questa tabella in una tabella
/// Postgres ('moves') così da poterla ampliare senza rilasci.
class MovePool {
  static const Map<String, List<Move>> _byType = {
    'normale': [
      Move(name: 'Azzannamento', type: 'normale', category: MoveCategory.fisica, power: 35, accuracy: 100, maxPp: 35, tier: 1),
      Move(name: 'Rapidità', type: 'normale', category: MoveCategory.fisica, power: 40, accuracy: 100, maxPp: 30, tier: 1),
      Move(name: 'Colpo Rapido', type: 'normale', category: MoveCategory.fisica, power: 60, accuracy: 100, maxPp: 20, tier: 2),
      Move(name: 'Ipervoce', type: 'normale', category: MoveCategory.speciale, power: 90, accuracy: 100, maxPp: 10, tier: 3),
    ],
    'fuoco': [
      Move(name: 'Braciere', type: 'fuoco', category: MoveCategory.speciale, power: 40, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Morso Infuocato', type: 'fuoco', category: MoveCategory.fisica, power: 45, accuracy: 95, maxPp: 20, tier: 1),
      Move(name: 'Lanciafiamme', type: 'fuoco', category: MoveCategory.speciale, power: 90, accuracy: 100, maxPp: 15, tier: 2),
      Move(name: 'Fuoco Fatuo', type: 'fuoco', category: MoveCategory.stato, power: 0, accuracy: 85, maxPp: 15, tier: 2),
      Move(name: 'Eruzione', type: 'fuoco', category: MoveCategory.speciale, power: 120, accuracy: 100, maxPp: 5, tier: 3),
    ],
    'acqua': [
      Move(name: 'Spruzzo', type: 'acqua', category: MoveCategory.speciale, power: 40, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Bolla', type: 'acqua', category: MoveCategory.speciale, power: 40, accuracy: 100, maxPp: 30, tier: 1),
      Move(name: 'Idropompa', type: 'acqua', category: MoveCategory.speciale, power: 90, accuracy: 90, maxPp: 10, tier: 2),
      Move(name: 'Surf', type: 'acqua', category: MoveCategory.speciale, power: 95, accuracy: 100, maxPp: 15, tier: 2),
      Move(name: "Uragano D'Acqua", type: 'acqua', category: MoveCategory.speciale, power: 120, accuracy: 100, maxPp: 5, tier: 3),
    ],
    'erba': [
      Move(name: 'Frustata', type: 'erba', category: MoveCategory.fisica, power: 45, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Assorbisai', type: 'erba', category: MoveCategory.speciale, power: 20, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Foglielama', type: 'erba', category: MoveCategory.fisica, power: 90, accuracy: 100, maxPp: 15, tier: 2),
      Move(name: 'Solarraggio', type: 'erba', category: MoveCategory.speciale, power: 120, accuracy: 100, maxPp: 10, tier: 3),
    ],
    'elettro': [
      Move(name: 'Scarica', type: 'elettro', category: MoveCategory.speciale, power: 40, accuracy: 100, maxPp: 30, tier: 1),
      Move(name: 'Fulmine Debole', type: 'elettro', category: MoveCategory.speciale, power: 45, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Fulmine', type: 'elettro', category: MoveCategory.speciale, power: 90, accuracy: 100, maxPp: 15, tier: 2),
      Move(name: 'Tuono', type: 'elettro', category: MoveCategory.speciale, power: 110, accuracy: 70, maxPp: 10, tier: 3),
    ],
    'ghiaccio': [
      Move(name: 'Vento Gelido', type: 'ghiaccio', category: MoveCategory.speciale, power: 55, accuracy: 95, maxPp: 15, tier: 1),
      Move(name: 'Palla Gelida', type: 'ghiaccio', category: MoveCategory.speciale, power: 40, accuracy: 90, maxPp: 25, tier: 1),
      Move(name: 'Raggio Gelido', type: 'ghiaccio', category: MoveCategory.speciale, power: 90, accuracy: 100, maxPp: 10, tier: 2),
      Move(name: 'Bufera', type: 'ghiaccio', category: MoveCategory.speciale, power: 110, accuracy: 70, maxPp: 5, tier: 3),
    ],
    'lotta': [
      Move(name: 'Braccio Teso', type: 'lotta', category: MoveCategory.fisica, power: 40, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Doppio Colpo', type: 'lotta', category: MoveCategory.fisica, power: 35, accuracy: 90, maxPp: 30, tier: 1),
      Move(name: 'Attacco Rissoso', type: 'lotta', category: MoveCategory.fisica, power: 85, accuracy: 100, maxPp: 15, tier: 2),
      Move(name: 'Focus Blast', type: 'lotta', category: MoveCategory.speciale, power: 120, accuracy: 70, maxPp: 5, tier: 3),
    ],
    'veleno': [
      Move(name: 'Fuliggine Tossica', type: 'veleno', category: MoveCategory.speciale, power: 40, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Puntura Velenosa', type: 'veleno', category: MoveCategory.fisica, power: 15, accuracy: 100, maxPp: 35, tier: 1),
      Move(name: 'Fuoco Tossico', type: 'veleno', category: MoveCategory.speciale, power: 90, accuracy: 100, maxPp: 10, tier: 2),
      Move(name: "Attacco D'Acido", type: 'veleno', category: MoveCategory.speciale, power: 100, accuracy: 90, maxPp: 10, tier: 3),
    ],
    'terra': [
      Move(name: 'Colpo Fossa', type: 'terra', category: MoveCategory.fisica, power: 45, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Lancio Sabbia', type: 'terra', category: MoveCategory.stato, power: 0, accuracy: 100, maxPp: 15, tier: 1),
      Move(name: 'Terremoto', type: 'terra', category: MoveCategory.fisica, power: 100, accuracy: 100, maxPp: 10, tier: 2),
      Move(name: 'Terra Aumentata', type: 'terra', category: MoveCategory.fisica, power: 90, accuracy: 85, maxPp: 10, tier: 3),
    ],
    'volante': [
      Move(name: 'Beccata', type: 'volante', category: MoveCategory.fisica, power: 35, accuracy: 100, maxPp: 35, tier: 1),
      Move(name: 'Turbine', type: 'volante', category: MoveCategory.speciale, power: 40, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Acrobazia', type: 'volante', category: MoveCategory.fisica, power: 85, accuracy: 100, maxPp: 15, tier: 2),
      Move(name: 'Uragano', type: 'volante', category: MoveCategory.speciale, power: 110, accuracy: 70, maxPp: 10, tier: 3),
    ],
    'psico': [
      Move(name: 'Confusione', type: 'psico', category: MoveCategory.speciale, power: 50, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Extrasenso', type: 'psico', category: MoveCategory.speciale, power: 40, accuracy: 100, maxPp: 20, tier: 1),
      Move(name: 'Psicoshock', type: 'psico', category: MoveCategory.speciale, power: 80, accuracy: 100, maxPp: 10, tier: 2),
      Move(name: 'Psicocinesi', type: 'psico', category: MoveCategory.speciale, power: 90, accuracy: 100, maxPp: 10, tier: 3),
    ],
    'coleottero': [
      Move(name: 'Attacco Furia', type: 'coleottero', category: MoveCategory.fisica, power: 15, accuracy: 85, maxPp: 20, tier: 1),
      Move(name: 'Ronzio', type: 'coleottero', category: MoveCategory.speciale, power: 40, accuracy: 100, maxPp: 20, tier: 1),
      Move(name: 'Megatorma', type: 'coleottero', category: MoveCategory.fisica, power: 90, accuracy: 100, maxPp: 10, tier: 2),
      Move(name: 'Attacco Prima Vera', type: 'coleottero', category: MoveCategory.fisica, power: 70, accuracy: 100, maxPp: 15, tier: 3),
    ],
    'roccia': [
      Move(name: 'Lancio Massi', type: 'roccia', category: MoveCategory.fisica, power: 50, accuracy: 90, maxPp: 15, tier: 1),
      Move(name: 'Tackle Rio', type: 'roccia', category: MoveCategory.fisica, power: 45, accuracy: 95, maxPp: 20, tier: 1),
      Move(name: 'Pietrataglio', type: 'roccia', category: MoveCategory.fisica, power: 100, accuracy: 80, maxPp: 5, tier: 2),
      Move(name: 'Frana', type: 'roccia', category: MoveCategory.fisica, power: 75, accuracy: 90, maxPp: 10, tier: 3),
    ],
    'spettro': [
      Move(name: 'Pugno Ombra', type: 'spettro', category: MoveCategory.fisica, power: 40, accuracy: 100, maxPp: 15, tier: 1),
      Move(name: 'Sguardo Furtivo', type: 'spettro', category: MoveCategory.stato, power: 0, accuracy: 100, maxPp: 30, tier: 1),
      Move(name: 'Palla Ombra', type: 'spettro', category: MoveCategory.speciale, power: 80, accuracy: 100, maxPp: 15, tier: 2),
      Move(name: "Attacco D'Ombra", type: 'spettro', category: MoveCategory.fisica, power: 90, accuracy: 100, maxPp: 10, tier: 3),
    ],
    'drago': [
      Move(name: 'Furia Draconica', type: 'drago', category: MoveCategory.speciale, power: 40, accuracy: 100, maxPp: 10, tier: 1),
      Move(name: 'Morso', type: 'drago', category: MoveCategory.fisica, power: 60, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Danza Drago', type: 'drago', category: MoveCategory.stato, power: 0, accuracy: 100, maxPp: 20, tier: 2),
      Move(name: 'Vampata Drago', type: 'drago', category: MoveCategory.speciale, power: 100, accuracy: 100, maxPp: 5, tier: 3),
    ],
    'buio': [
      Move(name: 'Morso Rapido', type: 'buio', category: MoveCategory.fisica, power: 40, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Sguardo Buio', type: 'buio', category: MoveCategory.stato, power: 0, accuracy: 100, maxPp: 30, tier: 1),
      Move(name: 'Attacco Furtivo', type: 'buio', category: MoveCategory.fisica, power: 40, accuracy: 100, maxPp: 30, tier: 2),
      Move(name: 'Cricca', type: 'buio', category: MoveCategory.fisica, power: 80, accuracy: 100, maxPp: 15, tier: 3),
    ],
    'acciaio': [
      Move(name: "Colpo D'Acciaio", type: 'acciaio', category: MoveCategory.fisica, power: 40, accuracy: 100, maxPp: 35, tier: 1),
      Move(name: 'Difesa Ferrea', type: 'acciaio', category: MoveCategory.stato, power: 0, accuracy: 100, maxPp: 15, tier: 1),
      Move(name: 'Testata Di Ferro', type: 'acciaio', category: MoveCategory.fisica, power: 80, accuracy: 100, maxPp: 15, tier: 2),
      Move(name: 'Meteorpugno', type: 'acciaio', category: MoveCategory.fisica, power: 90, accuracy: 90, maxPp: 10, tier: 3),
    ],
  };

  /// Le 4 mosse iniziali di una creatura appena catturata: sempre
  /// dal tier 1, sempre coerenti col suo tipo (o tipi, se già a due).
  List<Move> starterMoves(List<String> types, {Random? random}) {
    final rng = random ?? Random();
    final pool = <Move>[];
    for (final type in types) {
      pool.addAll(_movesOfTier(type, 1));
    }
    // Se il pool ha meno di 4 mosse, si integra con mosse normali generiche.
    pool.addAll(_movesOfTier('normale', 1));

    pool.shuffle(rng);
    final unique = <String, Move>{};
    for (final move in pool) {
      unique[move.name] = move;
      if (unique.length == 4) break;
    }
    return unique.values.toList();
  }

  /// Una mossa più forte da proporre come sostituzione, sbloccata al
  /// livello corrente. Restituisce null se non c'è nulla di nuovo
  /// da imparare a questo livello (si richiama ogni N livelli, la
  /// cadenza la decide il chiamante).
  Move? nextMoveToLearn({
    required List<String> types,
    required int level,
    required List<String> alreadyKnownNames,
    Random? random,
  }) {
    final rng = random ?? Random();
    final targetTier = level >= 60 ? 3 : (level >= 25 ? 2 : 1);

    final candidates = <Move>[];
    for (final type in types) {
      candidates.addAll(
        _movesOfTier(type, targetTier)
            .where((m) => !alreadyKnownNames.contains(m.name)),
      );
    }
    if (candidates.isEmpty) return null;
    candidates.shuffle(rng);
    return candidates.first;
  }

  List<Move> _movesOfTier(String type, int tier) {
    final all = _byType[type.toLowerCase()] ?? const [];
    return all.where((m) => m.tier == tier).toList();
  }
}
