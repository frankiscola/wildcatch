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

## Cosa manca (lato tuo)

1. **Progetto Supabase**: credenziali in `lib/services/supabase_service.dart`.

2. **Bucket storage** `captures` (public per l'MVP).

3. **Schema tabelle** — versione aggiornata con tutti i nuovi campi:

   ```sql
   create table captures (
     id uuid primary key default gen_random_uuid(),
     user_id uuid references auth.users not null,
     nickname text default '???',
     original_photo_url text not null,
     front_sprite_url text,
     back_sprite_url text,
     assigned_type text[] not null,
     species_hint text,

     level int not null default 5,
     current_exp int not null default 0,
     current_hp int not null,

     base_stats jsonb not null,       -- {hp, attack, defense, sp_attack, sp_defense, speed}
     moves jsonb not null,            -- array di {move: {...}, current_pp}
     evolution_plan jsonb not null,   -- {total_stages, current_stage, next_evolution_level, second_evolution_level}

     captured_at timestamptz not null,
     latitude double precision not null,
     longitude double precision not null,
     elevation_m double precision,
     weather_condition text not null,
     temperature_c double precision not null,
     humidity_percent double precision,
     wind_speed_kmh double precision,

     -- valorizzate solo dopo la prima evoluzione
     evolution_context jsonb
   );

   create table battle_logs (
     id uuid primary key default gen_random_uuid(),
     user_id uuid references auth.users not null,
     creature_id uuid references captures not null,
     wild_snapshot jsonb not null,
     outcome text not null,           -- 'caught' | 'fled' | 'fainted_own'
     created_at timestamptz not null default now()
   );
   ```

4. **Edge function `generate-creature`** (cattura): calcola il primo
   (e unico, alla cattura) tipo con `typing_engine.dart`, genera le
   statistiche base con `stats_engine.dart`, le 4 mosse iniziali con
   `movepool.dart`, il piano evolutivo con `evolution_engine.dart`,
   chiama il servizio di generazione immagini per fronte/retro, salva
   la riga e restituisce il JSON atteso da `Creature.fromJson`.

5. **Edge function `evolve-creature`** (nuova): riceve l'id della
   creatura + il contesto attuale (meteo/GPS/ora del momento
   dell'evoluzione), verifica che il livello abbia raggiunto la
   soglia, chiama `EvolutionEngine.determineSecondType` con ENTRAMBI
   i contesti, rigenera le sprite fronte/retro con il nuovo aspetto,
   propone eventualmente una mossa più forte da imparare, e aggiorna
   la riga.

6. **Edge function `resolve-wild-encounter`** (nuova, opzionale se si
   preferisce tenere la battaglia lato client): genera una
   `WildEncounter` a partire da una foto, con livello/tipo/statistiche
   coerenti col contesto attuale, da passare a `BattleScreen`.

7. **Permessi piattaforma**: invariati rispetto alla prima versione
   (fotocamera, posizione, storage).

## Avvio

```bash
flutter pub get
flutter run
```

## Prossimi passi suggeriti

- Sistema di esperienza/level-up dopo ogni battaglia vinta (oggi il
  livello sale solo "concettualmente": va aggiunta la logica che
  assegna EXP e richiama `EvolutionEngine.shouldEvolveNow` dopo ogni
  incremento di livello).
- UI per scegliere quale mossa dimenticare quando se ne impara una
  nuova (oggi `MovePool.nextMoveToLearn` è pronto lato logica).
- Efficacia di tipo (super efficace / poco efficace) nel
  `battle_engine.dart`, oggi il danno non la considera.
- Autenticazione reale al posto del placeholder `anonymous-user`.
