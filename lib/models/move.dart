/// Categoria di una mossa, come nei giochi originali.
enum MoveCategory { fisica, speciale, stato }

/// Una mossa che una creatura può conoscere. Le statistiche
/// (potenza, precisione, PP) rispecchiano il formato classico.
class Move {
  final String name;
  final String type;
  final MoveCategory category;
  final int power; // 0 per le mosse di stato
  final int accuracy; // 0-100 (alcune mosse "che non falliscono mai" usano 100)
  final int maxPp;
  final int tier; // 1 = mossa base debole, 2/3 = mosse più forti sbloccate a livelli alti

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

/// Una mossa così come la possiede una creatura: riferimento alla
/// mossa base + PP correnti (consumati con l'uso in battaglia).
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
