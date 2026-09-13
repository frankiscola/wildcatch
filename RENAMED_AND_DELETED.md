# Applying this patch

This zip contains only the files that changed or are new, keeping the
same folder structure as the repo, so you can extract it directly on
top of your project. A zip can't express file deletions/renames on
its own, so do these manually first:

## Delete (replaced by a renamed file included here)
- `lib/models/creature.dart` → replaced by `lib/models/wildkin.dart`
- `lib/screens/pokedex_screen.dart` → replaced by `lib/screens/field_journal_screen.dart`
- `lib/widgets/pokeball_spinner.dart` → replaced by `lib/widgets/capture_spinner.dart`
- `supabase/functions/generate-creature/` (whole folder) → replaced by `supabase/functions/generate-wildkin/`
- `lib/services/battle_screen.dart` — this was a **stray duplicate** of `lib/screens/battle_screen.dart` in the wrong folder (services instead of screens). I merged its one extra feature (the type-effectiveness message) into the correct file and dropped the duplicate. Delete this one.
- `android/app/src/main/kotlin/com/quince/wildcatch/` (whole folder) → replaced by `android/app/src/main/kotlin/com/quince/wildkin/`

## Then extract this zip on top of the repo
It will add/overwrite exactly the 60 files listed in my message.

## Not included here (flagged, not fixed)
- `assets/type_badges/*.png` — these badge icons are still visually
  close to an existing game's official badge style and should be
  redrawn as original artwork. I didn't touch the image files
  themselves, only the code/colors referencing them.
