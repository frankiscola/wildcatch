// 1:1 port of lib/services/stats_engine.dart.

export interface BaseStats {
  hp: number;
  attack: number;
  defense: number;
  elementalAttack: number;
  elementalDefense: number;
  speed: number;
}

const TYPE_BIAS: Record<string, Partial<Record<keyof BaseStats, number>>> = {
  fire: { attack: 6, elementalAttack: 6, speed: 3 },
  water: { defense: 4, elementalDefense: 5, hp: 3 },
  grass: { elementalAttack: 4, elementalDefense: 4, hp: 3 },
  electric: { speed: 8, elementalAttack: 4 },
  ice: { elementalDefense: 5, defense: 3 },
  poison: { elementalAttack: 3, speed: 2 },
  ground: { attack: 5, defense: 5 },
  flying: { speed: 7, elementalAttack: 3 },
  psychic: { elementalAttack: 8, elementalDefense: 3 },
  rock: { defense: 9, hp: 3 },
  dark: { attack: 5, speed: 5 },
};

function randInt(maxExclusive: number): number {
  return Math.floor(Math.random() * maxExclusive);
}

export function generateBaseStats(types: string[]): BaseStats {
  const values: BaseStats = {
    hp: 20 + randInt(15),
    attack: 15 + randInt(15),
    defense: 15 + randInt(15),
    elementalAttack: 15 + randInt(15),
    elementalDefense: 15 + randInt(15),
    speed: 15 + randInt(15),
  };

  for (const type of types) {
    const bias = TYPE_BIAS[type.toLowerCase()];
    if (!bias) continue;
    for (const [stat, bonus] of Object.entries(bias)) {
      values[stat as keyof BaseStats] += bonus as number;
    }
  }

  return values;
}

/// Converts to the snake_case keys used by BaseStats.fromJson on the
/// Dart side (and stored as-is in the base_stats jsonb column):
/// TS/JS naturally reads better with camelCase properties, but the
/// two sides of the app need to agree on the exact JSON shape.
export function serializeBaseStats(stats: BaseStats) {
  return {
    hp: stats.hp,
    attack: stats.attack,
    defense: stats.defense,
    elemental_attack: stats.elementalAttack,
    elemental_defense: stats.elementalDefense,
    speed: stats.speed,
  };
}
