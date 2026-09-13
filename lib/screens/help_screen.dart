import 'package:flutter/material.dart';
import '../models/type_chart.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/type_badge_assets.dart';
import '../widgets/route_background.dart';

/// Help/info menu: an always-available reference on how the game
/// rules work, for anyone who doesn't want to go back through the
/// whole multi-page tutorial just to check one detail (e.g. "how
/// much damage does a Water attack do against a Rock type?").
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HELP')),
      body: RouteBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              _Section(
                icon: Icons.public,
                title: 'How the type is chosen',
                body: 'At capture the Wildkin gets a single type (rarely '
                    'two, ~35% of the time), chosen based on several '
                    'factors of the moment and the place:',
                bullets: [
                  'Temperature: very hot favors Fire/Ground, very '
                      'cold favors Ice.',
                  'Weather: rain → Water, thunderstorm → Electric, snow → '
                      'Ice, fog → Psychic/Poison.',
                  'Biome: sea → Water, mountain → Rock/Ground, forest → '
                      'Grass, city → Electric/Rock, desert → '
                      'Ground/Fire, plain → Grass/Ground.',
                  'Time of day: night favors Dark/Psychic, day favors '
                      'Flying.',
                  'Season: summer → Fire/Ground, winter → Ice, '
                      'spring → Grass, fall → Ground/Dark.',
                ],
              ),
              SizedBox(height: 20),
              _Section(
                icon: Icons.upgrade,
                title: 'Evolution',
                body: 'Every captured Wildkin always starts at the base '
                    'stage, at level 5. At that same moment it\'s decided '
                    '(secretly) how many evolutions it will have:',
                bullets: [
                  '~50% of the time: ONE single evolution, between level '
                      '40 and 50.',
                  '~50% of the time: TWO evolutions, the first between level '
                      '15 and 30, the second between level 55 and 75.',
                  'The exact level is never revealed in advance: the '
                      'Wildkin\'s card only shows a rough hint (e.g. '
                      '"evolves soon" or "evolves late").',
                  'At each evolution the Wildkin gains a second type, '
                      'influenced both by the moment of capture and by the '
                      'weather, place, and time of the evolution itself.',
                ],
              ),
              SizedBox(height: 20),
              _Section(
                icon: Icons.bolt,
                title: 'Levels and moves',
                body: 'You level up by winning battles against other '
                    'photographed animals, up to a maximum of level 100.',
                bullets: [
                  'You start with 4 initial moves, all matching the '
                      'Wildkin\'s type.',
                  'As you level up, stronger moves unlock, which you can '
                      'choose to learn in place of one you already know.',
                  'In battle, the more you weaken a wild animal (low HP), '
                      'the higher the odds of catching it.',
                ],
              ),
              SizedBox(height: 20),
              _TypeChartSection(),
              SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final List<String> bullets;

  const _Section({
    required this.icon,
    required this.title,
    required this.body,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelCream,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.emberRed, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: AppFonts.pixelTitle(
                        fontSize: 16, color: AppColors.panelBrown)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: AppFonts.body(fontSize: 15)),
          const SizedBox(height: 8),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(b, style: AppFonts.body(fontSize: 14))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Effectiveness table for the 11 types, generated from
/// TypeChart.all: one card per type with its weaknesses/resistances/
/// immunities colored, so if the table in type_chart.dart changes
/// this screen updates itself, with no need to keep them in sync by
/// hand.
class _TypeChartSection extends StatelessWidget {
  const _TypeChartSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelCream,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield, color: AppColors.tidalBlue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Type chart',
                  style: AppFonts.pixelTitle(
                      fontSize: 16, color: AppColors.panelBrown),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'For each type: what it\'s weak against (takes 2x), what it '
            'resists (0.5x), and what it\'s immune to (0x). With two '
            'types, the effects multiply together.',
            style: AppFonts.body(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          ...TypeChart.all.map((info) => _TypeMatchupCard(info: info)),
        ],
      ),
    );
  }
}

class _TypeMatchupCard extends StatelessWidget {
  final TypeMatchupInfo info;

  const _TypeMatchupCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: TypeColors.of(info.type).withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TypeBadge(type: info.type),
          const SizedBox(height: 8),
          _MatchupRow(label: 'Weak (2x)', types: info.weakTo, emptyDash: true),
          _MatchupRow(
              label: 'Resists (0.5x)', types: info.resists, emptyDash: true),
          if (info.immuneTo.isNotEmpty)
            _MatchupRow(label: 'Immune', types: info.immuneTo),
        ],
      ),
    );
  }
}

class _MatchupRow extends StatelessWidget {
  final String label;
  final List<String> types;
  final bool emptyDash;

  const _MatchupRow(
      {required this.label, required this.types, this.emptyDash = false});

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty && !emptyDash) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label,
                style: AppFonts.body(fontSize: 12, color: AppColors.textMuted)),
          ),
          Expanded(
            child: types.isEmpty
                ? Text('—',
                    style:
                        AppFonts.body(fontSize: 12, color: AppColors.textMuted))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: types
                        .map((t) => _TypeBadge(type: t, small: true))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  final bool small;

  const _TypeBadge({required this.type, this.small = false});

  @override
  Widget build(BuildContext context) {
    final assetPath = TypeBadgeAssets.of(type);
    final size = small ? 28.0 : 40.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: assetPath != null
              ? Image.asset(assetPath, fit: BoxFit.contain)
              : Container(
                  decoration: BoxDecoration(
                      color: TypeColors.of(type), shape: BoxShape.circle),
                ),
        ),
        SizedBox(width: small ? 5 : 8),
        Text(
          type[0].toUpperCase() + type.substring(1),
          style: AppFonts.body(
            fontSize: small ? 12 : 14,
            color: AppColors.dialogText,
            weight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
