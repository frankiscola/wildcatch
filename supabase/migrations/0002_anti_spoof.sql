-- Meccanismo 5 (doppio avvistamento) e dedup globale delle foto.
-- Applicare con: supabase db push (dopo `supabase link`).

-- ─────────────────────────────────────────────────────────────
-- Avvistamenti in attesa di conferma. Un avvistamento diventa una
-- 'captures' solo se confermato entro expires_at da una seconda foto
-- plausibilmente dello stesso animale (vedi resolve-sighting).
-- ─────────────────────────────────────────────────────────────
create table if not exists sightings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,

  photo_url text not null,
  photo_ahash text not null,        -- average-hash esadecimale (16 char = 64 bit)
  species_hint text,                -- rilevamento on-device (ML Kit), nullable

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
-- Hash percettivo di OGNI foto vista dall'app (sia i due scatti di
-- un avvistamento sia, in futuro, eventuali foto di battaglia), per
-- poter controllare se una nuova foto combacia in modo sospetto con
-- una già vista da un altro utente — segnale forte di "immagine
-- presa da internet", perché una foto scattata dal vivo è
-- statisticamente unica.
--
-- NIENTE dati sensibili in questa tabella (solo un hash e l'id
-- utente): per questo la SELECT è permessa a chiunque sia
-- autenticato, non solo al proprietario — il controllo di dedup deve
-- poter confrontare con le foto di TUTTI gli utenti, non solo le
-- proprie.
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

-- NOTA SULLA SCALABILITÀ: oggi resolve-sighting scarica un batch di
-- hash recenti e calcola la distanza di Hamming in JavaScript, il che
-- va benissimo per un'app hobby/con pochi utenti. Se il volume di
-- catture cresce molto, conviene o (a) precalcolare bucket di hash
-- simili con un'estensione tipo pg_trgm/pgvector, oppure (b) tenere
-- solo una finestra temporale recente di photo_hashes invece che lo
-- storico completo.
