/// Original status effects a move can inflict (see Move.inflictsStatus).
/// Deliberately not a re-skin of the classic burn/paralysis/poison/
/// freeze/sleep set — each one is tied to a mechanic specific to
/// this game (real weather, real time, or the type chart itself).
///
/// NOTE: this is metadata only. battle_engine.dart does not resolve
/// these yet — applying them turn-by-turn is a follow-up task once
/// the core damage formula there is settled.
enum StatusEffect { chilled, toxicFilm, rattled, grounded, waterlogged }

class StatusEffectInfo {
  final String name;
  final String description;
  final bool reactsToRealWeather;
  final bool reactsToRealTime;

  const StatusEffectInfo({
    required this.name,
    required this.description,
    this.reactsToRealWeather = false,
    this.reactsToRealTime = false,
  });
}

extension StatusEffectDetails on StatusEffect {
  static const Map<StatusEffect, StatusEffectInfo> _info = {
    StatusEffect.chilled: StatusEffectInfo(
      name: 'Chilled',
      description: '-30% Speed. Melts away faster if the real weather right now is warm or clear.',
      reactsToRealWeather: true,
    ),
    StatusEffect.toxicFilm: StatusEffectInfo(
      name: 'Toxic Film',
      description: 'Growing damage each turn. Clears faster on a Wildkin with the Sun-Baked imprint.',
    ),
    StatusEffect.rattled: StatusEffectInfo(
      name: 'Rattled',
      description: "Chance to flinch and skip a turn. More likely if it's genuinely night right now.",
      reactsToRealTime: true,
    ),
    StatusEffect.grounded: StatusEffectInfo(
      name: 'Grounded',
      description: "Removes a Flying-type's immunity to Ground moves for the rest of the battle — "
          'the one deliberate exception to the type chart, and only from this status.',
    ),
    StatusEffect.waterlogged: StatusEffectInfo(
      name: 'Waterlogged',
      description: "-1 extra PP on the target's next move — weighed down, slow to react.",
    ),
  };

  StatusEffectInfo get info => _info[this]!;

  static StatusEffect? byKey(String key) {
    switch (key) {
      case 'chilled':
        return StatusEffect.chilled;
      case 'toxic_film':
        return StatusEffect.toxicFilm;
      case 'rattled':
        return StatusEffect.rattled;
      case 'grounded':
        return StatusEffect.grounded;
      case 'waterlogged':
        return StatusEffect.waterlogged;
      default:
        return null;
    }
  }
}
