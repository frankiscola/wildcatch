// 1:1 port of lib/models/type_chart.dart. Not used by any edge
// function yet (battle-turn hasn't been written, see README, "What's
// still missing"): ready for when it is.

interface TypeMatchups {
  weakTo?: string[];
  resists?: string[];
  immuneTo?: string[];
}

const CHART: Record<string, TypeMatchups> = {
  fuoco: { weakTo: ["acqua", "terra", "roccia"], resists: ["fuoco", "erba", "ghiaccio"] },
  acqua: { weakTo: ["elettro", "erba", "ghiaccio"], resists: ["fuoco", "acqua"] },
  elettro: { weakTo: ["terra"], resists: ["elettro", "volante"] },
  erba: { weakTo: ["fuoco", "veleno", "volante"], resists: ["acqua", "elettro", "erba", "terra"] },
  ghiaccio: { weakTo: ["fuoco", "volante"], resists: ["ghiaccio"] },
  veleno: { weakTo: ["terra", "psico"], resists: ["erba", "veleno", "roccia"] },
  terra: { weakTo: ["acqua", "erba", "ghiaccio"], resists: ["veleno", "roccia"], immuneTo: ["elettro"] },
  volante: { weakTo: ["elettro", "ghiaccio"], immuneTo: ["terra"] },
  psico: { weakTo: ["buio", "fuoco"], resists: ["psico", "terra"] },
  roccia: { weakTo: ["acqua", "erba"], resists: ["fuoco", "volante"] },
  buio: { weakTo: ["psico"], resists: ["buio"] },
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
