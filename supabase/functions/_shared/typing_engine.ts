// 1:1 port of lib/services/typing_engine.dart.
// Receives the CaptureContext exactly as the Flutter client
// serializes it (CaptureContext.toJson(), snake_case keys), so
// season, is_night_time, and biome arrive already computed — we
// don't recompute them here to avoid duplicating the date/time logic
// in two places.

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
    fire: 3,
    water: 3,
    electric: 3,
    grass: 3,
    ice: 2,
    poison: 2,
    ground: 3,
    flying: 3,
    psychic: 2,
    rock: 3,
    dark: 2,
  };
}

function add(scores: Record<string, number>, type: string, amount: number) {
  scores[type] = (scores[type] ?? 0) + amount;
}

function applyTemperature(scores: Record<string, number>, celsius: number) {
  if (celsius >= 30) {
    add(scores, "fire", 6);
    add(scores, "ground", 3);
  } else if (celsius >= 22) {
    add(scores, "grass", 3);
  } else if (celsius <= 5) {
    add(scores, "ice", 6);
  } else if (celsius <= 12) {
    add(scores, "ice", 2);
  }
}

function applyWeather(scores: Record<string, number>, condition: string) {
  switch (condition) {
    case "rain":
      add(scores, "water", 6);
      break;
    case "storm":
      add(scores, "electric", 7);
      add(scores, "flying", 2);
      break;
    case "snow":
      add(scores, "ice", 7);
      break;
    case "fog":
      add(scores, "psychic", 4);
      add(scores, "poison", 3);
      break;
    case "clear":
      add(scores, "fire", 1);
      add(scores, "flying", 2);
      break;
  }
}

function applySeason(scores: Record<string, number>, season: string) {
  switch (season) {
    case "summer":
      add(scores, "fire", 2);
      add(scores, "ground", 1);
      break;
    case "winter":
      add(scores, "ice", 2);
      break;
    case "spring":
      add(scores, "grass", 3);
      break;
    case "fall":
      add(scores, "ground", 2);
      add(scores, "dark", 1);
      break;
  }
}

function applyBiome(scores: Record<string, number>, biome: string) {
  switch (biome) {
    case "sea":
      add(scores, "water", 8);
      break;
    case "mountain":
      add(scores, "rock", 8);
      add(scores, "ground", 3);
      break;
    case "forest":
      add(scores, "grass", 6);
      break;
    case "urbanCity":
      add(scores, "electric", 5);
      add(scores, "rock", 3);
      break;
    case "plain":
      add(scores, "grass", 4);
      add(scores, "ground", 2);
      break;
    case "desert":
      add(scores, "ground", 7);
      add(scores, "fire", 2);
      break;
    default:
      break; // 'unknown'
  }
}

function applyTimeOfDay(scores: Record<string, number>, isNight: boolean) {
  if (isNight) {
    add(scores, "dark", 6);
    add(scores, "psychic", 4);
  } else {
    add(scores, "flying", 1);
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

/// Assigns 1 or 2 types based on the context, using the same
/// weighted logic as typing_engine.dart (~35% chance of a dual type
/// when this function is used for evolution; generate-wildkin only
/// uses the first element, since at capture the Wildkin always has
/// just one type).
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
