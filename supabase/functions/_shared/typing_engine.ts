// Porting 1:1 di lib/services/typing_engine.dart.
// Riceve il CaptureContext così come lo serializza il client Flutter
// (CaptureContext.toJson(), chiavi snake_case), quindi season,
// is_night_time e biome arrivano già calcolati — non li ricalcoliamo
// qui per evitare di duplicare la logica di data/ora due volte.

export interface CaptureContextJson {
  captured_at: string;
  latitude: number;
  longitude: number;
  elevation_meters: number | null;
  biome: string;
  weather_condition: string;
  temperature_celsius: number;
  humidity_percent: number;
  wind_speed_kmh: number;
  is_night_time: boolean;
  season: string;
}

function baseScores(): Record<string, number> {
  return {
    normale: 5,
    fuoco: 3,
    acqua: 3,
    elettro: 3,
    erba: 3,
    ghiaccio: 2,
    terra: 3,
    roccia: 3,
    volante: 3,
    spettro: 2,
    buio: 2,
    coleottero: 3,
  };
}

function add(scores: Record<string, number>, type: string, amount: number) {
  scores[type] = (scores[type] ?? 0) + amount;
}

function applyTemperature(scores: Record<string, number>, celsius: number) {
  if (celsius >= 30) {
    add(scores, "fuoco", 6);
    add(scores, "terra", 3);
  } else if (celsius >= 22) {
    add(scores, "erba", 3);
    add(scores, "coleottero", 2);
  } else if (celsius <= 5) {
    add(scores, "ghiaccio", 6);
  } else if (celsius <= 12) {
    add(scores, "ghiaccio", 2);
  }
}

function applyWeather(scores: Record<string, number>, condition: string) {
  switch (condition) {
    case "rain":
      add(scores, "acqua", 6);
      break;
    case "storm":
      add(scores, "elettro", 7);
      add(scores, "volante", 2);
      break;
    case "snow":
      add(scores, "ghiaccio", 7);
      break;
    case "fog":
      add(scores, "spettro", 5);
      add(scores, "veleno", 3);
      break;
    case "clear":
      add(scores, "fuoco", 1);
      add(scores, "volante", 2);
      break;
  }
}

function applySeason(scores: Record<string, number>, season: string) {
  switch (season) {
    case "estate":
      add(scores, "fuoco", 2);
      add(scores, "terra", 1);
      break;
    case "inverno":
      add(scores, "ghiaccio", 2);
      break;
    case "primavera":
      add(scores, "erba", 3);
      add(scores, "coleottero", 2);
      break;
    case "autunno":
      add(scores, "terra", 2);
      add(scores, "buio", 1);
      break;
  }
}

function applyBiome(scores: Record<string, number>, biome: string) {
  switch (biome) {
    case "mare":
      add(scores, "acqua", 8);
      break;
    case "montagna":
      add(scores, "roccia", 8);
      add(scores, "terra", 3);
      break;
    case "foresta":
      add(scores, "erba", 6);
      add(scores, "coleottero", 4);
      break;
    case "cittaUrbana":
      add(scores, "acciaio", 5);
      add(scores, "normale", 3);
      break;
    case "pianura":
      add(scores, "normale", 3);
      add(scores, "erba", 2);
      break;
    case "deserto":
      add(scores, "terra", 7);
      add(scores, "fuoco", 2);
      break;
    default:
      break; // 'sconosciuto'
  }
}

function applyTimeOfDay(scores: Record<string, number>, isNight: boolean) {
  if (isNight) {
    add(scores, "spettro", 4);
    add(scores, "buio", 5);
    add(scores, "psico", 2);
  } else {
    add(scores, "normale", 1);
    add(scores, "volante", 1);
  }
}

function weightedPick(scores: Record<string, number>): string {
  const entries = Object.entries(scores);
  const total = entries.reduce((sum, [, v]) => sum + v, 0);
  let roll = Math.random() * total;
  for (const [type, value] of entries) {
    roll -= value;
    if (roll <= 0) return type;
  }
  return entries[0][0];
}

/// Assegna 1 o 2 tipi in base al contesto, con la stessa logica
/// pesata usata in typing_engine.dart (~35% di probabilità di
/// doppio tipo quando questa funzione viene usata per l'evoluzione;
/// generate-creature usa solo il primo elemento perché alla cattura
/// la creatura ha sempre un tipo solo).
export function assignTypes(context: CaptureContextJson): string[] {
  const scores = baseScores();

  applyTemperature(scores, context.temperature_celsius);
  applyWeather(scores, context.weather_condition);
  applySeason(scores, context.season);
  applyBiome(scores, context.biome);
  applyTimeOfDay(scores, context.is_night_time);

  const primary = weightedPick(scores);
  delete scores[primary];

  const hasSecondType = Math.random() < 0.35;
  const remaining = Object.keys(scores);
  if (!hasSecondType || remaining.length === 0) return [primary];

  const secondary = weightedPick(scores);
  return [primary, secondary];
}
