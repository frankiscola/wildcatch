import 'dart:math';
import '../models/wildkin.dart';
import '../models/move.dart';
import '../models/type_chart.dart';
import '../models/wild_encounter.dart';

/// Outcome of a single attack.
class AttackResult {
  final bool hit;
  final int damage;
  final bool fainted; // true if the target was knocked out
  final double effectiveness; // 0, 0.25, 0.5, 1, 2, or 4 (two weak types)

  const AttackResult({
    required this.hit,
    required this.damage,
    required this.fainted,
    this.effectiveness = 1.0,
  });

  /// A Field-Journal-style message to show after the attack, or null
  /// if there's nothing notable to report (normal effectiveness).
  String? get effectivenessMessage {
    if (effectiveness <= 0) return 'It has no effect...';
    if (effectiveness >= 4) return 'It\'s DEVASTATING!';
    if (effectiveness >= 2) return 'It\'s super effective!';
    if (effectiveness < 1) return 'It\'s not very effective...';
    return null; // normal effect, no special message
  }
}

/// Handles resolving battle turns and capture attempts. Damage uses
/// a simplified version of the official formula (no STAB for the
/// MVP, but with type effectiveness, see TypeChart).
class BattleEngine {
  final Random _random;

  BattleEngine({Random? random}) : _random = random ?? Random();

  /// The player's own Wildkin attacks the wild one.
  AttackResult attackWild({
    required Wildkin attacker,
    required WildEncounter target,
    required Move move,
  }) {
    final stats = attacker.computeStats();
    return _resolveAttack(
      move: move,
      attackerLevel: attacker.level,
      attackStat: move.category == MoveCategory.physical ? stats.attack : stats.elementalAttack,
      defenseStat: move.category == MoveCategory.physical
          ? _wildDefense(target)
          : _wildWard(target),
      targetCurrentHp: target.currentHp,
      defenderTypes: target.types,
    );
  }

  /// The wild Wildkin counterattacks.
  AttackResult attackOwn({
    required WildEncounter attacker,
    required Wildkin target,
    required Move move,
  }) {
    final stats = target.computeStats();
    return _resolveAttack(
      move: move,
      attackerLevel: attacker.level,
      attackStat: move.category == MoveCategory.physical
          ? _wildAttack(attacker)
          : _wildInsight(attacker),
      defenseStat: move.category == MoveCategory.physical ? stats.defense : stats.elementalDefense,
      targetCurrentHp: target.currentHp,
      defenderTypes: target.types,
    );
  }

  AttackResult _resolveAttack({
    required Move move,
    required int attackerLevel,
    required int attackStat,
    required int defenseStat,
    required int targetCurrentHp,
    required List<String> defenderTypes,
  }) {
    if (move.category == MoveCategory.status) {
      return const AttackResult(hit: true, damage: 0, fainted: false);
    }

    final hit = _random.nextInt(100) < move.accuracy;
    if (!hit) return const AttackResult(hit: false, damage: 0, fainted: false);

    final effectiveness = TypeChart.effectiveness(move.type, defenderTypes);
    if (effectiveness == 0) {
      return AttackResult(hit: true, damage: 0, fainted: false, effectiveness: 0);
    }

    // Simplified damage formula (classic scheme), with type
    // effectiveness applied as a final multiplier.
    final base = (((2 * attackerLevel / 5 + 2) * move.power * attackStat / defenseStat) / 50) + 2;
    final randomFactor = 0.85 + _random.nextDouble() * 0.15;
    final damage = max(1, (base * randomFactor * effectiveness).floor());

    final fainted = damage >= targetCurrentHp;
    return AttackResult(
      hit: true,
      damage: damage,
      fainted: fainted,
      effectiveness: effectiveness,
    );
  }

  /// Capture attempt: the weaker the wild Wildkin is, the higher the
  /// probability. Inspired by the classic formula (catch rate tied
  /// to current/max HP), simplified with a single "base catch rate"
  /// for every Wildkin (0-255 as in the original games; 190 is an
  /// average-easy value).
  ///
  /// Returns a 0.0-1.0 value = probability of success.
  double catchProbability(WildEncounter target, {int baseCatchRate = 190}) {
    final hpFactor = (3 * target.maxHp - 2 * target.currentHp) / (3 * target.maxHp);
    final raw = hpFactor * (baseCatchRate / 255);
    return raw.clamp(0.03, 0.98); // never a guaranteed 0% or 100%, for tension
  }

  bool attemptCatch(WildEncounter target, {int baseCatchRate = 190}) {
    final probability = catchProbability(target, baseCatchRate: baseCatchRate);
    return _random.nextDouble() < probability;
  }

  // "Virtual" stats for a wild Wildkin: same formula as
  // Wildkin.computeStats() but applied to its baseStats.
  int _wildAttack(WildEncounter w) => _statAt(w.baseStats.attack, w.level);
  int _wildDefense(WildEncounter w) => _statAt(w.baseStats.defense, w.level);
  int _wildInsight(WildEncounter w) => _statAt(w.baseStats.elementalAttack, w.level);
  int _wildWard(WildEncounter w) => _statAt(w.baseStats.elementalDefense, w.level);

  int _statAt(int base, int level) => (((2 * base) * level) / 100).floor() + 5;
}
