// supabase/functions/generate-creature/index.ts
//
// Riceve { original_photo_url, context } dal client Flutter
// (SupabaseService.generateCreature), calcola tipo/statistiche/mosse
// /piano evolutivo, salva la riga in 'captures' e restituisce il
// JSON che Creature.fromJson si aspetta.
//
// NOTA sulle sprite: in questa versione front_sprite_url e
// back_sprite_url sono ancora placeholder (= la foto originale).
// La chiamata al servizio di generazione immagini AI è il prossimo
// pezzo da costruire — qui c'è già il punto esatto (TODO più sotto)
// dove andrà agganciata.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { assignTypes, type CaptureContextJson } from "../_shared/typing_engine.ts";
import { generateBaseStats } from "../_shared/stats_engine.ts";
import { starterMoves } from "../_shared/movepool.ts";
import { createInitialEvolutionPlan } from "../_shared/evolution.ts";

interface RequestBody {
  original_photo_url: string;
  context: CaptureContextJson & { species_hint?: string };
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

    // Client "per conto dell'utente": eredita il suo JWT, quindi
    // auth.uid() nelle policy RLS corrisponde a lui. Niente service
    // role key: è il modo più sicuro, l'inserimento passa comunque
    // dalle policy definite in 0001_init.sql.
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

    // 1. Tipo: alla cattura la creatura ha SEMPRE un solo tipo,
    //    anche se assignTypes può restituirne 2 (quel caso è per
    //    l'evoluzione, non per la cattura).
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

    // 5. Statistiche effettive a livello 5 (stessa formula di
    //    Creature.computeStats() lato Dart).
    const level = 5;
    const maxHp = Math.floor((2 * baseStats.hp * level) / 100) + level + 10;

    // 6. Sprite — PLACEHOLDER, vedi nota in testa al file.
    // TODO: sostituire con la chiamata al servizio di image-gen,
    // passandogli original_photo_url + types come indicazione di
    // stile/palette, e ottenendo due URL (fronte/retro) da salvare
    // qui sotto al posto di original_photo_url.
    const frontSpriteUrl = original_photo_url;
    const backSpriteUrl = original_photo_url;

    const row = {
      user_id: userId,
      nickname: context.species_hint ?? "???",
      original_photo_url,
      front_sprite_url: frontSpriteUrl,
      back_sprite_url: backSpriteUrl,
      assigned_type: types,
      species_hint: context.species_hint ?? null,
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
      console.error("Insert error:", insertError);
      return jsonResponse(
        { error: "Impossibile salvare la creatura.", details: insertError.message },
        500,
      );
    }

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
