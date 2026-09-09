// Logica di finalizzazione di una cattura: determina tipo,
// statistiche, mosse iniziali e piano evolutivo, poi salva la riga
// in 'captures'. Estratta da generate-creature/index.ts perché ora
// va richiamata da DUE punti:
//  - generate-creature/index.ts stesso (percorso diretto, tenuto per
//    test manuali da terminale, NON più usato dalla UI normale)
//  - resolve-sighting/index.ts, che la chiama solo dopo aver
//    verificato il doppio avvistamento (meccanismo 5)
//
// NOTA sulle sprite: front_sprite_url e back_sprite_url restano
// ancora placeholder (= la foto originale). Vedi README per lo stato
// della pipeline di generazione immagini.

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { assignTypes, type CaptureContextJson } from "./typing_engine.ts";
import { generateBaseStats } from "./stats_engine.ts";
import { starterMoves } from "./movepool.ts";
import { createInitialEvolutionPlan } from "./evolution.ts";

export interface FinalizeCaptureInput {
  userId: string;
  originalPhotoUrl: string;
  speciesHint: string;
  context: CaptureContextJson;
}

export async function finalizeCapture(
  supabase: SupabaseClient,
  input: FinalizeCaptureInput,
) {
  const { userId, originalPhotoUrl, speciesHint, context } = input;

  // 1. Tipo: alla cattura la creatura ha SEMPRE un solo tipo, anche
  //    se assignTypes può restituirne 2 (quel caso è per l'evoluzione).
  const types = [assignTypes(context)[0]];

  // 2. Statistiche base.
  const baseStats = generateBaseStats(types);

  // 3. Le 4 mosse iniziali, coerenti col tipo.
  const moves = starterMoves(types).map((move) => ({
    move,
    current_pp: move.max_pp,
  }));

  // 4. Piano evolutivo (stadi + soglie nascoste).
  const evolutionPlan = createInitialEvolutionPlan();

  // 5. Statistiche effettive a livello 5.
  const level = 5;
  const maxHp = Math.floor((2 * baseStats.hp * level) / 100) + level + 10;

  // 6. Sprite — PLACEHOLDER, vedi nota in cima al file.
  const frontSpriteUrl = originalPhotoUrl;
  const backSpriteUrl = originalPhotoUrl;

  const row = {
    user_id: userId,
    nickname: speciesHint,
    original_photo_url: originalPhotoUrl,
    front_sprite_url: frontSpriteUrl,
    back_sprite_url: backSpriteUrl,
    assigned_type: types,
    species_hint: speciesHint,
    level,
    current_exp: 0,
    current_hp: maxHp,
    base_stats: baseStats,
    moves,
    evolution_plan: evolutionPlan,
    captured_at: context.captured_at,
    latitude: context.latitude,
    longitude: context.longitude,
    elevation_m: context.elevation_meters ?? null,
    weather_condition: context.weather_condition,
    temperature_c: context.temperature_celsius,
    humidity_percent: context.humidity_percent ?? null,
    wind_speed_kmh: context.wind_speed_kmh ?? null,
  };

  const { data: inserted, error: insertError } = await supabase
    .from("captures")
    .insert(row)
    .select()
    .single();

  if (insertError) {
    throw new Error(`Impossibile salvare la creatura: ${insertError.message}`);
  }

  return inserted;
}
