// LOCAL TESTING ONLY — never referenced by the real app (main.dart).
// Skips the camera/GPS/weather pipeline and fabricates a
// CaptureContext by hand, then generates a wild encounter from it
// with the REAL WildEncounterGenerator and hands off to the REAL
// WildkinPickerScreen -> BattleScreen -> BattleEngine. Nothing about
// the actual battle is mocked — only the "taking a photo" step is
// skipped, so this exercises the real damage formula, real type
// effectiveness, and real capture-probability math.
//
// Hits your REAL Supabase project (reads your real captured
// Wildkin) — this is not the offline lib/dev/team_preview_main.dart
// harness. Run from the project root:
//   flutter run -t lib/dev/battle_preview_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/capture_context.dart';
import '../models/wild_encounter.dart';
import '../screens/wildkin_picker_screen.dart';
import '../services/supabase_service.dart';
import '../services/wild_encounter_generator.dart';
import '../theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  final auth = Supabase.instance.client.auth;
  if (auth.currentSession == null) {
    await auth.signInAnonymously();
  }

  runApp(const ProviderScope(child: _BattlePreviewApp()));
}

class _BattlePreviewApp extends StatelessWidget {
  const _BattlePreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wildkin — Battle preview',
      theme: AppTheme.light,
      home: const _PresetPickerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// A handful of hand-picked capture contexts, covering different
/// weather/biome/time combos so you can see different wild types
/// come up without needing to actually be in those conditions.
class _Preset {
  final String label;
  final CaptureContext context;
  const _Preset(this.label, this.context);
}

final _presets = [
  _Preset(
    'Sunny city, noon',
    CaptureContext(
      capturedAt: DateTime(2026, 7, 15, 13, 0),
      latitude: 45.46, longitude: 9.19,
      weatherCondition: 'clear', temperatureCelsius: 30,
      humidityPercent: 45, windSpeedKmh: 6,
      biome: Biome.urbanCity,
    ),
  ),
  _Preset(
    'Rainy forest, dusk',
    CaptureContext(
      capturedAt: DateTime(2026, 4, 10, 19, 30),
      latitude: 44.5, longitude: 11.3,
      weatherCondition: 'rain', temperatureCelsius: 14,
      humidityPercent: 85, windSpeedKmh: 10,
      biome: Biome.forest,
    ),
  ),
  _Preset(
    'Snowy mountain, dawn',
    CaptureContext(
      capturedAt: DateTime(2026, 1, 20, 6, 30),
      latitude: 46.5, longitude: 10.9,
      weatherCondition: 'snow', temperatureCelsius: -5,
      humidityPercent: 70, windSpeedKmh: 15,
      biome: Biome.mountain,
    ),
  ),
  _Preset(
    'Clear desert, midnight',
    CaptureContext(
      capturedAt: DateTime(2026, 8, 3, 0, 15),
      latitude: 31.6, longitude: 34.8,
      weatherCondition: 'clear', temperatureCelsius: 22,
      humidityPercent: 20, windSpeedKmh: 4,
      biome: Biome.desert,
    ),
  ),
  _Preset(
    'Calm sea, morning',
    CaptureContext(
      capturedAt: DateTime(2026, 6, 1, 9, 0),
      latitude: 41.0, longitude: 9.3,
      weatherCondition: 'clear', temperatureCelsius: 24,
      humidityPercent: 60, windSpeedKmh: 8,
      biome: Biome.sea,
    ),
  ),
];

class _PresetPickerScreen extends StatelessWidget {
  const _PresetPickerScreen();

  void _startBattle(BuildContext context, CaptureContext ctx) {
    final WildEncounter encounter = WildEncounterGenerator().generate(ctx);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WildkinPickerScreen(wildEncounter: encounter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Battle preview — pick a scenario')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Each button fabricates a wild encounter from a hand-picked '
              'context (no camera/GPS involved), then hands off to the '
              'real picker + battle screen with your real Wildkin.',
            ),
            const SizedBox(height: 16),
            for (final preset in _presets)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  onPressed: () => _startBattle(context, preset.context),
                  child: Text(preset.label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
