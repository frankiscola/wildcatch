import 'dart:math';
import '../models/creature.dart';
import '../models/move.dart';
import '../models/wild_encounter.dart';

/// Esito di un singolo attacco.
class AttackResult {
  final bool hit;
  final int damage;
  final bool fainted; // true se il bersaglio è stato messo KO

  const AttackResult({required this.hit, required this.damage, required this.fainted});
}

/// Gestisce la risoluzione dei turni di battaglia e il tentativo
/// di cattura. Il danno usa una versione semplificata della formula
/// ufficiale (niente STAB/efficacia di tipo per l'MVP, facilmente
/// aggiungibile in seguito con una tabella di efficacia tipo x tipo).
class BattleEngine {
  final Random _random;

  BattleEngine({Random? random}) : _random = random ?? Random();

  /// Il proprio Pokemon attacca la creatura selvatica.
  AttackResult attackWild({
    required Creature attacker,
    required WildEncounter target,
    required Move move,
  }) {
    final stats = attacker.computeStats();
    return _resolveAttack(
      move: move,
      attackerLevel: attacker.level,
      attackStat: move.category == MoveCategory.fisica ? stats.attack : stats.spAttack,
      defenseStat: move.category == MoveCategory.fisica
          ? _wildDefense(target)
          : _wildSpDefense(target),
      targetCurrentHp: target.currentHp,
    );
  }

  /// La creatura selvatica contrattacca.
  AttackResult attackOwn({
    required WildEncounter attacker,
    required Creature target,
    required Move move,
  }) {
    final stats = target.computeStats();
    return _resolveAttack(
      move: move,
      attackerLevel: attacker.level,
      attackStat: move.category == MoveCategory.fisica
          ? _wildAttack(attacker)
          : _wildSpAttack(attacker),
      defenseStat: move.category == MoveCategory.fisica ? stats.defense : stats.spDefense,
      targetCurrentHp: target.currentHp,
    );
  }

  AttackResult _resolveAttack({
    required Move move,
    required int attackerLevel,
    required int attackStat,
    required int defenseStat,
    required int targetCurrentHp,
  }) {
    if (move.category == MoveCategory.stato) {
      return const AttackResult(hit: true, damage: 0, fainted: false);
    }

    final hit = _random.nextInt(100) < move.accuracy;
    if (!hit) return const AttackResult(hit: false, damage: 0, fainted: false);

    // Formula di danno semplificata (schema classico, senza STAB/efficacia).
    final base = (((2 * attackerLevel / 5 + 2) * move.power * attackStat / defenseStat) / 50) + 2;
    final randomFactor = 0.85 + _random.nextDouble() * 0.15;
    final damage = max(1, (base * randomFactor).floor());

    final fainted = damage >= targetCurrentHp;
    return AttackResult(hit: true, damage: damage, fainted: fainted);
  }

  /// Tentativo di cattura: più la creatura selvatica è indebolita,
  /// più la probabilità sale. Ispirata alla formula classica
  /// (catchRate legato a HP correnti/massimi), semplificata con un
  /// unico "tasso di cattura base" per tutte le creature (0-255 come
  /// nei giochi originali; 190 è un valore medio-facile).
  ///
  /// Ritorna un valore 0.0-1.0 = probabilità di successo.
  double catchProbability(WildEncounter target, {int baseCatchRate = 190}) {
    final hpFactor = (3 * target.maxHp - 2 * target.currentHp) / (3 * target.maxHp);
    final raw = hpFactor * (baseCatchRate / 255);
    return raw.clamp(0.03, 0.98); // mai 0% né 100% garantito, per tensione
  }

  bool attemptCatch(WildEncounter target, {int baseCatchRate = 190}) {
    final probability = catchProbability(target, baseCatchRate: baseCatchRate);
    return _random.nextDouble() < probability;
  }

  // Stat "virtuali" per una creatura selvatica: stessa formula di
  // Creature.computeStats() ma applicata ai suoi baseStats.
  int _wildAttack(WildEncounter w) => _statAt(w.baseStats.attack, w.level);
  int _wildDefense(WildEncounter w) => _statAt(w.baseStats.defense, w.level);
  int _wildSpAttack(WildEncounter w) => _statAt(w.baseStats.spAttack, w.level);
  int _wildSpDefense(WildEncounter w) => _statAt(w.baseStats.spDefense, w.level);

  int _statAt(int base, int level) => (((2 * base) * level) / 100).floor() + 5;
}
