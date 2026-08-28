# Wildcatch — scaffold Flutter

Scaffold di partenza per l'app: fotografa un animale, ottieni una
creatura in stile pixel-art (gen 3/4) con sprite fronte/retro, il
cui tipo dipende da meteo, posizione GPS e ora della cattura.

## Cosa c'è già

- **UI completa** in stile Pokemon Ruby/Sapphire/Emerald (dialog box,
  pulsanti pixel, badge tipo, pokeball animata) — vedi `lib/widgets/`
  e `lib/theme/`.
- **Flusso di cattura completo lato client**: scatto foto → raccolta
  GPS/meteo → upload → chiamata alla edge function → reveal risultato
  (`lib/providers/capture_flow_provider.dart`).
- **Motore di tipizzazione** basato su meteo/stagione/bioma/ora,
  pronto per essere duplicato lato server (`lib/services/typing_engine.dart`).
- **Servizi meteo e GPS** già funzionanti (Open-Meteo e Open-Elevation
  sono entrambi gratuiti, nessuna API key richiesta).

## Cosa manca (lato tuo)

1. **Progetto Supabase**: crea un progetto su supabase.com, poi in
   `lib/services/supabase_service.dart` sostituisci `YOUR_PROJECT_REF`
   e `YOUR_SUPABASE_ANON_KEY` con i tuoi valori reali (Settings → API).

2. **Bucket storage** chiamato `captures` (Storage → New bucket, "public"
   va bene per l'MVP).

3. **Tabella `captures`** in Postgres, con schema tipo:
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
     captured_at timestamptz not null,
     latitude double precision not null,
     longitude double precision not null,
     elevation_m double precision,
     weather_condition text not null,
     temperature_c double precision not null,
     humidity_percent double precision,
     wind_speed_kmh double precision
   );
   ```

4. **Edge function `generate-creature`**: riceve `original_photo_url`
   e `context` (vedi `CaptureContext.toJson()`), calcola il tipo
   (porta lì la logica di `typing_engine.dart`), chiama il servizio
   di generazione immagini (es. Replicate/Fal.ai con un modello
   img2img in stile pixel-art) per fronte e retro, salva la riga in
   `captures` e restituisce il JSON atteso da `Creature.fromJson`.

5. **Permessi piattaforma**:
   - Android (`android/app/src/main/AndroidManifest.xml`): permessi
     `CAMERA`, `ACCESS_FINE_LOCATION`, `INTERNET`.
   - iOS (`ios/Runner/Info.plist`): `NSCameraUsageDescription`,
     `NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryUsageDescription`.

## Avvio

```bash
flutter pub get
flutter run
```

Finché non colleghi Supabase, l'app si avvia ma il flusso di cattura
fallirà all'upload — utile comunque per vedere/rifinire la UI
navigando tra `HomeScreen` e `CaptureScreen`.

## Idee per i prossimi passi

- Autenticazione (anche solo anonima, `supabase.auth.signInAnonymously()`)
  per far funzionare `userId` reale invece del placeholder.
- Sistema amici/battaglie (menzionato nella tua idea originale) — un
  buon punto di partenza è una tabella `friendships` + una edge
  function che confronta due creature.
- Distanza dalla costa reale per il rilevamento "mare" (dataset
  costiero o Overpass API), oggi è un placeholder in
  `capture_flow_provider.dart`.
