/// The six base stats, generated once at capture and then scaled
/// with level (same conceptual scheme as classic monster-collecting
/// RPGs: the "Potential Score" stays fixed for the Wildkin, the
/// effective value grows with level).
class BaseStats {
  final int hp;
  final int attack;
  final int defense;
  final int insight; // special attack
  final int ward; // special defense
  final int speed;

  const BaseStats({
    required this.hp,
    required this.attack,
    required this.defense,
    required this.insight,
    required this.ward,
    required this.speed,
  });

  Map<String, dynamic> toJson() => {
        'hp': hp,
        'attack': attack,
        'defense': defense,
        'insight': insight,
        'ward': ward,
        'speed': speed,
      };

  factory BaseStats.fromJson(Map<String, dynamic> json) => BaseStats(
        hp: json['hp'] as int,
        attack: json['attack'] as int,
        defense: json['defense'] as int,
        insight: json['insight'] as int,
        ward: json['ward'] as int,
        speed: json['speed'] as int,
      );
}

/// Effective stats at a given level, calculated from [BaseStats].
class ComputedStats {
  final int maxHp;
  final int attack;
  final int defense;
  final int insight;
  final int ward;
  final int speed;

  const ComputedStats({
    required this.maxHp,
    required this.attack,
    required this.defense,
    required this.insight,
    required this.ward,
    required this.speed,
  });
}
