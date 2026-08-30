import 'package:flutter/material.dart';
import '../models/creature.dart';
import '../models/move.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pixel_button.dart';
import '../widgets/type_badge.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final Creature creature;

  const ResultScreen({super.key, required this.creature});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showFront = true;

  @override
  Widget build(BuildContext context) {
    final creature = widget.creature;
    final stats = creature.computeStats();

    return Scaffold(
      appBar: AppBar(title: Text(creature.nickname.toUpperCase())),
      body: RouteBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GbaDialogBox(
                  text: 'Congratulazioni! Hai catturato una nuova creatura!',
                  fontSize: 15,
                ),
                const SizedBox(height: 16),
                _SpriteStage(creature: creature, showFront: _showFront),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => setState(() => _showFront = !_showFront),
                  child: _FlipHint(showFront: _showFront),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LevelBadge(level: creature.level),
                    const SizedBox(width: 10),
                    TypeBadgeRow(types: creature.types),
                  ],
                ),
                const SizedBox(height: 14),
                _EvolutionCard(creature: creature),
                const SizedBox(height: 14),
                _StatsCard(stats: stats),
                const SizedBox(height: 14),
                _MovesCard(moves: creature.moves.map((m) => m.move).toList()),
                const SizedBox(height: 14),
                _ContextSummary(creature: creature),
                const SizedBox(height: 20),
                PixelButton(
                  label: 'TORNA AL MENU',
                  background: AppColors.sapphireBlue,
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpriteStage extends StatelessWidget {
  final Creature creature;
  final bool showFront;

  const _SpriteStage({required this.creature, required this.showFront});

  @override
  Widget build(BuildContext context) {
    final spriteUrl = showFront ? creature.frontSpriteUrl : creature.backSpriteUrl;

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.panelCream,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Image.network(
          spriteUrl,
          key: ValueKey(spriteUrl),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(Icons.image_not_supported, size: 48, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

class _FlipHint extends StatelessWidget {
  final bool showFront;
  const _FlipHint({required this.showFront});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.panelCream,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flip, size: 16, color: AppColors.panelBrown),
          const SizedBox(width: 8),
          Text(
            showFront ? 'VISTA BATTAGLIA (RETRO)' : 'VISTA POKEDEX (FRONTE)',
            style: AppFonts.pixelTitle(fontSize: 9, color: AppColors.panelBrown),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final int level;
  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.panelBrown,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        'LV. $level',
        style: AppFonts.pixelTitle(fontSize: 10, color: AppColors.textOnDark),
      ),
    );
  }
}

/// Mostra numero di stadi della linea evolutiva e l'indizio
/// qualitativo sulla prossima evoluzione, senza mai rivelare il
/// livello esatto.
class _EvolutionCard extends StatelessWidget {
  final Creature creature;
  const _EvolutionCard({required this.creature});

  @override
  Widget build(BuildContext context) {
    final plan = creature.evolutionPlan;
    final lineLabel = plan.totalStages == 3
        ? 'Linea evolutiva a 3 stadi (2 evoluzioni possibili)'
        : 'Linea evolutiva a 2 stadi (1 evoluzione possibile)';

    return _Panel(
      title: 'EVOLUZIONE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lineLabel, style: AppFonts.body(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Stadio attuale: ${plan.currentStage}/${plan.totalStages}',
            style: AppFonts.body(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            plan.timingLabel(),
            style: AppFonts.body(fontSize: 16, color: AppColors.rubyRed),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final dynamic stats; // ComputedStats
  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'STATISTICHE',
      child: Column(
        children: [
          _StatBar(label: 'PS', value: stats.maxHp, max: 260, color: AppColors.grassGreen),
          _StatBar(label: 'ATT', value: stats.attack, max: 200, color: AppColors.rubyRed),
          _StatBar(label: 'DIF', value: stats.defense, max: 200, color: AppColors.sapphireBlue),
          _StatBar(label: 'ATT SP', value: stats.spAttack, max: 200, color: const Color(0xFF9C6ADE)),
          _StatBar(label: 'DIF SP', value: stats.spDefense, max: 200, color: const Color(0xFF4FA8A0)),
          _StatBar(label: 'VEL', value: stats.speed, max: 200, color: const Color(0xFFE0A62B)),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;

  const _StatBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: AppFonts.pixelTitle(fontSize: 9)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                children: [
                  Container(height: 14, color: AppColors.dialogBorderOuter.withOpacity(0.12)),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(height: 14, color: color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: AppFonts.body(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovesCard extends StatelessWidget {
  final List<Move> moves;
  const _MovesCard({required this.moves});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'MOSSE',
      child: Column(
        children: moves
            .map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(m.name, style: AppFonts.body(fontSize: 16)),
                      ),
                      Expanded(
                        flex: 2,
                        child: TypeBadge(type: m.type),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text(
                          m.category == MoveCategory.stato
                              ? 'PP ${m.maxPp}'
                              : 'Pot ${m.power} · Prec ${m.accuracy}% · PP ${m.maxPp}',
                          textAlign: TextAlign.right,
                          style: AppFonts.body(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _ContextSummary extends StatelessWidget {
  final Creature creature;
  const _ContextSummary({required this.creature});

  @override
  Widget build(BuildContext context) {
    final ctx = creature.captureContext;
    final chips = <String>[
      '${ctx.temperatureCelsius.round()}°C',
      ctx.weatherCondition,
      ctx.season,
      ctx.isNightTime ? 'notte' : 'giorno',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: chips
          .map((label) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.panelBrown,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  label,
                  style: AppFonts.body(fontSize: 14, color: AppColors.textOnDark),
                ),
              ))
          .toList(),
    );
  }
}

/// Riquadro generico arrotondato, riusato da stats/mosse/evoluzione.
class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.dialogBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppFonts.pixelTitle(fontSize: 11, color: AppColors.rubyRed)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
