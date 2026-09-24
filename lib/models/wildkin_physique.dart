import '../models/stats.dart';

/// XS / S / M / L / XL, derived from weight. Purely cosmetic/flavor
/// today; ScalesWithTargetWeight moves and any future "large target
/// is easier to hit / small target dodges more" rule read the
/// weight number directly rather than this bucket.
enum WildkinSize { xs, s, m, l, xl }

extension WildkinSizeLabel on WildkinSize {
  String get label => switch (this) {
        WildkinSize.xs => 'XS',
        WildkinSize.s => 'S',
        WildkinSize.m => 'M',
        WildkinSize.l => 'L',
        WildkinSize.xl => 'XL',
      };
}

/// Weight (kg) and size, derived from a Wildkin's base stats and
/// evolution stage — never stored, always recomputed, so it can
/// never drift out of sync with the stats it's based on.
class WildkinPhysique {
  final double weightKg;
  final WildkinSize size;

  const WildkinPhysique({required this.weightKg, required this.size});

  /// [currentStage] is 1-indexed (1 = base form). Weight grows with
  /// bulk (HP + Defense) and gets a flat multiplier per evolution
  /// stage, plus a little deterministic variation seeded from the
  /// stats themselves so two same-species Wildkin don't weigh
  /// exactly the same.
  factory WildkinPhysique.fromStats(BaseStats baseStats, {required int currentStage}) {
    final bulk = baseStats.hp + baseStats.defense;
    final stageMultiplier = 1.0 + (currentStage - 1) * 0.6;
    final variation = 0.9 + ((baseStats.hp * 7 + baseStats.defense * 13) % 21) / 100;
    final weight = (bulk * 0.35 * stageMultiplier * variation).clamp(0.5, 400.0);

    return WildkinPhysique(weightKg: weight, size: _sizeFor(weight));
  }

  static WildkinSize _sizeFor(double weightKg) {
    if (weightKg < 5) return WildkinSize.xs;
    if (weightKg < 15) return WildkinSize.s;
    if (weightKg < 40) return WildkinSize.m;
    if (weightKg < 90) return WildkinSize.l;
    return WildkinSize.xl;
  }
}
