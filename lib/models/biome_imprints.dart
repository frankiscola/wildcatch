import 'dart:math';
import 'capture_context.dart';

/// A permanent trait a Wildkin gets at the moment of capture, based
/// on which of its biome's two possible imprints it randomly rolls.
/// Unlike type (which can update at evolution), this never changes:
/// it represents where the Wildkin is FROM, not a snapshot in time.
class BiomeImprint {
  final String name;
  final String description;
  final ImprintEffect effect;
  final int bonusPct;

  const BiomeImprint({
    required this.name,
    required this.description,
    required this.effect,
    required this.bonusPct,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'effect': effect.name,
        'bonus_pct': bonusPct,
      };

  factory BiomeImprint.fromJson(Map<String, dynamic> json) => BiomeImprint(
        name: json['name'] as String,
        description: json['description'] as String,
        effect: ImprintEffect.values.byName(json['effect'] as String),
        bonusPct: json['bonus_pct'] as int,
      );
}

enum ImprintEffect {
  accuracy,
  criticalChance,
  evasion,
  statusInflictChance,
  statusResistance,
  firstTurnSpeed,
  universalMoveDamage,
  ward,
  defense,
}

extension ImprintEffectLabel on ImprintEffect {
  String get label => switch (this) {
        ImprintEffect.accuracy => 'Accuracy',
        ImprintEffect.criticalChance => 'Critical hit chance',
        ImprintEffect.evasion => 'Evasion',
        ImprintEffect.statusInflictChance => 'Chance to inflict status',
        ImprintEffect.statusResistance => 'Status resistance',
        ImprintEffect.firstTurnSpeed => 'Speed on the first turn',
        ImprintEffect.universalMoveDamage => 'Damage with universal moves',
        ImprintEffect.ward => 'Sp. Def',
        ImprintEffect.defense => 'Defense',
      };
}

class BiomeImprints {
  BiomeImprints._();

  static const Map<Biome, List<BiomeImprint>> byBiome = {
    Biome.sea: [
      BiomeImprint(name: 'Tide-Born', description: 'Grew up reading the tides.', effect: ImprintEffect.accuracy, bonusPct: 8),
      BiomeImprint(name: 'Brine-Hardened', description: 'Salt water toughened it against energy-based hits.', effect: ImprintEffect.ward, bonusPct: 8),
    ],
    Biome.mountain: [
      BiomeImprint(name: 'Summit-Forged', description: 'Learned to strike hard at high altitude.', effect: ImprintEffect.criticalChance, bonusPct: 8),
      BiomeImprint(name: 'Stone-Rooted', description: 'Built a sturdy frame climbing rocky terrain.', effect: ImprintEffect.defense, bonusPct: 8),
    ],
    Biome.forest: [
      BiomeImprint(name: 'Bramble-Touched', description: 'Picked up a knack for nasty thorns and stings.', effect: ImprintEffect.statusInflictChance, bonusPct: 8),
      BiomeImprint(name: 'Canopy-Shrouded', description: 'Learned to vanish into dappled leaf-shadow.', effect: ImprintEffect.evasion, bonusPct: 8),
    ],
    Biome.urbanCity: [
      BiomeImprint(name: 'Neon-Charged', description: 'Soaked up restless city energy.', effect: ImprintEffect.universalMoveDamage, bonusPct: 5),
      BiomeImprint(name: 'Street-Smart', description: 'Learned to react fast, dodging traffic and crowds.', effect: ImprintEffect.firstTurnSpeed, bonusPct: 8),
    ],
    Biome.plain: [
      BiomeImprint(name: 'Windswept', description: 'Raced the open wind across flat country.', effect: ImprintEffect.firstTurnSpeed, bonusPct: 8),
      BiomeImprint(name: 'Open-Sky Bold', description: 'Nowhere to hide out here, so it stopped trying.', effect: ImprintEffect.criticalChance, bonusPct: 8),
    ],
    Biome.desert: [
      BiomeImprint(name: 'Sun-Baked', description: 'Hardened by relentless heat and dry air.', effect: ImprintEffect.statusResistance, bonusPct: 8),
      BiomeImprint(name: 'Mirage-Veiled', description: 'Heat shimmer makes it hard to pin down.', effect: ImprintEffect.evasion, bonusPct: 8),
    ],
  };

  /// Rolls one of the two imprints for [biome] at capture time.
  /// Returns null for Biome.unknown (no location signal).
  static BiomeImprint? pick(Biome biome, {Random? random}) {
    final options = byBiome[biome];
    if (options == null || options.isEmpty) return null;
    final rng = random ?? Random();
    return options[rng.nextInt(options.length)];
  }
}
