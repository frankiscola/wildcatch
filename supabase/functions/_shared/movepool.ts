// Port of lib/services/movepool.dart. Same table, same keys
// (name/type/category/power/accuracy/max_pp/tier) expected by
// Move.fromJson on the Flutter side. Restricted to the 11 types
// currently in the game (see type_chart.ts). Only starterMoves() is
// needed here for capture (tier 1); tiers 2/3 stay ready for a
// future evolve-wildkin function.
//
// All move names below are original — not translations of any
// existing game's move names — by design, matching movepool.dart.

export type MoveCategory = "physical" | "special" | "status";

export interface MoveJson {
  name: string;
  type: string;
  category: MoveCategory;
  power: number;
  accuracy: number;
  max_pp: number;
  tier: number;
}

const BY_TYPE: Record<string, MoveJson[]> = {
  fire: [
    { name: "Spark Flame", type: "fire", category: "special", power: 40, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Cinder Bite", type: "fire", category: "physical", power: 45, accuracy: 95, max_pp: 20, tier: 1 },
    { name: "Blaze Jet", type: "fire", category: "special", power: 90, accuracy: 100, max_pp: 15, tier: 2 },
    { name: "Smoldering Curse", type: "fire", category: "status", power: 0, accuracy: 85, max_pp: 15, tier: 2 },
    { name: "Volcanic Burst", type: "fire", category: "special", power: 120, accuracy: 100, max_pp: 5, tier: 3 },
  ],
  water: [
    { name: "Water Jet", type: "water", category: "special", power: 40, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Foam Burst", type: "water", category: "special", power: 40, accuracy: 100, max_pp: 30, tier: 1 },
    { name: "Deluge Blast", type: "water", category: "special", power: 90, accuracy: 90, max_pp: 10, tier: 2 },
    { name: "Tidal Wave", type: "water", category: "special", power: 95, accuracy: 100, max_pp: 15, tier: 2 },
    { name: "Maelstrom", type: "water", category: "special", power: 120, accuracy: 100, max_pp: 5, tier: 3 },
  ],
  grass: [
    { name: "Bramble Snap", type: "grass", category: "physical", power: 45, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Sap Drain", type: "grass", category: "special", power: 20, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Thorned Slash", type: "grass", category: "physical", power: 90, accuracy: 100, max_pp: 15, tier: 2 },
    { name: "Radiant Bloom", type: "grass", category: "special", power: 120, accuracy: 100, max_pp: 10, tier: 3 },
  ],
  electric: [
    { name: "Static Zap", type: "electric", category: "special", power: 40, accuracy: 100, max_pp: 30, tier: 1 },
    { name: "Faint Spark", type: "electric", category: "special", power: 45, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Voltaic Arc", type: "electric", category: "special", power: 90, accuracy: 100, max_pp: 15, tier: 2 },
    { name: "Storm Bolt", type: "electric", category: "special", power: 110, accuracy: 70, max_pp: 10, tier: 3 },
  ],
  ice: [
    { name: "Chill Gust", type: "ice", category: "special", power: 55, accuracy: 95, max_pp: 15, tier: 1 },
    { name: "Frost Orb", type: "ice", category: "special", power: 40, accuracy: 90, max_pp: 25, tier: 1 },
    { name: "Glacial Ray", type: "ice", category: "special", power: 90, accuracy: 100, max_pp: 10, tier: 2 },
    { name: "Frost Squall", type: "ice", category: "special", power: 110, accuracy: 70, max_pp: 5, tier: 3 },
  ],
  poison: [
    { name: "Toxic Soot", type: "poison", category: "special", power: 40, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Venom Prick", type: "poison", category: "physical", power: 15, accuracy: 100, max_pp: 35, tier: 1 },
    { name: "Corrosive Flame", type: "poison", category: "special", power: 90, accuracy: 100, max_pp: 10, tier: 2 },
    { name: "Acid Surge", type: "poison", category: "special", power: 100, accuracy: 90, max_pp: 10, tier: 3 },
  ],
  ground: [
    { name: "Pitfall Strike", type: "ground", category: "physical", power: 45, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Sand Toss", type: "ground", category: "status", power: 0, accuracy: 100, max_pp: 15, tier: 1 },
    { name: "Tremor Quake", type: "ground", category: "physical", power: 100, accuracy: 100, max_pp: 10, tier: 2 },
    { name: "Rising Dust", type: "ground", category: "physical", power: 90, accuracy: 85, max_pp: 10, tier: 3 },
  ],
  flying: [
    { name: "Wing Jab", type: "flying", category: "physical", power: 35, accuracy: 100, max_pp: 35, tier: 1 },
    { name: "Wind Spiral", type: "flying", category: "special", power: 40, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Sky Acrobat", type: "flying", category: "physical", power: 85, accuracy: 100, max_pp: 15, tier: 2 },
    { name: "Cyclone Force", type: "flying", category: "special", power: 110, accuracy: 70, max_pp: 10, tier: 3 },
  ],
  psychic: [
    { name: "Mind Ripple", type: "psychic", category: "special", power: 50, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Keen Insight", type: "psychic", category: "special", power: 40, accuracy: 100, max_pp: 20, tier: 1 },
    { name: "Mental Shockwave", type: "psychic", category: "special", power: 80, accuracy: 100, max_pp: 10, tier: 2 },
    { name: "Telekinetic Wave", type: "psychic", category: "special", power: 90, accuracy: 100, max_pp: 10, tier: 3 },
  ],
  rock: [
    { name: "Boulder Toss", type: "rock", category: "physical", power: 50, accuracy: 90, max_pp: 15, tier: 1 },
    { name: "Riverstone Tackle", type: "rock", category: "physical", power: 45, accuracy: 95, max_pp: 20, tier: 1 },
    { name: "Stone Cleaver", type: "rock", category: "physical", power: 100, accuracy: 80, max_pp: 5, tier: 2 },
    { name: "Landslide", type: "rock", category: "physical", power: 75, accuracy: 90, max_pp: 10, tier: 3 },
  ],
  dark: [
    { name: "Swift Bite", type: "dark", category: "physical", power: 40, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Shadowed Glare", type: "dark", category: "status", power: 0, accuracy: 100, max_pp: 30, tier: 1 },
    { name: "Sneak Strike", type: "dark", category: "physical", power: 40, accuracy: 100, max_pp: 30, tier: 2 },
    { name: "Grim Maw", type: "dark", category: "physical", power: 80, accuracy: 100, max_pp: 15, tier: 3 },
  ],
};

function movesOfTier(type: string, tier: number): MoveJson[] {
  const all = BY_TYPE[type.toLowerCase()] ?? [];
  return all.filter((m) => m.tier === tier);
}

function shuffle<T>(arr: T[]): T[] {
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

/// The 4 starting moves for a freshly captured Wildkin: always from
/// tier 1, matching its type(s), falling back to the first type's
/// tier-1 moves if the pool has fewer than 4.
export function starterMoves(types: string[]): MoveJson[] {
  const pool: MoveJson[] = [];
  for (const type of types) {
    pool.push(...movesOfTier(type, 1));
  }
  if (types.length > 0) pool.push(...movesOfTier(types[0], 1));

  const shuffled = shuffle(pool);
  const unique = new Map<string, MoveJson>();
  for (const move of shuffled) {
    unique.set(move.name, move);
    if (unique.size === 4) break;
  }
  return [...unique.values()];
}
