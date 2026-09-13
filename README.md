# Wildkin — Flutter scaffold

Starting scaffold for the app: photograph an animal, get back a
pixel-art creature (gen 3/4 style) with front/back sprites, levels,
moves, stats, and evolutions — whose type depends on weather, GPS
location, and time of capture (and, at the first evolution, also on
the moment of the evolution itself).

## What's already there

### UI
Retro RPG dialog boxes, pixel buttons, type badges, an animated
capture scanner, stat/HP bars — `lib/widgets/`, `lib/theme/`.

### Client-side game flow
- **Capture**: photo → GPS/weather → upload → generation → reveal
  (`lib/providers/capture_flow_provider.dart`).
- **Battle**: against a wild Wildkin just photographed, with the
  option to weaken it before attempting a capture
  (`lib/screens/battle_screen.dart`, `lib/services/battle_engine.dart`).

### Game engines (`lib/services/`)
- `typing_engine.dart` — assigns 1+ types based on
  weather/season/biome/time, restricted to the 11 types in the game
  (see `lib/models/type_chart.dart`).
- `stats_engine.dart` — generates the 6 base stats (HP, Attack,
  Defense, Insight, Ward, Speed) with a small thematic bias per type.
- `movepool.dart` — move table per type (power/accuracy/PP), 4
  starting moves at tier 1, stronger moves unlockable at tiers 2/3.
  All move names are original, not translations of any existing
  game's moves.
- `evolution_engine.dart` — decides whether a Wildkin will have 1 or
  2 future evolutions, the random levels at which they trigger
  (hidden from the player, who only sees a qualitative hint), and
  determines the second type at the first evolution by combining the
  capture context with the context of the exact moment of evolution.
- `battle_engine.dart` — simplified damage resolution (now with type
  effectiveness, see `type_chart.dart`) and capture probability in
  the classic style (the lower the wild Wildkin's HP, the higher the
  probability).

### Models (`lib/models/`)
`wildkin.dart` (with level, exp, current HP, base stats, moves,
evolution plan, capture AND evolution context), `move.dart`,
`stats.dart`, `evolution_plan.dart`, `wild_encounter.dart`,
`type_chart.dart`, `sighting.dart`.

## Implemented progression rules

- **Capture level**: always 5, always base form (see
  `EvolutionEngine.createInitialPlan`).
- **Evolutionary line**: 50% of captures have 2 total stages (1
  evolution only), 50% have 3 (2 evolutions) — an easily adjustable
  threshold in `evolution_engine.dart` if you want to weight it
  differently.
- **Evolution levels** (never shown in full to the player):
  - 3-stage lines: first jump between level 15 and 30, second jump
    between 30 and 50 (always guaranteed after the first);
  - 2-stage lines: a single jump between level 30 and 50.
- **A hint, not a number**: `EvolutionPlan.timingLabel()` returns
  "soon / average / late" based on where the generated level falls
  in the possible range, without ever revealing it.
- **Second type**: assigned only at the first evolution, combining
  the typing engine applied to both the capture context and the
  evolution context (weighted slightly more) — see
  `EvolutionEngine.determineSecondType`.
- **Moves**: 4 at capture (tier 1, matching the type), replaceable
  with stronger moves (tier 2 from level ~25, tier 3 from level
  ~60). The UI for "choosing which move to forget" when a new one is
  learned still needs to be added (today `MovePool.nextMoveToLearn`
  only returns the candidate; the caller decides the replacement).
- **Easier capture when weakened**: `BattleEngine.catchProbability`
  uses the same logic as the classic formula (ratio of the wild
  Wildkin's current/max HP).
- **Type effectiveness**: implemented in `battle_engine.dart` via
  `TypeChart.effectiveness`, with "super effective / not very
  effective / no effect" messages shown in battle.

## Supabase backend (already set up in `supabase/`)

```
supabase/
  migrations/
    0001_init.sql                    # tables, RLS, storage bucket
    0002_anti_spoof.sql              # sightings + photo_hashes (see below)
  functions/
    _shared/                        # TS port of the Dart engines
      typing_engine.ts
      stats_engine.ts
      movepool.ts
      evolution.ts
      type_chart.ts                 # not called by any function yet, see below
      cors.ts
      finalize_capture.ts           # shared capture logic (formerly in generate-wildkin)
      phash.ts                      # perceptual hash, for the double sighting
      species_classifier.ts         # Claude vision fallback for species detection
    generate-wildkin/index.ts      # direct path, kept for manual testing
    resolve-sighting/index.ts       # normal path: double sighting
```

`finalize_capture.ts` contains the logic that used to live entirely
inside `generate-wildkin`: it computes type, stats, starting moves,
and evolution plan, saves the row into `captures` respecting the RLS
policies, and returns the JSON that `Wildkin.fromJson` already
expects on the Flutter side. It's now called from two places:

- `generate-wildkin/index.ts`, the direct path (a single shot, no
  anti-spoofing checks) — useful for testing from the terminal,
  **no longer used by the normal UI**.
- `resolve-sighting/index.ts`, the path the UI actually uses: see the
  "Anti-photo-of-a-screen" section below.

### Deploy

```bash
npm install -g supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF

supabase db push                          # creates tables, RLS, bucket (incl. 0002_anti_spoof.sql)
supabase functions deploy generate-wildkin
supabase functions deploy resolve-sighting
```

Then in `lib/services/supabase_service.dart` replace
`YOUR_PROJECT_REF` and `YOUR_SUPABASE_ANON_KEY` with the real values
(dashboard → Settings → API).

### Anonymous sign-in (required)

`generate-wildkin` requires an authenticated user (the RLS policies
rely on `auth.uid()`). `main.dart` already signs in anonymously
automatically on startup — the only thing left to do is enable it in
the dashboard: **Authentication → Providers → Anonymous Sign-Ins**.

### Quick check from the terminal

```bash
supabase functions invoke generate-wildkin --data '{
  "original_photo_url": "https://example.com/test.jpg",
  "context": {
    "captured_at": "2026-08-30T14:00:00.000Z",
    "latitude": 41.9,
    "longitude": 12.5,
    "elevation_meters": 20,
    "biome": "urbanCity",
    "weather_condition": "clear",
    "temperature_celsius": 32,
    "humidity_percent": 40,
    "wind_speed_kmh": 5,
    "is_night_time": false,
    "season": "summer"
  }
}'
```

With these values (summer, 32°C, city) you should see a Wildkin with
good odds of a fire/ground/electric/rock type — a good way to confirm
the typing engine was ported correctly to TypeScript.

## Anti-photo-of-a-screen / re-shot-photo

Five mechanisms, meant to raise the friction for anyone trying to
capture from a photo found online instead of a real animal. None of
these is foolproof on its own (see the comments in the respective
files): the goal is their sum, not one perfect check.

1. **Burst + parallax** (`lib/services/liveness_service.dart`): 3
   closely spaced frames, 3x3-grid block-matching, a score of how
   unevenly the blocks move relative to each other. Near zero =
   probably a flat surface.
2. **Depth** (`lib/services/depth_check_service.dart`): scaffold
   ONLY, always degrades to "not available" until the native code is
   written (see the comments in the file for what to implement on
   iOS/Android). Never blocks anything on its own.
3. **Gyroscope correlation** ("poor man's AR", same file as point 1):
   the phone must have physically moved at least a little during the
   shot. "Moved" frames but a still gyroscope (or vice versa) is a
   suspicious inconsistency.
4. **Time window** (`kSightingWindowDuration` in
   `capture_flow_provider.dart`, 20 minutes): the second shot must
   arrive within this time of the first, or everything is canceled
   (`CaptureStep.sightingExpired`).
5. **Double sighting** (`supabase/functions/resolve-sighting/`): the
   real heart of the system. The first shot records a "pending
   sighting"; the second, to be accepted, must happen within ~300m of
   the first, with a consistent species (if detected), and with an
   image that is NEITHER identical to the first (otherwise it's the
   same static photo shown again) NOR too similar to a photo already
   seen from another user (global dedup via `photo_hashes`,
   perceptual hash in `_shared/phash.ts`).

Points 1-4 travel inside `CaptureContext.liveness` sent to the server
as a clue, NEVER as the sole defense (a tampered client can always
lie about these values) — the truly robust barrier is point 5,
because it doesn't depend on anything the client claims to have
measured.

All the signals/thresholds (block-matching search radius, Hamming
distance thresholds, 300m, 20 minutes...) are reasonable starting
points but NOT calibrated on real data: they need to be tested on
real devices and adjusted.

## What's still missing

1. **Real image generation**: today `front_sprite_url` and
   `back_sprite_url` are placeholders (= the original photo). The
   exact spot to hook up the AI service is marked with a TODO in
   `supabase/functions/_shared/finalize_capture.ts`.

2. **`evolve-wildkin` edge function** (not written yet): same pattern
   as `finalize_capture.ts`, but will also use `determineSecondType`
   (to be ported from `evolution_engine.dart`) and will receive the
   CURRENT context in addition to the Wildkin's id.

3. **`resolve-wild-encounter` edge function** (not written yet,
   optional if you'd rather generate the encounter client-side):
   needed to connect `BattleScreen` to the rest of the flow.

4. **Native code for the depth signal** (mechanism 2, optional): see
   the TODOs in `depth_check_service.dart`. Today the signal is
   always `null` on every device.

5. **Calibration on real devices** of all the anti-spoofing plan's
   thresholds (see the section above): they were written at a desk,
   never tested with real hardware.

6. **New artwork for the type badges**: the current
   `assets/type_badges/*.png` icons and the very first version of the
   type color palette were too close to an existing game's official
   colors/icon style. The colors have already been replaced with an
   original palette (see `lib/theme/app_colors.dart`), but the badge
   PNGs themselves should be redrawn from scratch before shipping.

## Running it

```bash
flutter pub get
flutter run
```

## Suggested next steps

- AI image-generation pipeline (replaces the placeholders).
- Connect photo → `WildEncounter` → `BattleScreen` in the navigation flow.
- Experience/level-up system after each won battle (today the level
  only goes up "conceptually": the logic that awards EXP and calls
  `EvolutionEngine.shouldEvolveNow` still needs to be added).
- UI for choosing which move to forget when a new one is learned
  (today `MovePool.nextMoveToLearn` is ready on the logic side).
- "Real" authentication (email/social) in addition to the anonymous
  one, to retrieve your own Wildkin on a new device.
