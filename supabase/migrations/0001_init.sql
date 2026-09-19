-- Initial schema for Wildkin.
-- Apply with: supabase db push (after `supabase link`).

create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────────
-- Main table: the Wildkin captured by each user.
-- ─────────────────────────────────────────────────────────────
create table if not exists captures (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,

  nickname text not null default '???',
  original_photo_url text not null,
  front_sprite_url text,
  back_sprite_url text,
  assigned_type text[] not null,
  species_hint text,

  level int not null default 5,
  current_exp int not null default 0,
  current_hp int not null,

  base_stats jsonb not null,       -- {hp, attack, defense, elementalAttack, elementalDefense, speed}
  moves jsonb not null,            -- [{move: {...}, current_pp}, ...]
  evolution_plan jsonb not null,   -- {total_stages, current_stage, next_evolution_level, second_evolution_level}

  captured_at timestamptz not null,
  latitude double precision not null,
  longitude double precision not null,
  elevation_m double precision,
  weather_condition text not null,
  temperature_c double precision not null,
  humidity_percent double precision,
  wind_speed_kmh double precision,

  -- only set after the first evolution
  evolution_context jsonb,

  created_at timestamptz not null default now()
);

create index if not exists captures_user_id_idx on captures (user_id);

-- ─────────────────────────────────────────────────────────────
-- Battle logs (successful/failed capture, fainting, etc).
-- ─────────────────────────────────────────────────────────────
create table if not exists battle_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  creature_id uuid references captures not null, -- NOTE: kept as 'creature_id' to match the already-deployed schema; a future migration could rename it to 'wildkin_id'
  wild_snapshot jsonb not null,
  outcome text not null,           -- 'caught' | 'fled' | 'fainted_own'
  created_at timestamptz not null default now()
);

create index if not exists battle_logs_user_id_idx on battle_logs (user_id);

-- ─────────────────────────────────────────────────────────────
-- Row Level Security: every user can only see and write their own data.
-- ─────────────────────────────────────────────────────────────
alter table captures enable row level security;
alter table battle_logs enable row level security;

create policy "captures_select_own" on captures
  for select using (auth.uid() = user_id);

create policy "captures_insert_own" on captures
  for insert with check (auth.uid() = user_id);

create policy "captures_update_own" on captures
  for update using (auth.uid() = user_id);

create policy "battle_logs_select_own" on battle_logs
  for select using (auth.uid() = user_id);

create policy "battle_logs_insert_own" on battle_logs
  for insert with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- Storage bucket for the original photos and (in the future) the
-- sprites. Publicly readable for MVP simplicity: anyone with the URL
-- can view the image, but only the owner can upload it, because the
-- expected path is "<user_id>/<timestamp>.jpg" (see
-- SupabaseService.uploadOriginalPhoto in Flutter).
-- ─────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('captures', 'captures', true)
on conflict (id) do nothing;

create policy "captures_bucket_owner_upload"
on storage.objects for insert
with check (
  bucket_id = 'captures'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "captures_bucket_public_read"
on storage.objects for select
using (bucket_id = 'captures');
