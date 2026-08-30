import 'capture_context.dart';
import 'move.dart';
import 'stats.dart';

/// Una creatura selvatica appena "scoperta" fotografando un animale,
/// prima che il giocatore decida se combatterla o catturarla subito.
/// A differenza di [Creature] non ha ancora un piano evolutivo attivo
/// né un nickname: quelli si assegnano solo alla cattura effettiva.
class WildEncounter {
  final String photoUrl;
  final List<String> types;
  final int level;
  final BaseStats baseStats;
  final List<Move> moves;
  final CaptureContext context;

  /// HP correnti, che scendono durante una battaglia prima
  /// dell'eventuale tentativo di cattura.
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
