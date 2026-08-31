# Wildcatch — scaffold Flutter

Scaffold di partenza per l'app: fotografa un animale, ottieni una
creatura in stile pixel-art (gen 3/4) con sprite fronte/retro, livelli,
mosse, statistiche ed evoluzioni — il cui tipo dipende da meteo,
posizione GPS e ora della cattura (e, alla prima evoluzione, anche
del momento dell'evoluzione stessa).

## Cosa c'è già

### UI
Stile Pokemon Ruby/Sapphire/Emerald (dialog box, pulsanti pixel, badge
tipo, pokeball animata, barre statistiche/PS) — `lib/widgets/`, `lib/theme/`.

### Flusso di gioco lato client
- **Cattura**: foto → GPS/meteo → upload → generazione → reveal
  (`lib/providers/capture_flow_provider.dart`).
- **Battaglia**: contro una creatura selvatica appena fotografata,
  con possibilità di indebolirla prima di tentare la cattura
  (`lib/screens/battle_screen.dart`, `lib/services/battle_engine.dart`).

### Motori di gioco (`lib/services/`)
- `typing_engine.dart` — assegna 1+ tipi in base a meteo/stagione/bioma/ora.
- `stats_engine.dart` — genera le 6 statistiche base (HP, Att, Dif,
  Att Sp, Dif Sp, Vel) con un piccolo bias tematico per tipo.
- `movepool.dart` — tabella mosse per tipo (potenza/precisione/PP),
  4 mosse iniziali al tier 1, mosse più forti sbloccabili ai tier 2/3.
- `evolution_engine.dart` — decide se una creatura avrà 1 o 2
  evoluzioni future, i livelli casuali a cui scattano (nascosti al
  giocatore, che vede solo un indizio qualitativo), e determina il
  secondo tipo alla prima evoluzione combinando il contesto di
  cattura con quello del momento esatto dell'evoluzione.
- `battle_engine.dart` — risoluzione danno semplificata e probabilità
  di cattura in stile classico (più bassi sono gli HP del selvatico,
  più alta la probabilità).

### Modelli (`lib/models/`)
`creature.dart` (ora con livello, exp, HP correnti, statistiche base,
mosse, piano evolutivo, contesto di cattura ED evoluzione),
`move.dart`, `stats.dart`, `evolution_plan.dart`, `wild_encounter.dart`.

## Le regole di progressione implementate

- **Livello di cattura**: sempre 5, sempre forma base (vedi
  `EvolutionEngine.createInitialPlan`).
- **Linea evolutiva**: 50% delle catture ha 2 stadi totali (1 sola
  evoluzione), 50% ne ha 3 (2 evoluzioni) — soglia facilmente
  regolabile in `evolution_engine.dart` se vuoi pesare diversamente.
- **Livelli di evoluzione** (mai mostrati per intero al giocatore):
  - linee a 3 stadi: primo salto tra livello 15 e 30, secondo salto
    tra 30 e 50 (garantito sempre dopo il primo);
  - linee a 2 stadi: unico salto tra livello 30 e 50.
- **Indizio, non numero**: `EvolutionPlan.timingLabel()` restituisce
  "presto / nella media / tardi" in base a dove cade il livello
  generato nel range possibile, senza mai rivelarlo.
- **Secondo tipo**: assegnato solo alla prima evoluzione, combinando
  il motore di tipizzazione applicato sia al contesto di cattura sia
  a quello di evoluzione (pesato leggermente di più) — vedi
  `EvolutionEngine.determineSecondType`.
- **Mosse**: 4 alla cattura (tier 1, coerenti col tipo), sostituibili
  con mosse più forti (tier 2 da livello ~25, tier 3 da livello ~60).
  La UI per "scegliere quale mossa dimenticare" quando se ne impara
  una nuova va aggiunta (oggi `MovePool.nextMoveToLearn` restituisce
  solo il candidato, la sostituzione la decide il chiamante).
- **Cattura più facile se indebolito**: `BattleEngine.catchProbability`
  usa la stessa logica della formula classica (rapporto HP
  correnti/massimi del selvatico).

## Backend Supabase (già pronto in `supabase/`)

```
supabase/
  migrations/0001_init.sql          # tabelle, RLS, bucket storage
  functions/
    _shared/                        # porting TS dei motori Dart
      typing_engine.ts
      stats_engine.ts
      movepool.ts
      evolution.ts
      cors.ts
    generate-creature/index.ts      # orchestratore della cattura
```

`generate-creature` fa esattamente quello che faceva la simulazione
locale: calcola tipo, statistiche, mosse iniziali e piano evolutivo,
salva la riga in `captures` rispettando le policy RLS (l'utente può
scrivere solo le proprie righe) e restituisce il JSON che
`Creature.fromJson` si aspetta già lato Flutter — non serve toccare
altro codice Dart.

### Deploy

```bash
npm install -g supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF

supabase db push                          # crea tabelle, RLS, bucket
supabase functions deploy generate-creature
```

Poi in `lib/services/supabase_service.dart` sostituisci
`YOUR_PROJECT_REF` e `YOUR_SUPABASE_ANON_KEY` con i valori reali
(dashboard → Settings → API).

### Sign-in anonimo (necessario)

`generate-creature` richiede un utente autenticato (le policy RLS si
basano su `auth.uid()`). `main.dart` fa già il sign-in anonimo in
automatico all'avvio — l'unica cosa da fare è abilitarlo nella
dashboard: **Authentication → Providers → Anonymous Sign-Ins**.

### Verifica rapida da terminale

```bash
supabase functions invoke generate-creature --data '{
  "original_photo_url": "https://example.com/test.jpg",
  "context": {
    "captured_at": "2026-08-30T14:00:00.000Z",
    "latitude": 41.9,
    "longitude": 12.5,
    "elevation_meters": 20,
    "biome": "cittaUrbana",
    "weather_condition": "clear",
    "temperature_celsius": 32,
    "humidity_percent": 40,
    "wind_speed_kmh": 5,
    "is_night_time": false,
    "season": "estate"
  }
}'
```

Con questi valori (estate, 32°C, città) dovresti vedere una creatura
con buone probabilità di tipo fuoco/terra/acciaio/normale — un buon
modo per confermare che il motore di tipizzazione è stato portato
correttamente in TypeScript.

## Cosa manca ancora

1. **Generazione immagini reale**: oggi `front_sprite_url` e
   `back_sprite_url` sono placeholder (= la foto originale). Il punto
   esatto dove agganciare il servizio AI è commentato con TODO in
   `supabase/functions/generate-creature/index.ts`.

2. **Edge function `evolve-creature`** (non ancora scritta): stesso
   pattern di `generate-creature`, ma userà anche
   `determineSecondType` (da portare da `evolution_engine.dart`) e
   riceverà il contesto ATTUALE oltre all'id della creatura.

3. **Edge function `resolve-wild-encounter`** (non ancora scritta,
   opzionale se si preferisce generare l'incontro lato client): serve
   per collegare `BattleScreen` al resto del flusso.

4. **Permessi piattaforma**:
   - Android (`android/app/src/main/AndroidManifest.xml`): `CAMERA`,
     `ACCESS_FINE_LOCATION`, `INTERNET`.
   - iOS (`ios/Runner/Info.plist`): `NSCameraUsageDescription`,
     `NSLocationWhenInUseUsageDescription`,
     `NSPhotoLibraryUsageDescription`.

## Avvio

```bash
flutter pub get
flutter run
```

## Prossimi passi suggeriti

- Pipeline di generazione immagini AI (sostituisce i placeholder).
- Collegare foto → `WildEncounter` → `BattleScreen` nel flusso di navigazione.
- Sistema di esperienza/level-up dopo ogni battaglia vinta (oggi il
  livello sale solo "concettualmente": va aggiunta la logica che
  assegna EXP e richiama `EvolutionEngine.shouldEvolveNow`).
- UI per scegliere quale mossa dimenticare quando se ne impara una
  nuova (oggi `MovePool.nextMoveToLearn` è pronto lato logica).
- Efficacia di tipo (super efficace / poco efficace) nel `battle_engine.dart`.
- Autenticazione "vera" (email/social) in aggiunta a quella anonima,
  per recuperare i propri Pokemon su un nuovo dispositivo.
