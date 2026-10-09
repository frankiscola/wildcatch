// Server-side enforcement for monetization. This is the ONLY place
// that should decide whether a capture or a sprite reroll is allowed
// to proceed — never trust a client-side check for this, since
// that's exactly what protects real money (the OpenAI cost of
// generateSprites) from being spent on behalf of someone who hasn't
// paid or used up their free quota.

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const DAILY_FREE_CAPTURES = 3;

export interface Profile {
  user_id: string;
  is_premium: boolean;
  premium_expires_at: string | null;
  capture_tokens: number;
  free_captures_used_today: number;
  free_captures_reset_at: string; // date, 'YYYY-MM-DD'
}

/// Fetches the user's profile, creating a fresh one (0 tokens, no
/// premium, today's date) on first use. Also resets the daily free
/// counter if the stored reset date isn't today anymore — done here,
/// lazily, so there's no need for a cron job just to zero everyone's
/// counter at midnight.
export async function getOrCreateProfile(
  supabase: SupabaseClient,
  userId: string,
): Promise<Profile> {
  const { data: existing } = await supabase
    .from("profiles")
    .select()
    .eq("user_id", userId)
    .maybeSingle();

  const today = new Date().toISOString().slice(0, 10);

  if (!existing) {
    const { data: created, error } = await supabase
      .from("profiles")
      .insert({ user_id: userId, free_captures_reset_at: today })
      .select()
      .single();
    if (error) throw new Error(`Could not create profile: ${error.message}`);
    return created as Profile;
  }

  if (existing.free_captures_reset_at !== today) {
    const { data: updated, error } = await supabase
      .from("profiles")
      .update({ free_captures_used_today: 0, free_captures_reset_at: today })
      .eq("user_id", userId)
      .select()
      .single();
    if (error) throw new Error(`Could not reset daily quota: ${error.message}`);
    return updated as Profile;
  }

  return existing as Profile;
}

function isPremiumActive(profile: Profile): boolean {
  if (!profile.is_premium) return false;
  if (!profile.premium_expires_at) return true; // shouldn't happen, but don't punish for it
  return new Date(profile.premium_expires_at).getTime() > Date.now();
}

/// Which pool a credit was taken from. Needed so a failed operation
/// can refund exactly what it took (a premium user consumed nothing,
/// so there's nothing to give back).
export type CreditSource = "premium" | "free" | "token";

/// Call before actually finalizing a capture (i.e. before spending
/// money on sprite generation). Returns the source the credit was
/// taken from — or `null` (consuming NOTHING) if the player has run
/// out of every option.
///
/// If the operation this credit was for then fails, call
/// [refundCredit] with the returned source.
///
/// NOTE on race conditions: this is a plain read-then-write, not a
/// single atomic SQL statement. For a hobby app's traffic this is an
/// acceptable trade-off (worst case, a player who double-taps fast
/// enough could sneak in one extra free capture) — the same kind of
/// pragmatic call already made for photo_hashes elsewhere in this
/// codebase. Worth revisiting with a proper `for update` row lock if
/// this ever needs to hold up under real concurrent load.
export async function consumeCaptureCredit(
  supabase: SupabaseClient,
  userId: string,
): Promise<CreditSource | null> {
  const profile = await getOrCreateProfile(supabase, userId);

  if (isPremiumActive(profile)) return "premium";

  if (profile.free_captures_used_today < DAILY_FREE_CAPTURES) {
    await supabase
      .from("profiles")
      .update({ free_captures_used_today: profile.free_captures_used_today + 1 })
      .eq("user_id", userId);
    return "free";
  }

  if (profile.capture_tokens > 0) {
    await supabase
      .from("profiles")
      .update({ capture_tokens: profile.capture_tokens - 1 })
      .eq("user_id", userId);
    return "token";
  }

  return null;
}

/// Same idea, for regenerating a sprite the player already has.
/// Unlike captures, rerolls have NO daily free allowance — always a
/// token, unless premium (which gets unlimited rerolls too).
export async function consumeRerollCredit(
  supabase: SupabaseClient,
  userId: string,
): Promise<CreditSource | null> {
  const profile = await getOrCreateProfile(supabase, userId);

  if (isPremiumActive(profile)) return "premium";

  if (profile.capture_tokens > 0) {
    await supabase
      .from("profiles")
      .update({ capture_tokens: profile.capture_tokens - 1 })
      .eq("user_id", userId);
    return "token";
  }

  return null;
}

/// Gives back a credit taken by [consumeCaptureCredit] /
/// [consumeRerollCredit] when the operation it paid for FAILED on our
/// side (e.g. the image API errored out). Never call this for
/// rejections that are the player's doing (expired sighting, species
/// mismatch...) — those don't reach the point of consuming anything.
export async function refundCredit(
  supabase: SupabaseClient,
  userId: string,
  source: CreditSource,
): Promise<void> {
  if (source === "premium") return; // nothing was taken

  const profile = await getOrCreateProfile(supabase, userId);

  if (source === "token") {
    await supabase
      .from("profiles")
      .update({ capture_tokens: profile.capture_tokens + 1 })
      .eq("user_id", userId);
    return;
  }

  // "free": never go below zero (e.g. the daily counter may have
  // been reset at midnight between the consume and the refund).
  await supabase
    .from("profiles")
    .update({
      free_captures_used_today: Math.max(0, profile.free_captures_used_today - 1),
    })
    .eq("user_id", userId);
}

/// Read-only status for the client to display ("2 free captures left
/// today", "5 tokens"), without consuming anything.
export async function getEntitlementStatus(
  supabase: SupabaseClient,
  userId: string,
) {
  const profile = await getOrCreateProfile(supabase, userId);
  const premiumActive = isPremiumActive(profile);
  return {
    is_premium: premiumActive,
    premium_expires_at: profile.premium_expires_at,
    capture_tokens: profile.capture_tokens,
    free_captures_remaining: premiumActive
      ? null // unlimited, not a number worth showing
      : Math.max(0, DAILY_FREE_CAPTURES - profile.free_captures_used_today),
  };
}
