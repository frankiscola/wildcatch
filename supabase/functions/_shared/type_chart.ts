// 1:1 port of lib/models/type_chart.dart. Not used by any edge
// function yet (battle-turn hasn't been written, see README, "What's
// still missing"): ready for when it is.

interface TypeMatchups {
  weakTo?: string[];
  resists?: string[];
  immuneTo?: string[];
}

const CHART: Record<string, TypeMatchups> = {
  fire: { weakTo: ["water", "ground", "rock"], resists: ["fire", "grass", "ice"] },
  water: { weakTo: ["electric", "grass", "ice"], resists: ["fire", "water"] },
  electric: { weakTo: ["ground"], resists: ["electric", "flying"] },
  grass: { weakTo: ["fire", "poison", "flying"], resists: ["water", "electric", "grass", "ground"] },
  ice: { weakTo: ["fire", "flying"], resists: ["ice"] },
  poison: { weakTo: ["ground", "psychic"], resists: ["grass", "poison", "rock"] },
  ground: { weakTo: ["water", "grass", "ice"], resists: ["poison", "rock"], immuneTo: ["electric"] },
  flying: { weakTo: ["electric", "ice"], immuneTo: ["ground"] },
  psychic: { weakTo: ["dark", "fire"], resists: ["psychic", "ground"] },
  rock: { weakTo: ["water", "grass"], resists: ["fire", "flying"] },
  dark: { weakTo: ["psychic"], resists: ["dark"] },
};

/// Damage multiplier for a move of type `attackType` against a target
/// with types `defenderTypes` (1 or 2 types). See the Dart
/// counterpart for the full semantics.
export function typeEffectiveness(attackType: string, defenderTypes: string[]): number {
  let multiplier = 1;
  const attack = attackType.toLowerCase();

  for (const defenderType of defenderTypes) {
    const matchups = CHART[defenderType.toLowerCase()];
    if (!matchups) continue;

    if (matchups.immuneTo?.includes(attack)) {
      multiplier *= 0;
    } else if (matchups.weakTo?.includes(attack)) {
      multiplier *= 2;
    } else if (matchups.resists?.includes(attack)) {
      multiplier *= 0.5;
    }
  }

  return multiplier;
}
