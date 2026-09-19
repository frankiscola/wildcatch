-- Renames the base_stats jsonb keys from the old 'insight'/'ward'
-- naming to 'elemental_attack'/'elemental_defense' for any Wildkin
-- captured before that rename. Optional: lib/models/stats.dart
-- already falls back to the old keys if these aren't found, so the
-- app works fine without running this. Run it if you'd rather clean
-- up the stored data than keep relying on the client-side fallback.
update captures
set base_stats = (base_stats - 'insight' - 'ward')
  || jsonb_build_object(
       'elemental_attack', base_stats -> 'insight',
       'elemental_defense', base_stats -> 'ward'
     )
where base_stats ? 'insight' or base_stats ? 'ward';
