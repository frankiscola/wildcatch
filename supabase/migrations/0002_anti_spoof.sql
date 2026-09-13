-- Mechanism 5 (double sighting) and global photo dedup.
-- Apply with: supabase db push (after `supabase link`).

-- ─────────────────────────────────────────────────────────────
-- Sightings awaiting confirmation. A sighting becomes a 'captures'
-- row only if confirmed within expires_at by a second photo
-- plausibly of the same animal (see resolve-sighting).
-- ─────────────────────────────────────────────────────────────
create table if not exists sightings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,

  photo_url text not null,
  photo_ahash text not null,        -- hex average-hash (16 chars = 64 bits)
  species_hint text,                -- on-device detection (ML Kit), nullable

  latitude double precision not null,
  longitude double precision not null,
  sighted_at timestamptz not null default now(),
  expires_at timestamptz not null,

  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'expired', 'rejected')),
  matched_capture_id uuid references captures(id),

  created_at timestamptz not null default now()
);

create index if not exists sightings_user_id_idx on sightings (user_id);
create index if not exists sightings_status_idx on sightings (status);

alter table sightings enable row level security;

create policy "sightings_select_own" on sightings
  for select using (auth.uid() = user_id);

create policy "sightings_insert_own" on sightings
  for insert with check (auth.uid() = user_id);

create policy "sightings_update_own" on sightings
  for update using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- Perceptual hash of EVERY photo the app has seen (both shots of a
-- sighting and, in the future, any battle photos), to check whether
-- a new photo suspiciously matches one already seen from another
-- user — a strong signal of "image taken from the internet", since a
-- live-taken photo is statistically unique.
--
-- NO sensitive data in this table (just a hash and the user id):
-- that's why SELECT is allowed to anyone authenticated, not just the
-- owner — the dedup check needs to compare against ALL users'
-- photos, not just its own.
-- ─────────────────────────────────────────────────────────────
create table if not exists photo_hashes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  ahash text not null,
  source text not null check (source in ('sighting', 'capture')),
  created_at timestamptz not null default now()
);

create index if not exists photo_hashes_ahash_idx on photo_hashes (ahash);

alter table photo_hashes enable row level security;

create policy "photo_hashes_select_all_authenticated" on photo_hashes
  for select using (auth.role() = 'authenticated');

create policy "photo_hashes_insert_own" on photo_hashes
  for insert with check (auth.uid() = user_id);

-- SCALABILITY NOTE: today resolve-sighting downloads a batch of
-- recent hashes and computes the Hamming distance in JavaScript,
-- which is perfectly fine for a hobby app with few users. If capture
-- volume grows a lot, it's worth either (a) precomputing buckets of
-- similar hashes with an extension like pg_trgm/pgvector, or (b)
-- keeping only a recent time window of photo_hashes instead of the
-- full history.
