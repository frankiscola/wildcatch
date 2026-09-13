import 'dart:math';
import '../models/move.dart';

/// Static table of the moves available for each of the 11 types in
/// the game, split into 3 power "tiers". Tier 1 is what starting
/// moves are drawn from (level 5), tier 2 unlocks around mid-career,
/// tier 3 for well-trained Wildkin.
///
/// NOTE: this is an MVP version with a handful of moves per type,
/// meant to be extended easily by adding entries to the list. In
/// production it's worth moving this table into a Postgres table
/// ('moves') so it can grow without app releases.
///
/// All move names below are original — not translations of any
/// existing game's move names — by design.
class MovePool {
  static const Map<String, List<Move>> _byType = {
    'fire': [
      Move(name: 'Spark Flame', type: 'fire', category: MoveCategory.special, power: 40, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Cinder Bite', type: 'fire', category: MoveCategory.physical, power: 45, accuracy: 95, maxPp: 20, tier: 1),
      Move(name: 'Blaze Jet', type: 'fire', category: MoveCategory.special, power: 90, accuracy: 100, maxPp: 15, tier: 2),
      Move(name: 'Smoldering Curse', type: 'fire', category: MoveCategory.status, power: 0, accuracy: 85, maxPp: 15, tier: 2),
      Move(name: 'Volcanic Burst', type: 'fire', category: MoveCategory.special, power: 120, accuracy: 100, maxPp: 5, tier: 3),
    ],
    'water': [
      Move(name: 'Water Jet', type: 'water', category: MoveCategory.special, power: 40, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Foam Burst', type: 'water', category: MoveCategory.special, power: 40, accuracy: 100, maxPp: 30, tier: 1),
      Move(name: 'Deluge Blast', type: 'water', category: MoveCategory.special, power: 90, accuracy: 90, maxPp: 10, tier: 2),
      Move(name: 'Tidal Wave', type: 'water', category: MoveCategory.special, power: 95, accuracy: 100, maxPp: 15, tier: 2),
      Move(name: 'Maelstrom', type: 'water', category: MoveCategory.special, power: 120, accuracy: 100, maxPp: 5, tier: 3),
    ],
    'grass': [
      Move(name: 'Bramble Snap', type: 'grass', category: MoveCategory.physical, power: 45, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Sap Drain', type: 'grass', category: MoveCategory.special, power: 20, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Thorned Slash', type: 'grass', category: MoveCategory.physical, power: 90, accuracy: 100, maxPp: 15, tier: 2),
      Move(name: 'Radiant Bloom', type: 'grass', category: MoveCategory.special, power: 120, accuracy: 100, maxPp: 10, tier: 3),
    ],
    'electric': [
      Move(name: 'Static Zap', type: 'electric', category: MoveCategory.special, power: 40, accuracy: 100, maxPp: 30, tier: 1),
      Move(name: 'Faint Spark', type: 'electric', category: MoveCategory.special, power: 45, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Voltaic Arc', type: 'electric', category: MoveCategory.special, power: 90, accuracy: 100, maxPp: 15, tier: 2),
      Move(name: 'Storm Bolt', type: 'electric', category: MoveCategory.special, power: 110, accuracy: 70, maxPp: 10, tier: 3),
    ],
    'ice': [
      Move(name: 'Chill Gust', type: 'ice', category: MoveCategory.special, power: 55, accuracy: 95, maxPp: 15, tier: 1),
      Move(name: 'Frost Orb', type: 'ice', category: MoveCategory.special, power: 40, accuracy: 90, maxPp: 25, tier: 1),
      Move(name: 'Glacial Ray', type: 'ice', category: MoveCategory.special, power: 90, accuracy: 100, maxPp: 10, tier: 2),
      Move(name: 'Frost Squall', type: 'ice', category: MoveCategory.special, power: 110, accuracy: 70, maxPp: 5, tier: 3),
    ],
    'poison': [
      Move(name: 'Toxic Soot', type: 'poison', category: MoveCategory.special, power: 40, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Venom Prick', type: 'poison', category: MoveCategory.physical, power: 15, accuracy: 100, maxPp: 35, tier: 1),
      Move(name: 'Corrosive Flame', type: 'poison', category: MoveCategory.special, power: 90, accuracy: 100, maxPp: 10, tier: 2),
      Move(name: 'Acid Surge', type: 'poison', category: MoveCategory.special, power: 100, accuracy: 90, maxPp: 10, tier: 3),
    ],
    'ground': [
      Move(name: 'Pitfall Strike', type: 'ground', category: MoveCategory.physical, power: 45, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Sand Toss', type: 'ground', category: MoveCategory.status, power: 0, accuracy: 100, maxPp: 15, tier: 1),
      Move(name: 'Tremor Quake', type: 'ground', category: MoveCategory.physical, power: 100, accuracy: 100, maxPp: 10, tier: 2),
      Move(name: 'Rising Dust', type: 'ground', category: MoveCategory.physical, power: 90, accuracy: 85, maxPp: 10, tier: 3),
    ],
    'flying': [
      Move(name: 'Wing Jab', type: 'flying', category: MoveCategory.physical, power: 35, accuracy: 100, maxPp: 35, tier: 1),
      Move(name: 'Wind Spiral', type: 'flying', category: MoveCategory.special, power: 40, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Sky Acrobat', type: 'flying', category: MoveCategory.physical, power: 85, accuracy: 100, maxPp: 15, tier: 2),
      Move(name: 'Cyclone Force', type: 'flying', category: MoveCategory.special, power: 110, accuracy: 70, maxPp: 10, tier: 3),
    ],
    'psychic': [
      Move(name: 'Mind Ripple', type: 'psychic', category: MoveCategory.special, power: 50, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Keen Insight', type: 'psychic', category: MoveCategory.special, power: 40, accuracy: 100, maxPp: 20, tier: 1),
      Move(name: 'Mental Shockwave', type: 'psychic', category: MoveCategory.special, power: 80, accuracy: 100, maxPp: 10, tier: 2),
      Move(name: 'Telekinetic Wave', type: 'psychic', category: MoveCategory.special, power: 90, accuracy: 100, maxPp: 10, tier: 3),
    ],
    'rock': [
      Move(name: 'Boulder Toss', type: 'rock', category: MoveCategory.physical, power: 50, accuracy: 90, maxPp: 15, tier: 1),
      Move(name: 'Riverstone Tackle', type: 'rock', category: MoveCategory.physical, power: 45, accuracy: 95, maxPp: 20, tier: 1),
      Move(name: 'Stone Cleaver', type: 'rock', category: MoveCategory.physical, power: 100, accuracy: 80, maxPp: 5, tier: 2),
      Move(name: 'Landslide', type: 'rock', category: MoveCategory.physical, power: 75, accuracy: 90, maxPp: 10, tier: 3),
    ],
    'dark': [
      Move(name: 'Swift Bite', type: 'dark', category: MoveCategory.physical, power: 40, accuracy: 100, maxPp: 25, tier: 1),
      Move(name: 'Shadowed Glare', type: 'dark', category: MoveCategory.status, power: 0, accuracy: 100, maxPp: 30, tier: 1),
      Move(name: 'Sneak Strike', type: 'dark', category: MoveCategory.physical, power: 40, accuracy: 100, maxPp: 30, tier: 2),
      Move(name: 'Grim Maw', type: 'dark', category: MoveCategory.physical, power: 80, accuracy: 100, maxPp: 15, tier: 3),
    ],
  };

  /// The 4 starting moves for a freshly captured Wildkin: always
  /// from tier 1, always matching its type(s).
  List<Move> starterMoves(List<String> types, {Random? random}) {
    final rng = random ?? Random();
    final pool = <Move>[];
    for (final type in types) {
      pool.addAll(_movesOfTier(type, 1));
    }
    // If the pool has fewer than 4 moves, fill in with the first
    // type's tier-1 moves again to reach 4 candidates.
    if (types.isNotEmpty) pool.addAll(_movesOfTier(types.first, 1));

    pool.shuffle(rng);
    final unique = <String, Move>{};
    for (final move in pool) {
      unique[move.name] = move;
      if (unique.length == 4) break;
    }
    return unique.values.toList();
  }

  /// A stronger move to offer as a replacement, unlocked at the
  /// current level. Returns null if there's nothing new to learn at
  /// this level (called every N levels; the cadence is decided by
  /// the caller).
  Move? nextMoveToLearn({
    required List<String> types,
    required int level,
    required List<String> alreadyKnownNames,
    Random? random,
  }) {
    final rng = random ?? Random();
    final targetTier = level >= 60 ? 3 : (level >= 25 ? 2 : 1);

    final candidates = <Move>[];
    for (final type in types) {
      candidates.addAll(
        _movesOfTier(type, targetTier)
            .where((m) => !alreadyKnownNames.contains(m.name)),
      );
    }
    if (candidates.isEmpty) return null;
    candidates.shuffle(rng);
    return candidates.first;
  }

  List<Move> _movesOfTier(String type, int tier) {
    final all = _byType[type.toLowerCase()] ?? const [];
    return all.where((m) => m.tier == tier).toList();
  }
}
