-- Monetization: user profiles (premium status + capture credits),
-- and a log of RevenueCat webhook events for idempotency/debugging.
-- Apply with: supabase db push (after `supabase link`).

-- ─────────────────────────────────────────────────────────────
-- One row per user. Written ONLY by edge functions (service role
-- or the user's own session through SECURITY DEFINER-free direct
-- writes are intentionally NOT allowed from the client — see the
-- RLS policies below): the client can read its own row to show
-- "3 captures left today", but every write goes through
-- entitlements.ts server-side, so nothing here can be tampered with
-- by a modified client.
-- ─────────────────────────────────────────────────────────────
create table if not exists profiles (
  user_id uuid primary key references auth.users on delete cascade,

  is_premium boolean not null default false,
  premium_expires_at timestamptz,

  -- Single currency, spendable on either an extra capture beyond the
  -- daily free quota, or a sprite reroll (see entitlements.ts).
  capture_tokens int not null default 0,

  free_captures_used_today int not null default 0,
  free_captures_reset_at date not null default current_date,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "profiles_select_own" on profiles
  for select using (auth.uid() = user_id);

-- No insert/update/delete policy for authenticated users on purpose:
-- all writes to this table happen through edge functions using the
-- service role key (entitlements.ts, revenuecat-webhook), never
-- directly from the client.

-- ─────────────────────────────────────────────────────────────
-- Every RevenueCat webhook event, kept for idempotency (RevenueCat
-- can and does redeliver events) and for debugging subscription
-- issues after the fact.
-- ─────────────────────────────────────────────────────────────
create table if not exists revenuecat_events (
  event_id text primary key,
  event_type text not null,
  app_user_id text not null,
  raw_payload jsonb not null,
  processed_at timestamptz not null default now()
);

-- No RLS: this table is only ever touched by the webhook edge
-- function using the service role key, never exposed to clients.
alter table revenuecat_events enable row level security;
-- (no policies -> nobody with a normal user token can read/write it)
