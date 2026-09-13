import 'package:flutter/material.dart';
import '../models/wildkin.dart';
import '../models/move.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pixel_button.dart';
import '../widgets/type_badge.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final Wildkin wildkin;

  const ResultScreen({super.key, required this.wildkin});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showFront = true;

  @override
  Widget build(BuildContext context) {
    final wildkin = widget.wildkin;
    final stats = wildkin.computeStats();

    return Scaffold(
      appBar: AppBar(title: Text(wildkin.nickname.toUpperCase())),
      body: RouteBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GbaDialogBox(
                  text: 'Congratulations! You caught a new Wildkin!',
                  fontSize: 15,
                ),
                const SizedBox(height: 16),
                _SpriteStage(wildkin: wildkin, showFront: _showFront),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => setState(() => _showFront = !_showFront),
                  child: _FlipHint(showFront: _showFront),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LevelBadge(level: wildkin.level),
                    const SizedBox(width: 10),
                    TypeBadgeRow(types: wildkin.types),
                  ],
                ),
                const SizedBox(height: 14),
                _EvolutionCard(wildkin: wildkin),
                const SizedBox(height: 14),
                _StatsCard(stats: stats),
                const SizedBox(height: 14),
                _MovesCard(moves: wildkin.moves.map((m) => m.move).toList()),
                const SizedBox(height: 14),
                _ContextSummary(wildkin: wildkin),
                const SizedBox(height: 20),
                PixelButton(
                  label: 'BACK TO MENU',
                  background: AppColors.tidalBlue,
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
  final Wildkin wildkin;
  final bool showFront;

  const _SpriteStage({required this.wildkin, required this.showFront});

  @override
  Widget build(BuildContext context) {
    final spriteUrl = showFront ? wildkin.frontSpriteUrl : wildkin.backSpriteUrl;

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
            showFront ? 'BATTLE VIEW (BACK)' : 'JOURNAL VIEW (FRONT)',
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

/// Shows the number of stages in the evolutionary line and the
/// qualitative hint about the next evolution, without ever revealing
/// the exact level.
class _EvolutionCard extends StatelessWidget {
  final Wildkin wildkin;
  const _EvolutionCard({required this.wildkin});

  @override
  Widget build(BuildContext context) {
    final plan = wildkin.evolutionPlan;
    final lineLabel = plan.totalStages == 3
        ? '3-stage evolutionary line (2 possible evolutions)'
        : '2-stage evolutionary line (1 possible evolution)';

    return _Panel(
      title: 'EVOLUTION',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lineLabel, style: AppFonts.body(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Current stage: ${plan.currentStage}/${plan.totalStages}',
            style: AppFonts.body(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            plan.timingLabel(),
            style: AppFonts.body(fontSize: 16, color: AppColors.emberRed),
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
      title: 'STATS',
      child: Column(
        children: [
          _StatBar(label: 'HP', value: stats.maxHp, max: 260, color: AppColors.grassGreen),
          _StatBar(label: 'ATK', value: stats.attack, max: 200, color: AppColors.emberRed),
          _StatBar(label: 'DEF', value: stats.defense, max: 200, color: AppColors.tidalBlue),
          _StatBar(label: 'INSIGHT', value: stats.insight, max: 200, color: const Color(0xFF9C6ADE)),
          _StatBar(label: 'WARD', value: stats.ward, max: 200, color: const Color(0xFF4FA8A0)),
          _StatBar(label: 'SPEED', value: stats.speed, max: 200, color: const Color(0xFFE0A62B)),
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
      title: 'MOVES',
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
                          m.category == MoveCategory.status
                              ? 'PP ${m.maxPp}'
                              : 'Pow ${m.power} · Acc ${m.accuracy}% · PP ${m.maxPp}',
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
  final Wildkin wildkin;
  const _ContextSummary({required this.wildkin});

  @override
  Widget build(BuildContext context) {
    final ctx = wildkin.captureContext;
    final chips = <String>[
      '${ctx.temperatureCelsius.round()}°C',
      ctx.weatherCondition,
      ctx.season,
      ctx.isNightTime ? 'night' : 'day',
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

/// Generic rounded panel, reused by stats/moves/evolution.
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
          Text(title, style: AppFonts.pixelTitle(fontSize: 11, color: AppColors.emberRed)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
