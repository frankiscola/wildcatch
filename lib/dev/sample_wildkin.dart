import '../models/capture_context.dart';
import '../models/evolution_plan.dart';
import '../models/move.dart';
import '../models/stats.dart';
import '../models/wildkin.dart';

/// Local-only sample data for previewing TeamScreen/ResultScreen
/// without a real Supabase project. Sprite paths point at
/// dev_preview_assets/ (project root) and are picked up by
/// SpriteImage as local files, not network URLs.
///
/// NOT wired into the real app anywhere — only used by
/// lib/dev/team_preview_main.dart. Never reference this file from
/// production code (screens, providers, services).
List<Wildkin> buildSampleWildkin() {
  final captureContext = CaptureContext(
    capturedAt: DateTime(2026, 1, 10, 22, 30),
    latitude: 45.46,
    longitude: 9.19,
    weatherCondition: 'clear',
    temperatureCelsius: 2,
    humidityPercent: 60,
    windSpeedKmh: 8,
    biome: Biome.urbanCity,
  );

  final coastContext = CaptureContext(
    capturedAt: DateTime(2026, 7, 4, 15, 0),
    latitude: 41.9,
    longitude: 12.5,
    weatherCondition: 'clear',
    temperatureCelsius: 31,
    humidityPercent: 55,
    windSpeedKmh: 12,
    biome: Biome.sea,
  );

  final forestContext = CaptureContext(
    capturedAt: DateTime(2026, 4, 2, 9, 0),
    latitude: 44.5,
    longitude: 11.3,
    weatherCondition: 'rain',
    temperatureCelsius: 14,
    humidityPercent: 80,
    windSpeedKmh: 5,
    biome: Biome.forest,
  );

  final cat = Wildkin(
    id: 'sample-cat',
    nickname: 'Frostwhisk',
    originalPhotoUrl: 'dev_preview_assets/cat.webp',
    frontSpriteUrl: 'dev_preview_assets/cat.webp',
    backSpriteUrl: 'dev_preview_assets/cat_back.webp',
    types: const ['ice', 'dark'],
    level: 35,
    currentExp: 0,
    currentHp: 58,
    baseStats: const BaseStats(hp: 62, attack: 55, defense: 50, elementalAttack: 60, elementalDefense: 58, speed: 70),
    moves: const [
      LearnedMove(
        move: Move(name: 'Glacial Ray', type: 'ice', category: MoveCategory.special, power: 90, accuracy: 100, maxPp: 10, tier: 2),
        currentPp: 10,
      ),
      LearnedMove(
        move: Move(name: 'Frost Orb', type: 'ice', category: MoveCategory.special, power: 40, accuracy: 90, maxPp: 25, tier: 1),
        currentPp: 25,
      ),
      LearnedMove(
        move: Move(name: 'Sneak Strike', type: 'dark', category: MoveCategory.physical, power: 40, accuracy: 100, maxPp: 30, tier: 2),
        currentPp: 30,
      ),
      LearnedMove(
        move: Move(name: 'Shadowed Glare', type: 'dark', category: MoveCategory.status, power: 0, accuracy: 100, maxPp: 30, tier: 1),
        currentPp: 30,
      ),
    ],
    evolutionPlan: const EvolutionPlan(totalStages: 2, currentStage: 2),
    captureContext: captureContext,
    evolutionContext: coastContext,
    speciesHint: 'cat',
    isInTeam: true,
  );

  final parrot = Wildkin(
    id: 'sample-parrot',
    nickname: 'Squallbeak',
    originalPhotoUrl: 'dev_preview_assets/parrot.webp',
    frontSpriteUrl: 'dev_preview_assets/parrot.webp',
    backSpriteUrl: 'dev_preview_assets/parrot_back.webp',
    types: const ['flying'],
    level: 14,
    currentExp: 0,
    currentHp: 34,
    baseStats: const BaseStats(hp: 45, attack: 40, defense: 35, elementalAttack: 45, elementalDefense: 40, speed: 65),
    moves: const [
      LearnedMove(
        move: Move(name: 'Wing Jab', type: 'flying', category: MoveCategory.physical, power: 35, accuracy: 100, maxPp: 35, tier: 1),
        currentPp: 35,
      ),
      LearnedMove(
        move: Move(name: 'Wind Spiral', type: 'flying', category: MoveCategory.special, power: 40, accuracy: 100, maxPp: 25, tier: 1),
        currentPp: 25,
      ),
      LearnedMove(
        move: Move(name: 'Sky Acrobat', type: 'flying', category: MoveCategory.physical, power: 85, accuracy: 100, maxPp: 15, tier: 2),
        currentPp: 15,
      ),
      LearnedMove(
        move: Move(name: 'Cyclone Force', type: 'flying', category: MoveCategory.special, power: 110, accuracy: 70, maxPp: 10, tier: 3),
        currentPp: 10,
      ),
    ],
    evolutionPlan: const EvolutionPlan(totalStages: 2, currentStage: 1, nextEvolutionLevel: 42),
    captureContext: coastContext,
    speciesHint: 'parrot',
    isInTeam: true,
  );

  final worm = Wildkin(
    id: 'sample-worm',
    nickname: 'Mudnip',
    originalPhotoUrl: 'dev_preview_assets/worm.webp',
    frontSpriteUrl: 'dev_preview_assets/worm.webp',
    backSpriteUrl: 'dev_preview_assets/worm_back.webp',
    types: const ['poison'],
    level: 8,
    currentExp: 0,
    currentHp: 22,
    baseStats: const BaseStats(hp: 40, attack: 35, defense: 45, elementalAttack: 30, elementalDefense: 35, speed: 25),
    moves: const [
      LearnedMove(
        move: Move(name: 'Toxic Soot', type: 'poison', category: MoveCategory.special, power: 40, accuracy: 100, maxPp: 25, tier: 1),
        currentPp: 25,
      ),
      LearnedMove(
        move: Move(name: 'Venom Prick', type: 'poison', category: MoveCategory.physical, power: 15, accuracy: 100, maxPp: 35, tier: 1),
        currentPp: 35,
      ),
    ],
    evolutionPlan: const EvolutionPlan(totalStages: 3, currentStage: 1, nextEvolutionLevel: 18, secondEvolutionLevel: 47),
    captureContext: forestContext,
    speciesHint: 'grub',
    isInTeam: false,
  );

  return [cat, parrot, worm];
}
