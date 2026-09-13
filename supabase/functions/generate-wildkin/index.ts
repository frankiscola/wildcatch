// supabase/functions/generate-wildkin/index.ts
//
// DIRECT path (no double sighting): kept for manual testing from the
// terminal and as a reference, but the normal UI now goes through
// resolve-sighting (mechanism 5, double sighting). See
// _shared/finalize_capture.ts for the actual logic, shared between
// the two functions.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import type { CaptureContextJson } from "../_shared/typing_engine.ts";
import { finalizeCapture } from "../_shared/finalize_capture.ts";
import { classifySpecies } from "../_shared/species_classifier.ts";

interface RequestBody {
  original_photo_url: string;
  context: CaptureContextJson;
  // On-device detection (ML Kit, free) already done by the client:
  // if present, it entirely skips the classifySpecies call below
  // (which costs money, being a call to a vision model). See the
  // cost discussion in the README.
  species_hint?: string | null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as RequestBody;
    const { original_photo_url, context } = body;

    if (!original_photo_url || !context) {
      return jsonResponse(
        { error: "original_photo_url and context are required." },
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

    // Always prefer the client's free hint. The paid fallback only
    // kicks in if the client didn't provide one (e.g. ML Kit didn't
    // recognize anything with enough confidence).
    const speciesHint = body.species_hint ?? (await classifySpecies(original_photo_url));

    const inserted = await finalizeCapture(supabase, {
      userId,
      originalPhotoUrl: original_photo_url,
      speciesHint,
      context,
    });

    return jsonResponse(inserted, 200);
  } catch (e) {
    console.error("Unhandled error:", e);
    return jsonResponse({ error: "Internal error." }, 500);
  }
});

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
