import '../models/capture_context.dart';
import '../models/wildkin.dart';
import '../models/level_up_summary.dart';
import '../models/move.dart';
import 'evolution_engine.dart';
import 'movepool.dart';
import 'stats_engine.dart';

/// Grants experience to a Wildkin after a won battle, and handles
/// everything that can trigger on level-up: checking whether it's
/// time to evolve (using [EvolutionEngine] with the CURRENT context,
/// not the capture one), updating base stats on evolution, and
/// proposing a stronger move to learn once one unlocks.
class LevelingService {
  final EvolutionEngine _evolutionEngine;
  final MovePool _movePool;
  final StatsEngine _statsEngine;

  LevelingService({
    EvolutionEngine? evolutionEngine,
    MovePool? movePool,
    StatsEngine? statsEngine,
  })  : _evolutionEngine = evolutionEngine ?? EvolutionEngine(),
        _movePool = movePool ?? MovePool(),
        _statsEngine = statsEngine ?? StatsEngine();

  /// Experience threshold to go from [level] to the next one. Cubic
  /// growth (the classic games' "medium fast" curve).
  int expThreshold(int level) => level * level * level;

  /// Experience earned for knocking out a wild Wildkin of a given level.
  int expFromVictory(int wildLevel) => 20 + wildLevel * 5;

  /// Applies the earned experience, leveling up (possibly more than
  /// once in a single call), and handling evolution and new moves
  /// along the way.
  ///
  /// [fetchCurrentContext] is only called if an evolution actually
  /// triggers — no unnecessary GPS/weather calls otherwise.
  Future<(Wildkin, LevelUpSummary)> grantExperience({
    required Wildkin wildkin,
    required int gainedExp,
    required Future<CaptureContext> Function() fetchCurrentContext,
  }) async {
    var level = wildkin.level;
    var exp = wildkin.currentExp + gainedExp;
    var types = wildkin.types;
    var baseStats = wildkin.baseStats;
    var plan = wildkin.evolutionPlan;
    var evolutionContext = wildkin.evolutionContext;
    final moves = List<LearnedMove>.from(wildkin.moves);

    final levelsGained = <int>[];
    var evolved = false;
    Move? learnedMove;

    while (level < 100 && exp >= expThreshold(level)) {
      exp -= expThreshold(level);
      level += 1;
      levelsGained.add(level);

      if (_evolutionEngine.shouldEvolveNow(plan, level)) {
        final freshContext = await fetchCurrentContext();
        final secondType = _evolutionEngine.determineSecondType(
          existingTypes: types,
          captureContext: wildkin.captureContext,
          evolutionContext: freshContext,
        );
        types = [...types, secondType];
        baseStats = _statsEngine.boostForEvolution(baseStats);
        plan = _evolutionEngine.advance(plan);
        evolutionContext = freshContext;
        evolved = true;
      }

      final candidate = _movePool.nextMoveToLearn(
        types: types,
        level: level,
        alreadyKnownNames: moves.map((m) => m.move.name).toList(),
      );
      if (candidate != null) {
        if (moves.length >= 4) {
          // MVP: replaces the weakest-power move. A future version
          // should let the player choose explicitly.
          moves.sort((a, b) => a.move.power.compareTo(b.move.power));
          moves[0] = LearnedMove(move: candidate, currentPp: candidate.maxPp);
        } else {
          moves.add(LearnedMove(move: candidate, currentPp: candidate.maxPp));
        }
        learnedMove = candidate;
      }
    }

    final newMaxHp = (((2 * baseStats.hp) * level) / 100).floor() + level + 10;

    final updated = wildkin.copyWith(
      level: level,
      currentExp: exp,
      types: types,
      baseStats: baseStats,
      moves: moves,
      evolutionPlan: plan,
      evolutionContext: evolutionContext,
      currentHp: newMaxHp, // full heal on level-up
    );

    final summary = LevelUpSummary(
      levelsGained: levelsGained,
      evolved: evolved,
      learnedMove: learnedMove,
    );

    return (updated, summary);
  }
}
