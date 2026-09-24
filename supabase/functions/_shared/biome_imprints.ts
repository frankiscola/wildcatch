// 1:1 port of lib/models/biome_imprints.dart. Used by
// finalize_capture.ts to roll a Wildkin's permanent imprint once, at
// capture time — this is the source of truth, same as type assignment.

export interface BiomeImprint {
  name: string;
  description: string;
  effect: string;
  bonus_pct: number;
}

const BY_BIOME: Record<string, BiomeImprint[]> = {
  sea: [
    { name: "Tide-Born", description: "Grew up reading the tides.", effect: "accuracy", bonus_pct: 8 },
    { name: "Brine-Hardened", description: "Salt water toughened it against energy-based hits.", effect: "ward", bonus_pct: 8 },
  ],
  mountain: [
    { name: "Summit-Forged", description: "Learned to strike hard at high altitude.", effect: "criticalChance", bonus_pct: 8 },
    { name: "Stone-Rooted", description: "Built a sturdy frame climbing rocky terrain.", effect: "defense", bonus_pct: 8 },
  ],
  forest: [
    { name: "Bramble-Touched", description: "Picked up a knack for nasty thorns and stings.", effect: "statusInflictChance", bonus_pct: 8 },
    { name: "Canopy-Shrouded", description: "Learned to vanish into dappled leaf-shadow.", effect: "evasion", bonus_pct: 8 },
  ],
  urbanCity: [
    { name: "Neon-Charged", description: "Soaked up restless city energy.", effect: "universalMoveDamage", bonus_pct: 5 },
    { name: "Street-Smart", description: "Learned to react fast, dodging traffic and crowds.", effect: "firstTurnSpeed", bonus_pct: 8 },
  ],
  plain: [
    { name: "Windswept", description: "Raced the open wind across flat country.", effect: "firstTurnSpeed", bonus_pct: 8 },
    { name: "Open-Sky Bold", description: "Nowhere to hide out here, so it stopped trying.", effect: "criticalChance", bonus_pct: 8 },
  ],
  desert: [
    { name: "Sun-Baked", description: "Hardened by relentless heat and dry air.", effect: "statusResistance", bonus_pct: 8 },
    { name: "Mirage-Veiled", description: "Heat shimmer makes it hard to pin down.", effect: "evasion", bonus_pct: 8 },
  ],
};

/// Rolls one of the biome's two imprints. Null for "unknown" or any
/// biome not in the table.
export function pickBiomeImprint(biome: string): BiomeImprint | null {
  const options = BY_BIOME[biome];
  if (!options || options.length === 0) return null;
  return options[Math.floor(Math.random() * options.length)];
}
