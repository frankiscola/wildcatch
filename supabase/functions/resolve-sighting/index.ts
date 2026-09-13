// supabase/functions/resolve-sighting/index.ts
//
// Mechanism 5 of the anti-photo-of-a-screen plan: double sighting.
// Handles two actions, called respectively from
// SupabaseService.recordSighting and SupabaseService.confirmSighting:
//
//  action: "record"  → first shot. Computes the photo's perceptual
//                       hash, checks it doesn't suspiciously match
//                       photos from OTHER users, saves a "pending"
//                       sighting with an expiration.
//
//  action: "confirm" → second shot, within the time window
//                       (mechanism 4). Checks it's plausible that
//                       this is the same animal seen again shortly
//                       after (GPS proximity, consistent species,
//                       an image similar-but-not-identical to the
//                       first), then calls finalizeCapture() and
//                       returns the Wildkin just like generate-wildkin
//                       would.
//
// On rejection it responds with status 409 and { reason: "..." },
// codes the client maps to SightingRejectionReason.

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import type { CaptureContextJson } from "../_shared/typing_engine.ts";
import { finalizeCapture } from "../_shared/finalize_capture.ts";
import { computeAverageHash, hammingDistance } from "../_shared/phash.ts";

// ── Thresholds, all to be recalibrated with real usage data ──
const SIGHTING_WINDOW_MINUTES = 20;
const MAX_DISTANCE_METERS = 300;
// 64-bit hash: distance 0-2 = practically the same image.
const SAME_IMAGE_MAX_DISTANCE = 3;
// Above this threshold two photos are considered "clearly different
// subjects/moments"; below it, and belonging to ANOTHER user, they're
// treated as a suspicious duplicate taken from the internet.
const CROSS_USER_DUPLICATE_MAX_DISTANCE = 6;

interface RequestBody {
  action: "record" | "confirm";
  original_photo_url: string;
  context: CaptureContextJson;
  species_hint?: string | null;
  sighting_id?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as RequestBody;
    const { action, original_photo_url, context } = body;

    if (!action || !original_photo_url || !context) {
      return jsonResponse(
        { error: "action, original_photo_url, and context are required." },
        400,
      );
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

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return jsonResponse({ error: "Invalid or expired token." }, 401);
    }
    const userId = userData.user.id;

    if (action === "record") {
      return await handleRecord(supabase, userId, body);
    }
    return await handleConfirm(supabase, userId, body);
  } catch (e) {
    console.error("Unhandled error:", e);
    return jsonResponse({ error: "Internal error." }, 500);
  }
});

async function handleRecord(
  supabase: SupabaseClient,
  userId: string,
  body: RequestBody,
): Promise<Response> {
  const ahash = await computeAverageHash(body.original_photo_url);

  const duplicate = await findCrossUserDuplicate(supabase, userId, ahash);
  if (duplicate) {
    return jsonResponse({ reason: "suspicious_duplicate_of_other_user" }, 409);
  }

  const expiresAt = new Date(Date.now() + SIGHTING_WINDOW_MINUTES * 60_000);

  const { data: sighting, error } = await supabase
    .from("sightings")
    .insert({
      user_id: userId,
      photo_url: body.original_photo_url,
      photo_ahash: ahash,
      species_hint: normalizeSpecies(body.species_hint),
      latitude: body.context.latitude,
      longitude: body.context.longitude,
      sighted_at: body.context.captured_at,
      expires_at: expiresAt.toISOString(),
    })
    .select()
    .single();

  if (error) {
    console.error("Insert sighting error:", error);
    return jsonResponse({ error: "Could not record the sighting." }, 500);
  }

  await supabase.from("photo_hashes").insert({
    user_id: userId,
    ahash,
    source: "sighting",
  });

  return jsonResponse(
    {
      sighting_id: sighting.id,
      expires_at: sighting.expires_at,
      latitude: sighting.latitude,
      longitude: sighting.longitude,
    },
    200,
  );
}

async function handleConfirm(
  supabase: SupabaseClient,
  userId: string,
  body: RequestBody,
): Promise<Response> {
  if (!body.sighting_id) {
    return jsonResponse({ error: "sighting_id is required for confirm." }, 400);
  }

  const { data: sighting, error: fetchError } = await supabase
    .from("sightings")
    .select()
    .eq("id", body.sighting_id)
    .eq("user_id", userId)
    .single();

  if (fetchError || !sighting) {
    return jsonResponse({ error: "Sighting not found." }, 404);
  }

  if (sighting.status !== "pending") {
    return jsonResponse({ reason: "expired" }, 409);
  }

  if (new Date(sighting.expires_at).getTime() < Date.now()) {
    await supabase.from("sightings").update({ status: "expired" }).eq("id", sighting.id);
    return jsonResponse({ reason: "expired" }, 409);
  }

  const distanceMeters = haversineMeters(
    sighting.latitude,
    sighting.longitude,
    body.context.latitude,
    body.context.longitude,
  );
  if (distanceMeters > MAX_DISTANCE_METERS) {
    return jsonResponse({ reason: "too_far" }, 409);
  }

  const newSpecies = normalizeSpecies(body.species_hint);
  if (sighting.species_hint && newSpecies && sighting.species_hint !== newSpecies) {
    return jsonResponse({ reason: "species_mismatch" }, 409);
  }

  const newAhash = await computeAverageHash(body.original_photo_url);

  const distanceFromFirstShot = hammingDistance(sighting.photo_ahash, newAhash);
  if (distanceFromFirstShot <= SAME_IMAGE_MAX_DISTANCE) {
    return jsonResponse({ reason: "duplicate_image" }, 409);
  }

  const duplicate = await findCrossUserDuplicate(supabase, userId, newAhash);
  if (duplicate) {
    return jsonResponse({ reason: "suspicious_duplicate_of_other_user" }, 409);
  }

  // All checks passed: finalize the capture using the context of
  // THIS second shot (that's the moment the capture is actually
  // completed).
  const inserted = await finalizeCapture(supabase, {
    userId,
    originalPhotoUrl: body.original_photo_url,
    speciesHint: newSpecies ?? sighting.species_hint ?? "???",
    context: body.context,
  });

  await supabase
    .from("sightings")
    .update({ status: "confirmed", matched_capture_id: inserted.id })
    .eq("id", sighting.id);

  await supabase.from("photo_hashes").insert({
    user_id: userId,
    ahash: newAhash,
    source: "capture",
  });

  return jsonResponse(inserted, 200);
}

/// Looks, among photos already seen from OTHER users, for a hash too
/// similar to the one passed in. Doesn't look at the user's own
/// photos: this is only concerned with the "image taken from the
/// internet and already used by someone else" case, not the
/// comparison between the two shots of the same sighting (handleConfirm
/// does that separately).
async function findCrossUserDuplicate(
  supabase: SupabaseClient,
  userId: string,
  ahash: string,
): Promise<boolean> {
  // See the scalability note in 0002_anti_spoof.sql: for a hobby app
  // it's perfectly fine to compare against a recent batch instead of
  // the full history.
  const { data: rows, error } = await supabase
    .from("photo_hashes")
    .select("ahash, user_id")
    .neq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(2000);

  if (error || !rows) return false;

  return rows.some((row) => hammingDistance(row.ahash, ahash) <= CROSS_USER_DUPLICATE_MAX_DISTANCE);
}

function normalizeSpecies(hint: string | null | undefined): string | null {
  if (!hint) return null;
  return hint.trim().toLowerCase();
}

/// Distance in meters between two GPS coordinates (haversine formula).
function haversineMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6_371_000;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
