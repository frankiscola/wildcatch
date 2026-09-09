// supabase/functions/generate-creature/index.ts
//
// Percorso DIRETTO (nessun doppio avvistamento): tenuto per test
// manuali da terminale e come riferimento, ma la UI normale ora passa
// da resolve-sighting (meccanismo 5, doppio avvistamento). Vedi
// _shared/finalize_capture.ts per la logica vera e propria, condivisa
// tra le due function.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import type { CaptureContextJson } from "../_shared/typing_engine.ts";
import { finalizeCapture } from "../_shared/finalize_capture.ts";
import { classifySpecies } from "../_shared/species_classifier.ts";

interface RequestBody {
  original_photo_url: string;
  context: CaptureContextJson;
  // Rilevamento on-device (ML Kit, gratuito) già fatto dal client:
  // se presente, evita del tutto la chiamata a classifySpecies qui
  // sotto (che invece costa, essendo una chiamata a un modello di
  // visione). Vedi discussione sui costi nel README.
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
        { error: "original_photo_url e context sono obbligatori." },
        400,
      );
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Utente non autenticato." }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return jsonResponse({ error: "Token non valido o scaduto." }, 401);
    }
    const userId = userData.user.id;

    // Preferisci sempre l'hint gratuito del client. Il fallback a
    // pagamento scatta solo se il client non ne ha fornito uno (es.
    // ML Kit non ha riconosciuto nulla con sufficiente confidenza).
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
    return jsonResponse({ error: "Errore interno." }, 500);
  }
});

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
