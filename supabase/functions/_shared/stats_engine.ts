// Porting 1:1 di lib/services/stats_engine.dart.

export interface BaseStats {
  hp: number;
  attack: number;
  defense: number;
  sp_attack: number;
  sp_defense: number;
  speed: number;
}

const TYPE_BIAS: Record<string, Partial<Record<keyof BaseStats, number>>> = {
  fuoco: { attack: 6, sp_attack: 6, speed: 3 },
  acqua: { defense: 4, sp_defense: 5, hp: 3 },
  erba: { sp_attack: 4, sp_defense: 4, hp: 3 },
  elettro: { speed: 8, sp_attack: 4 },
  ghiaccio: { sp_defense: 5, defense: 3 },
  lotta: { attack: 8, hp: 4 },
  veleno: { sp_attack: 3, speed: 2 },
  terra: { attack: 5, defense: 5 },
  volante: { speed: 7, sp_attack: 3 },
  psico: { sp_attack: 8, sp_defense: 3 },
  coleottero: { attack: 3, speed: 4 },
  roccia: { defense: 9, hp: 3 },
  spettro: { sp_attack: 5, sp_defense: 5 },
  drago: { attack: 6, sp_attack: 6, hp: 3 },
  buio: { attack: 5, speed: 5 },
  acciaio: { defense: 9, sp_defense: 4 },
  normale: { hp: 5 },
};

function randInt(maxExclusive: number): number {
  return Math.floor(Math.random() * maxExclusive);
}

export function generateBaseStats(types: string[]): BaseStats {
  const values: BaseStats = {
    hp: 20 + randInt(15),
    attack: 15 + randInt(15),
    defense: 15 + randInt(15),
    sp_attack: 15 + randInt(15),
    sp_defense: 15 + randInt(15),
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
