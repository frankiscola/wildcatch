/// A logged wild encounter from `battle_logs` — used only to show
/// Wildkin that were fought but never caught in the Field Journal.
/// Deliberately minimal (just enough to render a "seen" card): the
/// full battle mechanics never need to be reconstructed from this.
class BattleLogEntry {
  final String id;
  final String photoUrl;
  final List<String> types;
  final int level;
  final String outcome; // 'won' | 'catch_failed' | 'fled' | 'lost'
  final DateTime createdAt;

  /// Real-world animal this wild encounter looked like, if the
  /// snapshot happens to carry one. NOTE: as of today,
  /// WildEncounterGenerator doesn't attach a species hint to wild
  /// encounters, so this will normally be null for "seen" entries —
  /// kept nullable and read defensively so the Journal's species
  /// filter already works the day that's added, without another
  /// migration of this model.
  final String? speciesHint;

  const BattleLogEntry({
    required this.id,
    required this.photoUrl,
    required this.types,
    required this.level,
    required this.outcome,
    required this.createdAt,
    this.speciesHint,
  });

  factory BattleLogEntry.fromJson(Map<String, dynamic> json) {
    final snapshot = json['wild_snapshot'] as Map<String, dynamic>;
    return BattleLogEntry(
      id: json['id'] as String,
      photoUrl: snapshot['photo_url'] as String,
      types: List<String>.from(snapshot['types'] as List),
      level: snapshot['level'] as int,
      outcome: json['outcome'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      speciesHint: snapshot['species_hint'] as String?,
    );
  }
}
