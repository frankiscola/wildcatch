/// A move's category, as in the original games.
enum MoveCategory { physical, special, status }

/// A move a Wildkin can know. The stats (power, accuracy, PP)
/// mirror the classic format.
class Move {
  final String name;
  final String type;
  final MoveCategory category;
  final int power; // 0 for status moves
  final int accuracy; // 0-100 (some "never miss" moves use 100)
  final int maxPp;
  final int tier; // 1 = weak starting move, 2/3 = stronger moves unlocked at higher levels

  const Move({
    required this.name,
    required this.type,
    required this.category,
    required this.power,
    required this.accuracy,
    required this.maxPp,
    required this.tier,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'category': category.name,
        'power': power,
        'accuracy': accuracy,
        'max_pp': maxPp,
        'tier': tier,
      };

  factory Move.fromJson(Map<String, dynamic> json) => Move(
        name: json['name'] as String,
        type: json['type'] as String,
        category: MoveCategory.values.byName(json['category'] as String),
        power: json['power'] as int,
        accuracy: json['accuracy'] as int,
        maxPp: json['max_pp'] as int,
        tier: json['tier'] as int,
      );
}

/// A move as owned by a Wildkin: a reference to the base move +
/// current PP (consumed by use in battle).
class LearnedMove {
  final Move move;
  final int currentPp;

  const LearnedMove({required this.move, required this.currentPp});

  LearnedMove copyWith({int? currentPp}) =>
      LearnedMove(move: move, currentPp: currentPp ?? this.currentPp);

  Map<String, dynamic> toJson() => {
        'move': move.toJson(),
        'current_pp': currentPp,
      };

  factory LearnedMove.fromJson(Map<String, dynamic> json) => LearnedMove(
        move: Move.fromJson(json['move'] as Map<String, dynamic>),
        currentPp: json['current_pp'] as int,
      );
}
