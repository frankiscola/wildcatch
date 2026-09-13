// Capture-finalization logic: determines type, stats, starting
// moves, and evolution plan, then saves the row into 'captures'.
// Extracted out of generate-wildkin/index.ts because it now needs to
// be called from TWO places:
//  - generate-wildkin/index.ts itself (the direct path, kept for
//    manual testing from the terminal, NO LONGER used by the normal
//    UI)
//  - resolve-sighting/index.ts, which calls it only after verifying
//    the double sighting (mechanism 5)
//
// NOTE on sprites: front_sprite_url and back_sprite_url are still
// placeholders (= the original photo). See the README for the
// status of the image-generation pipeline.

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

  // 1. Type: at capture the Wildkin ALWAYS has a single type, even
  //    though assignTypes can return 2 (that case is for evolution).
  const types = [assignTypes(context)[0]];

  // 2. Base stats.
  const baseStats = generateBaseStats(types);

  // 3. The 4 starting moves, matching the type.
  const moves = starterMoves(types).map((move) => ({
    move,
    current_pp: move.max_pp,
  }));

  // 4. Evolution plan (stages + hidden thresholds).
  const evolutionPlan = createInitialEvolutionPlan();

  // 5. Effective stats at level 5.
  const level = 5;
  const maxHp = Math.floor((2 * baseStats.hp * level) / 100) + level + 10;

  // 6. Sprites — PLACEHOLDER, see the note at the top of the file.
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
    throw new Error(`Could not save the Wildkin: ${insertError.message}`);
  }

  return inserted;
}
