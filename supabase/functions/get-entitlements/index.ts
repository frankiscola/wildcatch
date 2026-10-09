// supabase/functions/get-entitlements/index.ts
//
// Read-only status for the client: premium state, daily free
// captures remaining, token balance. Used to show things like
// "2 captures left today" before the player even tries one — never
// used to gate anything itself (resolve-sighting/regenerate-sprite
// do that independently, right before spending real money).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { getEntitlementStatus } from "../_shared/entitlements.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
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

    // Service-role client: see the note in entitlements.ts about why
    // 'profiles' has no client-writable RLS policy, and reads go
    // through here rather than a SELECT policy, for one consistent
    // code path.
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const status = await getEntitlementStatus(supabaseAdmin, userData.user.id);
    return jsonResponse(status, 200);
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
