import '../models/capture_context.dart';
import '../models/wild_encounter.dart';
import 'typing_engine.dart';
import 'stats_engine.dart';
import 'movepool.dart';

/// Generates a [WildEncounter] from a context, with the exact same
/// logic as finalize_capture.ts server-side (a single type, base
/// stats, 4 starter moves, always level 5). Runs entirely client-side
/// to show who the player is about to fight without waiting on the
/// server.
///
/// If the encounter ends in a successful capture, persistence still
/// goes through the existing double-sighting mechanism — this
/// generator is only for the battle PREVIEW, it never bypasses the
/// server-side anti-spoofing check.
class WildEncounterGenerator {
  final TypingEngine _typingEngine;
  final StatsEngine _statsEngine;
  final MovePool _movePool;

  WildEncounterGenerator({
    TypingEngine? typingEngine,
    StatsEngine? statsEngine,
    MovePool? movePool,
  })  : _typingEngine = typingEngine ?? TypingEngine(),
        _statsEngine = statsEngine ?? StatsEngine(),
        _movePool = movePool ?? MovePool();

  WildEncounter generate(CaptureContext context) {
    final types = [_typingEngine.assignTypes(context).first];
    final baseStats = _statsEngine.generate(types);
    final moves = _movePool.starterMoves(types);

    const level = 5;
    final maxHp = (((2 * baseStats.hp) * level) / 100).floor() + level + 10;

    return WildEncounter(
      photoUrl: '',
      types: types,
      level: level,
      baseStats: baseStats,
      moves: moves,
      context: context,
      currentHp: maxHp,
      maxHp: maxHp,
    );
  }
}
