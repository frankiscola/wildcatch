/// Le sei statistiche di base, generate una volta alla cattura
/// e poi scalate col livello (stesso schema concettuale dei
/// giochi originali: gli "IV" restano fissi per la creatura,
/// il valore effettivo cresce col livello).
class BaseStats {
  final int hp;
  final int attack;
  final int defense;
  final int spAttack;
  final int spDefense;
  final int speed;

  const BaseStats({
    required this.hp,
    required this.attack,
    required this.defense,
    required this.spAttack,
    required this.spDefense,
    required this.speed,
  });

  Map<String, dynamic> toJson() => {
        'hp': hp,
        'attack': attack,
        'defense': defense,
        'sp_attack': spAttack,
        'sp_defense': spDefense,
        'speed': speed,
      };

  factory BaseStats.fromJson(Map<String, dynamic> json) => BaseStats(
        hp: json['hp'] as int,
        attack: json['attack'] as int,
        defense: json['defense'] as int,
        spAttack: json['sp_attack'] as int,
        spDefense: json['sp_defense'] as int,
        speed: json['speed'] as int,
      );
}

/// Statistiche effettive a un dato livello, calcolate da [BaseStats].
class ComputedStats {
  final int maxHp;
  final int attack;
  final int defense;
  final int spAttack;
  final int spDefense;
  final int speed;

  const ComputedStats({
    required this.maxHp,
    required this.attack,
    required this.defense,
    required this.spAttack,
    required this.spDefense,
    required this.speed,
  });
}
