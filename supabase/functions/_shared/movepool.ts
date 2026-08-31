// Porting di lib/services/movepool.dart. Stessa tabella, stesse
// chiavi (name/type/category/power/accuracy/max_pp/tier) attese da
// Move.fromJson lato Flutter. Qui serve solo starterMoves() per la
// cattura (tier 1); tier 2/3 restano pronti per evolve-creature.

export type MoveCategory = "fisica" | "speciale" | "stato";

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
  normale: [
    { name: "Azzannamento", type: "normale", category: "fisica", power: 35, accuracy: 100, max_pp: 35, tier: 1 },
    { name: "Rapidità", type: "normale", category: "fisica", power: 40, accuracy: 100, max_pp: 30, tier: 1 },
    { name: "Colpo Rapido", type: "normale", category: "fisica", power: 60, accuracy: 100, max_pp: 20, tier: 2 },
    { name: "Ipervoce", type: "normale", category: "speciale", power: 90, accuracy: 100, max_pp: 10, tier: 3 },
  ],
  fuoco: [
    { name: "Braciere", type: "fuoco", category: "speciale", power: 40, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Morso Infuocato", type: "fuoco", category: "fisica", power: 45, accuracy: 95, max_pp: 20, tier: 1 },
    { name: "Lanciafiamme", type: "fuoco", category: "speciale", power: 90, accuracy: 100, max_pp: 15, tier: 2 },
    { name: "Fuoco Fatuo", type: "fuoco", category: "stato", power: 0, accuracy: 85, max_pp: 15, tier: 2 },
    { name: "Eruzione", type: "fuoco", category: "speciale", power: 120, accuracy: 100, max_pp: 5, tier: 3 },
  ],
  acqua: [
    { name: "Spruzzo", type: "acqua", category: "speciale", power: 40, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Bolla", type: "acqua", category: "speciale", power: 40, accuracy: 100, max_pp: 30, tier: 1 },
    { name: "Idropompa", type: "acqua", category: "speciale", power: 90, accuracy: 90, max_pp: 10, tier: 2 },
    { name: "Surf", type: "acqua", category: "speciale", power: 95, accuracy: 100, max_pp: 15, tier: 2 },
    { name: "Uragano D'Acqua", type: "acqua", category: "speciale", power: 120, accuracy: 100, max_pp: 5, tier: 3 },
  ],
  erba: [
    { name: "Frustata", type: "erba", category: "fisica", power: 45, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Assorbisai", type: "erba", category: "speciale", power: 20, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Foglielama", type: "erba", category: "fisica", power: 90, accuracy: 100, max_pp: 15, tier: 2 },
    { name: "Solarraggio", type: "erba", category: "speciale", power: 120, accuracy: 100, max_pp: 10, tier: 3 },
  ],
  elettro: [
    { name: "Scarica", type: "elettro", category: "speciale", power: 40, accuracy: 100, max_pp: 30, tier: 1 },
    { name: "Fulmine Debole", type: "elettro", category: "speciale", power: 45, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Fulmine", type: "elettro", category: "speciale", power: 90, accuracy: 100, max_pp: 15, tier: 2 },
    { name: "Tuono", type: "elettro", category: "speciale", power: 110, accuracy: 70, max_pp: 10, tier: 3 },
  ],
  ghiaccio: [
    { name: "Vento Gelido", type: "ghiaccio", category: "speciale", power: 55, accuracy: 95, max_pp: 15, tier: 1 },
    { name: "Palla Gelida", type: "ghiaccio", category: "speciale", power: 40, accuracy: 90, max_pp: 25, tier: 1 },
    { name: "Raggio Gelido", type: "ghiaccio", category: "speciale", power: 90, accuracy: 100, max_pp: 10, tier: 2 },
    { name: "Bufera", type: "ghiaccio", category: "speciale", power: 110, accuracy: 70, max_pp: 5, tier: 3 },
  ],
  lotta: [
    { name: "Braccio Teso", type: "lotta", category: "fisica", power: 40, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Doppio Colpo", type: "lotta", category: "fisica", power: 35, accuracy: 90, max_pp: 30, tier: 1 },
    { name: "Attacco Rissoso", type: "lotta", category: "fisica", power: 85, accuracy: 100, max_pp: 15, tier: 2 },
    { name: "Focus Blast", type: "lotta", category: "speciale", power: 120, accuracy: 70, max_pp: 5, tier: 3 },
  ],
  veleno: [
    { name: "Fuliggine Tossica", type: "veleno", category: "speciale", power: 40, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Puntura Velenosa", type: "veleno", category: "fisica", power: 15, accuracy: 100, max_pp: 35, tier: 1 },
    { name: "Fuoco Tossico", type: "veleno", category: "speciale", power: 90, accuracy: 100, max_pp: 10, tier: 2 },
    { name: "Attacco D'Acido", type: "veleno", category: "speciale", power: 100, accuracy: 90, max_pp: 10, tier: 3 },
  ],
  terra: [
    { name: "Colpo Fossa", type: "terra", category: "fisica", power: 45, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Lancio Sabbia", type: "terra", category: "stato", power: 0, accuracy: 100, max_pp: 15, tier: 1 },
    { name: "Terremoto", type: "terra", category: "fisica", power: 100, accuracy: 100, max_pp: 10, tier: 2 },
    { name: "Terra Aumentata", type: "terra", category: "fisica", power: 90, accuracy: 85, max_pp: 10, tier: 3 },
  ],
  volante: [
    { name: "Beccata", type: "volante", category: "fisica", power: 35, accuracy: 100, max_pp: 35, tier: 1 },
    { name: "Turbine", type: "volante", category: "speciale", power: 40, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Acrobazia", type: "volante", category: "fisica", power: 85, accuracy: 100, max_pp: 15, tier: 2 },
    { name: "Uragano", type: "volante", category: "speciale", power: 110, accuracy: 70, max_pp: 10, tier: 3 },
  ],
  psico: [
    { name: "Confusione", type: "psico", category: "speciale", power: 50, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Extrasenso", type: "psico", category: "speciale", power: 40, accuracy: 100, max_pp: 20, tier: 1 },
    { name: "Psicoshock", type: "psico", category: "speciale", power: 80, accuracy: 100, max_pp: 10, tier: 2 },
    { name: "Psicocinesi", type: "psico", category: "speciale", power: 90, accuracy: 100, max_pp: 10, tier: 3 },
  ],
  coleottero: [
    { name: "Attacco Furia", type: "coleottero", category: "fisica", power: 15, accuracy: 85, max_pp: 20, tier: 1 },
    { name: "Ronzio", type: "coleottero", category: "speciale", power: 40, accuracy: 100, max_pp: 20, tier: 1 },
    { name: "Megatorma", type: "coleottero", category: "fisica", power: 90, accuracy: 100, max_pp: 10, tier: 2 },
    { name: "Attacco Prima Vera", type: "coleottero", category: "fisica", power: 70, accuracy: 100, max_pp: 15, tier: 3 },
  ],
  roccia: [
    { name: "Lancio Massi", type: "roccia", category: "fisica", power: 50, accuracy: 90, max_pp: 15, tier: 1 },
    { name: "Tackle Rio", type: "roccia", category: "fisica", power: 45, accuracy: 95, max_pp: 20, tier: 1 },
    { name: "Pietrataglio", type: "roccia", category: "fisica", power: 100, accuracy: 80, max_pp: 5, tier: 2 },
    { name: "Frana", type: "roccia", category: "fisica", power: 75, accuracy: 90, max_pp: 10, tier: 3 },
  ],
  spettro: [
    { name: "Pugno Ombra", type: "spettro", category: "fisica", power: 40, accuracy: 100, max_pp: 15, tier: 1 },
    { name: "Sguardo Furtivo", type: "spettro", category: "stato", power: 0, accuracy: 100, max_pp: 30, tier: 1 },
    { name: "Palla Ombra", type: "spettro", category: "speciale", power: 80, accuracy: 100, max_pp: 15, tier: 2 },
    { name: "Attacco D'Ombra", type: "spettro", category: "fisica", power: 90, accuracy: 100, max_pp: 10, tier: 3 },
  ],
  drago: [
    { name: "Furia Draconica", type: "drago", category: "speciale", power: 40, accuracy: 100, max_pp: 10, tier: 1 },
    { name: "Morso", type: "drago", category: "fisica", power: 60, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Danza Drago", type: "drago", category: "stato", power: 0, accuracy: 100, max_pp: 20, tier: 2 },
    { name: "Vampata Drago", type: "drago", category: "speciale", power: 100, accuracy: 100, max_pp: 5, tier: 3 },
  ],
  buio: [
    { name: "Morso Rapido", type: "buio", category: "fisica", power: 40, accuracy: 100, max_pp: 25, tier: 1 },
    { name: "Sguardo Buio", type: "buio", category: "stato", power: 0, accuracy: 100, max_pp: 30, tier: 1 },
    { name: "Attacco Furtivo", type: "buio", category: "fisica", power: 40, accuracy: 100, max_pp: 30, tier: 2 },
    { name: "Cricca", type: "buio", category: "fisica", power: 80, accuracy: 100, max_pp: 15, tier: 3 },
  ],
  acciaio: [
    { name: "Colpo D'Acciaio", type: "acciaio", category: "fisica", power: 40, accuracy: 100, max_pp: 35, tier: 1 },
    { name: "Difesa Ferrea", type: "acciaio", category: "stato", power: 0, accuracy: 100, max_pp: 15, tier: 1 },
    { name: "Testata Di Ferro", type: "acciaio", category: "fisica", power: 80, accuracy: 100, max_pp: 15, tier: 2 },
    { name: "Meteorpugno", type: "acciaio", category: "fisica", power: 90, accuracy: 90, max_pp: 10, tier: 3 },
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

/// Le 4 mosse iniziali di una creatura appena catturata: sempre dal
/// tier 1, coerenti col suo tipo, con fallback su 'normale' se il
/// pool del tipo ha meno di 4 mosse.
export function starterMoves(types: string[]): MoveJson[] {
  const pool: MoveJson[] = [];
  for (const type of types) {
    pool.push(...movesOfTier(type, 1));
  }
  pool.push(...movesOfTier("normale", 1));

  const shuffled = shuffle(pool);
  const unique = new Map<string, MoveJson>();
  for (const move of shuffled) {
    unique.set(move.name, move);
    if (unique.size === 4) break;
  }
  return [...unique.values()];
}
