// Porting 1:1 di lib/models/type_chart.dart. Non ancora usato da
// nessuna edge function (battle-turn non è ancora stata scritta, vedi
// README, sezione "Cosa manca ancora"): pronto per quando lo sarà.

interface TypeMatchups {
  weakTo?: string[];
  resists?: string[];
  immuneTo?: string[];
}

const CHART: Record<string, TypeMatchups> = {
  fuoco: { weakTo: ["acqua", "terra", "roccia"], resists: ["fuoco", "erba", "ghiaccio", "coleottero"] },
  acqua: { weakTo: ["elettro", "erba", "ghiaccio"], resists: ["fuoco", "acqua"] },
  elettro: { weakTo: ["terra"], resists: ["elettro", "volante"] },
  erba: { weakTo: ["fuoco", "coleottero", "veleno"], resists: ["acqua", "elettro", "erba", "terra"] },
  ghiaccio: { weakTo: ["fuoco"], resists: ["ghiaccio"] },
  veleno: { weakTo: ["terra", "psico"], resists: ["erba", "veleno", "coleottero", "roccia"] },
  terra: { weakTo: ["acqua", "erba", "ghiaccio"], resists: ["veleno", "roccia"], immuneTo: ["elettro"] },
  volante: { weakTo: ["elettro", "ghiaccio"], immuneTo: ["terra"] },
  psico: { weakTo: ["buio", "coleottero"], resists: ["psico"] },
  coleottero: { weakTo: ["fuoco", "volante", "roccia"], resists: ["erba", "terra"] },
  roccia: { weakTo: ["acqua", "erba"], resists: ["fuoco", "veleno", "volante"] },
  buio: { weakTo: ["psico"], resists: ["buio"] },
};

/// Moltiplicatore di danno di una mossa di tipo `attackType` contro un
/// bersaglio con i tipi `defenderTypes` (1 o 2 tipi). Vedi la
/// controparte Dart per la spiegazione completa della semantica.
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
