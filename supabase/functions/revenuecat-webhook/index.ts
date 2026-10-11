// supabase/functions/revenuecat-webhook/index.ts
//
// Receives subscription lifecycle events from RevenueCat and keeps
// `profiles` (is_premium, premium_expires_at, capture_tokens) in
// sync. This is the ONLY place that grants premium/tokens from a
// real purchase — the Flutter client never writes these fields
// itself (see entitlements.ts for why).
//
// !! DEPLOY WITH JWT VERIFICATION DISABLED !!
// RevenueCat sends its OWN shared-secret value in the Authorization
// header, not a Supabase JWT. With Supabase's default JWT check on,
// the gateway rejects every webhook with a 401 before this code even
// runs — it would look deployed and healthy while never receiving a
// single event. Deploy with:
//   supabase functions deploy revenuecat-webhook --no-verify-jwt
// The shared-secret check below is what actually authenticates calls.
//
// Setup required on your side:
//   1. RevenueCat dashboard -> Project settings -> Webhooks:
//      URL = https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook
//      Authorization header value = a secret of your choosing.
//   2. supabase secrets set REVENUECAT_WEBHOOK_SECRET=<that same value>
//   3. Make sure the entitlement identifier in RevenueCat is exactly
//      "premium" (or change ENTITLEMENT_ID below to match).
//   4. Adjust CONSUMABLE_TOKEN_PRODUCTS below to your real product
//      identifiers from App Store Connect / Play Console.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ENTITLEMENT_ID = "premium";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// product_id (as configured in RevenueCat/App Store/Play Store) ->
// how many capture tokens a NON_RENEWING_PURCHASE of it grants.
// These are placeholders — replace with your real product IDs.
const CONSUMABLE_TOKEN_PRODUCTS: Record<string, number> = {
  tokens_5: 5,
  tokens_15: 15,
  tokens_40: 40,
};

interface RevenueCatEvent {
  id: string;
  type: string;
  app_user_id: string;
  aliases?: string[];
  original_app_user_id?: string;
  product_id?: string;
  entitlement_ids?: string[] | null;
  expiration_at_ms?: number | null;
  environment?: string;
}

interface WebhookPayload {
  api_version: string;
  event: RevenueCatEvent;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const expectedAuth = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  const receivedAuth = req.headers.get("Authorization");
  if (!expectedAuth || receivedAuth !== expectedAuth) {
    // Deliberately vague: don't help an attacker figure out whether
    // the secret is merely wrong or entirely unset.
    return new Response("Unauthorized", { status: 401 });
  }

  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const event = payload.event;
  if (!event?.id || !event.type || !event.app_user_id) {
    return new Response("Malformed event", { status: 400 });
  }

  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Idempotency: RevenueCat retries webhooks that don't respond fast
  // enough or that fail, REUSING THE SAME event.id. If we've already
  // recorded this id, acknowledge and do nothing — processing it
  // twice would double-grant tokens.
  const { error: insertError } = await supabaseAdmin
    .from("revenuecat_events")
    .insert({
      event_id: event.id,
      event_type: event.type,
      app_user_id: event.app_user_id,
      raw_payload: payload,
    });

  if (insertError) {
    // Unique violation on event_id = already processed this one.
    if (insertError.code === "23505") {
      return new Response("Already processed", { status: 200 });
    }
    console.error("Could not log webhook event:", insertError);
    return new Response("Internal error", { status: 500 });
  }

  // The RevenueCat app_user_id is set to Supabase's auth.uid() from
  // the Flutter side (Purchases.logIn with the Supabase user id) —
  // see purchases_service.dart. If a purchase ever happens BEFORE
  // that login, RevenueCat reports it under an anonymous id like
  // "$RCAnonymousID:abc123", which maps to no profile at all.
  // Retrying can't fix that, so acknowledge it (200) instead of
  // making RevenueCat retry forever, but log it loudly so the
  // purchase can be reconciled by hand.
  const userId = event.app_user_id;
  if (!UUID_PATTERN.test(userId)) {
    console.warn(
      `Event ${event.id} (${event.type}) has a non-UUID app_user_id ` +
        `"${userId}" — not attributable to a Supabase user. ` +
        "Left logged in revenuecat_events for manual reconciliation.",
    );
    return new Response("Not attributable", { status: 200 });
  }

  try {
    switch (event.type) {
      case "INITIAL_PURCHASE":
      case "RENEWAL":
      case "UNCANCELLATION":
      case "PRODUCT_CHANGE": {
        if (!hasPremiumEntitlement(event)) break;
        await grantPremium(supabaseAdmin, userId, event.expiration_at_ms ?? null);
        break;
      }

      case "EXPIRATION": {
        // CANCELLATION deliberately does nothing here: it only means
        // auto-renew was turned off, the subscription is still
        // active until its current period actually ends. EXPIRATION
        // is the real "access should end now" signal.
        if (!hasPremiumEntitlement(event)) break;
        await revokePremium(supabaseAdmin, userId);
        break;
      }

      case "NON_RENEWING_PURCHASE": {
        const tokens = event.product_id
          ? CONSUMABLE_TOKEN_PRODUCTS[event.product_id]
          : undefined;
        if (tokens) {
          await grantTokens(supabaseAdmin, userId, tokens);
        } else {
          console.warn(
            `NON_RENEWING_PURCHASE for unmapped product_id "${event.product_id}" — ` +
              "add it to CONSUMABLE_TOKEN_PRODUCTS if this is a real token pack.",
          );
        }
        break;
      }

      case "CANCELLATION":
      case "BILLING_ISSUE":
      case "TEST":
        // Logged above via revenuecat_events; no profile change needed.
        break;

      default:
        console.warn(`Unhandled RevenueCat event type: ${event.type}`);
    }
  } catch (e) {
    console.error(`Failed to apply event ${event.id} (${event.type}):`, e);

    // The event was marked as "seen" above BEFORE being applied, so
    // that marker must be undone now: RevenueCat's retry reuses the
    // same event.id, and if the marker stayed, the retry would hit
    // the "Already processed" branch and the purchase would never be
    // applied — the player would have paid for nothing, silently.
    // Removing it and returning 500 makes RevenueCat retry with
    // backoff, and the retry gets a clean second attempt.
    const { error: cleanupError } = await supabaseAdmin
      .from("revenuecat_events")
      .delete()
      .eq("event_id", event.id);
    if (cleanupError) {
      // Narrow window, but worth shouting about: if THIS fails too,
      // the retry will be skipped as a duplicate and the purchase
      // needs to be applied by hand from the logged event id.
      console.error(
        `CRITICAL: could not undo idempotency marker for ${event.id}; ` +
          "this purchase may need manual reconciliation.",
        cleanupError,
      );
    }
    return new Response("Processing failed", { status: 500 });
  }

  return new Response("OK", { status: 200 });
});

function hasPremiumEntitlement(event: RevenueCatEvent): boolean {
  return (event.entitlement_ids ?? []).includes(ENTITLEMENT_ID);
}

// deno-lint-ignore no-explicit-any
async function grantPremium(supabase: any, userId: string, expiresAtMs: number | null) {
  await ensureProfileExists(supabase, userId);
  const { data, error } = await supabase
    .from("profiles")
    .update({
      is_premium: true,
      premium_expires_at: expiresAtMs ? new Date(expiresAtMs).toISOString() : null,
    })
    .eq("user_id", userId)
    .select("user_id");
  if (error) throw new Error(`grantPremium failed: ${error.message}`);
  // An update that matches zero rows is NOT an error to Postgres, so
  // without this check a purchase for a user that doesn't exist would
  // look successfully applied while changing nothing.
  if (!data || data.length === 0) {
    throw new Error(`grantPremium matched no profile row for ${userId}`);
  }
}

// deno-lint-ignore no-explicit-any
async function revokePremium(supabase: any, userId: string) {
  const { data, error } = await supabase
    .from("profiles")
    .update({ is_premium: false })
    .eq("user_id", userId)
    .select("user_id");
  if (error) throw new Error(`revokePremium failed: ${error.message}`);
  if (!data || data.length === 0) {
    throw new Error(`revokePremium matched no profile row for ${userId}`);
  }
}

// deno-lint-ignore no-explicit-any
async function grantTokens(supabase: any, userId: string, amount: number) {
  await ensureProfileExists(supabase, userId);
  const { data: profile, error: fetchError } = await supabase
    .from("profiles")
    .select("capture_tokens")
    .eq("user_id", userId)
    .single();
  if (fetchError) throw new Error(`grantTokens read failed: ${fetchError.message}`);

  const { error } = await supabase
    .from("profiles")
    .update({ capture_tokens: (profile.capture_tokens ?? 0) + amount })
    .eq("user_id", userId);
  if (error) throw new Error(`grantTokens write failed: ${error.message}`);
}

/// A purchase can be the very first thing RevenueCat ever tells us
/// about this user — there may be no profiles row yet if they've
/// never captured anything. Insert a bare one if missing, so the
/// update() calls above always have a row to land on.
///
/// NOTE: supabase-js does NOT reject the promise on a database
/// error (a unique violation from the row already existing resolves
/// with `{ error: {...} }`, it doesn't throw) — so there's no need
/// to special-case that here. Any REAL problem will surface from the
/// explicit update()/select() calls right after this, which do check
/// their `error` field and throw.
// deno-lint-ignore no-explicit-any
async function ensureProfileExists(supabase: any, userId: string) {
  await supabase.from("profiles").insert({ user_id: userId });
}
