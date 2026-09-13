// 1:1 port of lib/services/stats_engine.dart.

export interface BaseStats {
  hp: number;
  attack: number;
  defense: number;
  insight: number;
  ward: number;
  speed: number;
}

const TYPE_BIAS: Record<string, Partial<Record<keyof BaseStats, number>>> = {
  fire: { attack: 6, insight: 6, speed: 3 },
  water: { defense: 4, ward: 5, hp: 3 },
  grass: { insight: 4, ward: 4, hp: 3 },
  electric: { speed: 8, insight: 4 },
  ice: { ward: 5, defense: 3 },
  poison: { insight: 3, speed: 2 },
  ground: { attack: 5, defense: 5 },
  flying: { speed: 7, insight: 3 },
  psychic: { insight: 8, ward: 3 },
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
    insight: 15 + randInt(15),
    ward: 15 + randInt(15),
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
