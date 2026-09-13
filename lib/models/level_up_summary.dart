import 'move.dart';

/// What happened after granting experience to a Wildkin: how many
/// levels it gained, whether it evolved, whether it learned a new
/// move. Used by the UI to narrate the battle outcome instead of
/// silently updating numbers.
class LevelUpSummary {
  final List<int> levelsGained;
  final bool evolved;
  final Move? learnedMove;

  const LevelUpSummary({
    this.levelsGained = const [],
    this.evolved = false,
    this.learnedMove,
  });

  bool get leveledUp => levelsGained.isNotEmpty;
}
