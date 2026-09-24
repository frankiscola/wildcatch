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
// NOTE on sprites: generated via Gemini (see image_generation_client.ts
// and sprite_pipeline.ts). If generation fails for any reason, we fall
// back to the original photo rather than failing the whole capture —
// an image-gen hiccup should never cost the player their catch.

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { assignTypes, type CaptureContextJson } from "./typing_engine.ts";
import { generateBaseStats, serializeBaseStats } from "./stats_engine.ts";
import { starterMoves } from "./movepool.ts";
import { createInitialEvolutionPlan } from "./evolution.ts";
import { generateSprites } from "./sprite_pipeline.ts";
import { pickBiomeImprint } from "./biome_imprints.ts";

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

  // 6. Sprites: real generation, with a safe fallback to the
  //    original photo if anything goes wrong (network, quota,
  //    malformed response...). Never let this step fail the capture.
  let frontSpriteUrl = originalPhotoUrl;
  let backSpriteUrl = originalPhotoUrl;

  try {
    const photoBytes = await fetchAsBytes(originalPhotoUrl);
    const sprites = await generateSprites(
      { bytes: photoBytes, mimeType: guessMimeType(originalPhotoUrl) },
      speciesHint,
    );

    const spriteId = crypto.randomUUID();
    const frontPath = `${userId}/sprites/${spriteId}_front.png`;
    const backPath = `${userId}/sprites/${spriteId}_back.png`;

    await uploadOrThrow(supabase, frontPath, sprites.front);
    await uploadOrThrow(supabase, backPath, sprites.back);

    frontSpriteUrl = supabase.storage.from("captures").getPublicUrl(frontPath).data.publicUrl;
    backSpriteUrl = supabase.storage.from("captures").getPublicUrl(backPath).data.publicUrl;
  } catch (e) {
    console.error("Sprite generation failed, falling back to the original photo:", e);
  }

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
    base_stats: serializeBaseStats(baseStats),
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
    // Rolled once, here, server-side — same trust model as type
    // assignment. Null for Biome "unknown" (no strong location signal).
    biome_imprint: pickBiomeImprint(context.biome),
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

async function fetchAsBytes(url: string): Promise<Uint8Array> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Could not download the original photo (status ${response.status}).`);
  }
  return new Uint8Array(await response.arrayBuffer());
}

function guessMimeType(url: string): string {
  const lower = url.toLowerCase();
  if (lower.endsWith(".png")) return "image/png";
  if (lower.endsWith(".webp")) return "image/webp";
  return "image/jpeg"; // the client's camera always shoots JPEG, see camera_capture_service.dart
}

async function uploadOrThrow(
  supabase: SupabaseClient,
  path: string,
  image: { bytes: Uint8Array; mimeType: string },
): Promise<void> {
  const { error } = await supabase.storage
    .from("captures")
    .upload(path, image.bytes, { contentType: image.mimeType, upsert: false });
  if (error) {
    throw new Error(`Sprite upload failed (${path}): ${error.message}`);
  }
}
