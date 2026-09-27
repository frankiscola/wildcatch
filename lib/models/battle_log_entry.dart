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

  const BattleLogEntry({
    required this.id,
    required this.photoUrl,
    required this.types,
    required this.level,
    required this.outcome,
    required this.createdAt,
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
    );
  }
}
