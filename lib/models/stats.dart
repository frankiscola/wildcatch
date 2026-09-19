/// The six base stats, generated once at capture and then scaled
/// with level (same conceptual scheme as classic monster-collecting
/// RPGs: the "Potential Score" stays fixed for the Wildkin, the
/// effective value grows with level).
class BaseStats {
  final int hp;
  final int attack;
  final int defense;
  final int elementalAttack; // special attack
  final int elementalDefense; // special defense
  final int speed;

  const BaseStats({
    required this.hp,
    required this.attack,
    required this.defense,
    required this.elementalAttack,
    required this.elementalDefense,
    required this.speed,
  });

  Map<String, dynamic> toJson() => {
        'hp': hp,
        'attack': attack,
        'defense': defense,
        'elemental_attack': elementalAttack,
        'elemental_defense': elementalDefense,
        'speed': speed,
      };

  factory BaseStats.fromJson(Map<String, dynamic> json) => BaseStats(
        hp: json['hp'] as int,
        attack: json['attack'] as int,
        defense: json['defense'] as int,
        // Fallback to the old 'insight'/'ward' keys for Wildkin captured
        // before the elemental_attack/elemental_defense rename, so
        // already-saved rows keep loading without a DB migration.
        elementalAttack: (json['elemental_attack'] ?? json['insight']) as int,
        elementalDefense: (json['elemental_defense'] ?? json['ward']) as int,
        speed: json['speed'] as int,
      );
}

/// Effective stats at a given level, calculated from [BaseStats].
class ComputedStats {
  final int maxHp;
  final int attack;
  final int defense;
  final int elementalAttack;
  final int elementalDefense;
  final int speed;

  const ComputedStats({
    required this.maxHp,
    required this.attack,
    required this.defense,
    required this.elementalAttack,
    required this.elementalDefense,
    required this.speed,
  });
}
