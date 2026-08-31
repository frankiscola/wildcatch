-- Schema iniziale per Wildcatch.
-- Applicare con: supabase db push (dopo `supabase link`).

create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────────
-- Tabella principale: le creature catturate da ciascun utente.
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

  base_stats jsonb not null,       -- {hp, attack, defense, sp_attack, sp_defense, speed}
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

  -- valorizzato solo dopo la prima evoluzione
  evolution_context jsonb,

  created_at timestamptz not null default now()
);

create index if not exists captures_user_id_idx on captures (user_id);

-- ─────────────────────────────────────────────────────────────
-- Log delle battaglie (cattura riuscita/fallita, KO, ecc).
-- ─────────────────────────────────────────────────────────────
create table if not exists battle_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  creature_id uuid references captures not null,
  wild_snapshot jsonb not null,
  outcome text not null,           -- 'caught' | 'fled' | 'fainted_own'
  created_at timestamptz not null default now()
);

create index if not exists battle_logs_user_id_idx on battle_logs (user_id);

-- ─────────────────────────────────────────────────────────────
-- Row Level Security: ogni utente vede e scrive solo i propri dati.
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
-- Bucket di storage per le foto originali e (in futuro) le sprite.
-- Pubblico in lettura per semplicità di MVP: chiunque abbia l'URL
-- può vedere l'immagine, ma solo il proprietario può caricarla,
-- perché il path atteso è "<user_id>/<timestamp>.jpg" (vedi
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
