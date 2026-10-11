// supabase/functions/regenerate-sprite/index.ts
//
// Generates a NEW front/back sprite candidate for an ALREADY-CAPTURED
// Wildkin, keeping the same original photo and species as reference —
// the "reroll if you don't love the result" feature.
//
// It does NOT overwrite the Wildkin's current sprites: it uploads the
// candidate and returns its URLs, so the player can compare it with
// the current design and choose. The client applies the choice (see
// SupabaseService.applySprites). Spends a capture
// token (or is free for an active premium subscriber) via the same
// entitlements pool used for extra captures beyond the daily free
// quota; see _shared/entitlements.ts.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { generateSprites } from "../_shared/sprite_pipeline.ts";
import { ImageProviderError } from "../_shared/image_generation_client.ts";
import { consumeRerollCredit, refundCredit } from "../_shared/entitlements.ts";

interface RequestBody {
  wildkin_id: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { wildkin_id } = (await req.json()) as RequestBody;
    if (!wildkin_id) {
      return jsonResponse({ error: "wildkin_id is required." }, 400);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "User not authenticated." }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return jsonResponse({ error: "Invalid or expired token." }, 401);
    }
    const userId = userData.user.id;

    // RLS on 'captures' already guarantees this only returns a row
    // the caller owns, but the explicit .eq keeps intent obvious.
    const { data: wildkin, error: fetchError } = await supabase
      .from("captures")
      .select("id, user_id, original_photo_url, species_hint, assigned_type")
      .eq("id", wildkin_id)
      .eq("user_id", userId)
      .single();

    if (fetchError || !wildkin) {
      return jsonResponse({ error: "Wildkin not found." }, 404);
    }

    const creditSource = await consumeRerollCredit(supabaseAdmin, userId);
    if (creditSource === null) {
      return jsonResponse({ reason: "no_captures_remaining" }, 409);
    }

    // Unlike a capture (where sprite generation has a photo fallback
    // built in), here generating IS the whole point: if anything
    // below fails on our side, the player got nothing, so refund the
    // credit and report the failure instead of keeping it.
    try {
      const photoResponse = await fetch(wildkin.original_photo_url);
      if (!photoResponse.ok) {
        throw new Error("Could not re-download the original photo.");
      }
      const photoBytes = new Uint8Array(await photoResponse.arrayBuffer());
      const mimeType = guessMimeType(wildkin.original_photo_url);

      // species_hint may legitimately be null: pass it through as-is
      // so the prompt simply omits the species line, instead of
      // injecting a bogus placeholder into it.
      const sprites = await generateSprites(
        { bytes: photoBytes, mimeType },
        wildkin.species_hint ?? null,
        (wildkin.assigned_type as string[] | null) ?? [],
      );

      const spriteId = crypto.randomUUID();
      const frontPath = `${userId}/sprites/${spriteId}_front.png`;
      const backPath = `${userId}/sprites/${spriteId}_back.png`;

      await uploadOrThrow(supabase, frontPath, sprites.front);
      await uploadOrThrow(supabase, backPath, sprites.back);

      const frontSpriteUrl = supabase.storage.from("captures").getPublicUrl(frontPath).data.publicUrl;
      const backSpriteUrl = supabase.storage.from("captures").getPublicUrl(backPath).data.publicUrl;

      // Deliberately NOT written to the captures row: the player
      // decides first whether to keep the current design or use this one.
      return jsonResponse(
        { front_sprite_url: frontSpriteUrl, back_sprite_url: backSpriteUrl },
        200,
      );
    } catch (e) {
      console.error("Sprite regeneration failed, refunding credit:", e);
      await refundCredit(supabaseAdmin, userId, creditSource);

      // The provider's safety system rejected the generated image
      // (even after a retry): not a server fault, tell the client so
      // it can suggest trying again / another photo.
      if (e instanceof ImageProviderError && e.code === "moderation_blocked") {
        return jsonResponse({ reason: "image_blocked" }, 422);
      }

      return jsonResponse(
        { error: "Sprite generation failed. You were not charged." },
        502,
      );
    }
  } catch (e) {
    console.error("Unhandled error:", e);
    return jsonResponse({ error: "Internal error." }, 500);
  }
});

function guessMimeType(url: string): string {
  const lower = url.toLowerCase();
  if (lower.endsWith(".png")) return "image/png";
  if (lower.endsWith(".webp")) return "image/webp";
  return "image/jpeg";
}

async function uploadOrThrow(
  // deno-lint-ignore no-explicit-any
  supabase: any,
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

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
