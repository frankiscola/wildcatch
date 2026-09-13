import 'capture_context.dart';
import 'move.dart';
import 'stats.dart';

/// A wild Wildkin just "discovered" by photographing an animal,
/// before the player decides whether to battle it or catch it
/// right away. Unlike [Wildkin] it doesn't have an active evolution
/// plan or a nickname yet — those are only assigned on an actual
/// capture.
class WildEncounter {
  final String photoUrl;
  final List<String> types;
  final int level;
  final BaseStats baseStats;
  final List<Move> moves;
  final CaptureContext context;

  /// Current HP, which drops during a battle before any capture
  /// attempt.
  final int currentHp;
  final int maxHp;

  const WildEncounter({
    required this.photoUrl,
    required this.types,
    required this.level,
    required this.baseStats,
    required this.moves,
    required this.context,
    required this.currentHp,
    required this.maxHp,
  });

  double get hpFraction => maxHp == 0 ? 0 : currentHp / maxHp;

  WildEncounter copyWith({int? currentHp}) => WildEncounter(
        photoUrl: photoUrl,
        types: types,
        level: level,
        baseStats: baseStats,
        moves: moves,
        context: context,
        currentHp: currentHp ?? this.currentHp,
        maxHp: maxHp,
      );
}
