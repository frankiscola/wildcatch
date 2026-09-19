import 'package:flutter/material.dart';
import '../models/wildkin.dart';
import '../models/capture_context.dart';
import '../models/move.dart';
import '../models/type_chart.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pixel_button.dart';
import '../widgets/type_badge.dart';
import '../widgets/sprite_image.dart';
import '../services/supabase_service.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final Wildkin wildkin;

  /// True (default) right after a capture, when the top banner and
  /// "back to menu" flow make sense. Pass false when opening this
  /// screen to look at an already-owned Wildkin (Field Journal, Team
  /// screen): swaps the banner for a neutral one and turns the
  /// bottom button into a plain "back" instead of resetting the nav
  /// stack to the home screen.
  final bool isNewCapture;

  const ResultScreen({super.key, required this.wildkin, this.isNewCapture = true});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showFront = true;
  late Wildkin _wildkin;
  bool _updatingTeam = false;

  @override
  void initState() {
    super.initState();
    _wildkin = widget.wildkin;
  }

  Future<void> _toggleTeam() async {
    setState(() => _updatingTeam = true);
    try {
      final updated = await SupabaseService().setTeamMembership(
        id: _wildkin.id,
        isInTeam: !_wildkin.isInTeam,
      );
      setState(() => _wildkin = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _updatingTeam = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wildkin = _wildkin;
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
                  text: widget.isNewCapture
                      ? 'Congratulations! You caught a new Wildkin!'
                      : _flavorLine(wildkin),
                  fontSize: 15,
                ),
                const SizedBox(height: 16),
                _SpriteStage(wildkin: wildkin, showFront: _showFront),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => setState(() => _showFront = !_showFront),
                  child: _FlipHint(showFront: _showFront),
                ),
                if (wildkin.speciesHint != null) ...[
                  const SizedBox(height: 8),
                  _OriginTag(speciesHint: wildkin.speciesHint!),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LevelBadge(level: wildkin.level),
                    const SizedBox(width: 10),
                    TypeBadgeRow(types: wildkin.types),
                  ],
                ),
                const SizedBox(height: 10),
                PixelButton(
                  label: wildkin.isInTeam ? 'REMOVE FROM TEAM' : 'ADD TO TEAM',
                  background: wildkin.isInTeam ? AppColors.emberRed : AppColors.grassGreen,
                  onPressed: _updatingTeam ? null : _toggleTeam,
                ),
                const SizedBox(height: 14),
                _EvolutionCard(wildkin: wildkin),
                const SizedBox(height: 14),
                _TypeMatchupsCard(types: wildkin.types),
                const SizedBox(height: 14),
                _StatsCard(stats: stats),
                const SizedBox(height: 14),
                _MovesCard(moves: wildkin.moves.map((m) => m.move).toList()),
                const SizedBox(height: 14),
                _CaptureStoryCard(wildkin: wildkin),
                const SizedBox(height: 20),
                PixelButton(
                  label: widget.isNewCapture ? 'BACK TO MENU' : 'BACK',
                  background: AppColors.tidalBlue,
                  onPressed: () {
                    if (widget.isNewCapture) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A short, varied line for the banner when this Wildkin is being
  /// looked up (not freshly caught) — picked deterministically from
  /// its id so it doesn't flicker between rebuilds.
  String _flavorLine(Wildkin wildkin) {
    const lines = [
      'Ready when you are.',
      'Loyal and always watching.',
      "Let's take a look.",
      'Standing by.',
    ];
    return lines[wildkin.id.hashCode.abs() % lines.length];
  }
}

/// Small pill under the sprite naming the real-world animal this
/// Wildkin was derived from (e.g. "Derived from a cat"), when known.
class _OriginTag extends StatelessWidget {
  final String speciesHint;
  const _OriginTag({required this.speciesHint});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Derived from a $speciesHint',
      style: AppFonts.body(fontSize: 13, color: AppColors.textMuted).copyWith(
        fontStyle: FontStyle.italic,
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
        child: SpriteImage(url: spriteUrl, key: ValueKey(spriteUrl)),
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

/// Shows what this Wildkin is weak against and resistant to, built
/// straight from [TypeChart.matchupsFor] — the same source of truth
/// [EvolutionEngine] and [StatsEngine] use to steer second-type
/// selection and defensive compensation. x4/x0.25 entries (only
/// possible once a Wildkin has two types) get an outlined badge and
/// their own row, since they're the ones that actually swing a
/// battle and are worth calling out clearly rather than burying them
/// among the plain x2/x0.5 ones.
class _TypeMatchupsCard extends StatelessWidget {
  final List<String> types;
  const _TypeMatchupsCard({required this.types});

  @override
  Widget build(BuildContext context) {
    final matchups = TypeChart.matchupsFor(types);

    return _Panel(
      title: 'TYPE MATCHUPS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (types.length == 2) ...[
            _TypingQualityChip(matchups: matchups),
            const SizedBox(height: 10),
          ],
          if (matchups.weakX4.isNotEmpty)
            _MatchupRow(
              label: 'QUADRUPLE WEAKNESS',
              labelColor: AppColors.emberRed,
              types: matchups.weakX4,
              multiplierLabel: 'x4',
              isDoubledUp: true,
            ),
          if (matchups.weakX2.isNotEmpty)
            _MatchupRow(
              label: 'Weak against',
              types: matchups.weakX2,
              multiplierLabel: 'x2',
            ),
          if (matchups.resistX4.isNotEmpty)
            _MatchupRow(
              label: 'QUADRUPLE RESISTANCE',
              labelColor: AppColors.grassGreen,
              types: matchups.resistX4,
              multiplierLabel: 'x0.25',
              isDoubledUp: true,
            ),
          if (matchups.resistX2.isNotEmpty)
            _MatchupRow(
              label: 'Resists',
              types: matchups.resistX2,
              multiplierLabel: 'x0.5',
            ),
          if (matchups.immune.isNotEmpty)
            _MatchupRow(
              label: 'Immune to',
              types: matchups.immune,
              multiplierLabel: 'IMMUNE',
            ),
        ],
      ),
    );
  }
}

/// Quick verdict on a dual-type combo, computed from the same
/// [WildkinMatchups] the rest of the panel already has — no extra
/// calculation, just a friendlier label than reading four lists of
/// badges. Only shown for dual types: a single type never has an x4
/// anything, so there's nothing to call out.
class _TypingQualityChip extends StatelessWidget {
  final WildkinMatchups matchups;
  const _TypingQualityChip({required this.matchups});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    if (matchups.hasNetQuadWeakness) {
      label = 'RISKY TYPING';
      color = AppColors.emberRed;
    } else if (matchups.resistX4.isNotEmpty) {
      label = 'SOLID TYPING';
      color = AppColors.grassGreen;
    } else {
      label = 'BALANCED TYPING';
      color = AppColors.tidalBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: AppFonts.pixelTitle(fontSize: 8, color: Colors.white)),
    );
  }
}

class _MatchupRow extends StatelessWidget {
  final String label;
  final Color? labelColor;
  final List<String> types;
  final String multiplierLabel;
  final bool isDoubledUp;

  const _MatchupRow({
    required this.label,
    required this.types,
    required this.multiplierLabel,
    this.labelColor,
    this.isDoubledUp = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppFonts.pixelTitle(fontSize: 9, color: labelColor ?? AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types
                .map((t) => TypeMatchupBadge(
                      type: t,
                      multiplierLabel: multiplierLabel,
                      isDoubledUp: isDoubledUp,
                    ))
                .toList(),
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
          _StatBar(label: 'ELM. ATK', value: stats.elementalAttack, max: 200, color: const Color(0xFF9C6ADE)),
          _StatBar(label: 'ELM. DEF', value: stats.elementalDefense, max: 200, color: const Color(0xFF4FA8A0)),
          _StatBar(label: 'SPEED', value: stats.speed, max: 200, color: const Color(0xFFE0A62B)),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final String? subtitle;
  final int value;
  final int max;
  final Color color;

  const _StatBar({
    required this.label,
    this.subtitle,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppFonts.pixelTitle(fontSize: 9)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppFonts.body(fontSize: 8, color: AppColors.textMuted),
                  ),
              ],
            ),
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

/// Turns the raw capture context (and, if it evolved, the evolution
/// context too) into a couple of readable sentences instead of bare
/// stat chips — e.g. "Caught at night, in the rain, near the coast."
/// The chips stay underneath for a quick-glance version of the same
/// data.
class _CaptureStoryCard extends StatelessWidget {
  final Wildkin wildkin;
  const _CaptureStoryCard({required this.wildkin});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'CAPTURE STORY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sentenceFor(wildkin.captureContext, verb: 'Caught'),
            style: AppFonts.body(fontSize: 14, color: AppColors.panelBrown),
          ),
          const SizedBox(height: 6),
          _chips(wildkin.captureContext),
          if (wildkin.evolutionContext != null) ...[
            const SizedBox(height: 14),
            Text(
              _sentenceFor(wildkin.evolutionContext!, verb: 'Evolved'),
              style: AppFonts.body(fontSize: 14, color: AppColors.panelBrown),
            ),
            const SizedBox(height: 6),
            _chips(wildkin.evolutionContext!),
          ],
        ],
      ),
    );
  }

  String _sentenceFor(CaptureContext ctx, {required String verb}) {
    final timeOfDay = ctx.isNightTime ? 'at night' : 'during the day';
    final weather = _weatherPhrase(ctx.weatherCondition);
    final place = _biomePhrase(ctx.biome);
    return '$verb $timeOfDay, $weather, $place, in ${ctx.season}. '
        '(${ctx.temperatureCelsius.round()}°C)';
  }

  String _weatherPhrase(String weatherCondition) {
    switch (weatherCondition.toLowerCase()) {
      case 'rain':
        return 'in the rain';
      case 'snow':
        return 'in the snow';
      case 'storm':
        return 'during a storm';
      case 'fog':
        return 'in thick fog';
      case 'clear':
        return 'under a clear sky';
      default:
        return 'in $weatherCondition weather';
    }
  }

  String _biomePhrase(Biome biome) {
    switch (biome) {
      case Biome.sea:
        return 'near the coast';
      case Biome.mountain:
        return 'up in the mountains';
      case Biome.forest:
        return 'deep in a forest';
      case Biome.urbanCity:
        return 'in the middle of a city';
      case Biome.plain:
        return 'out on the open plains';
      case Biome.desert:
        return 'out in the desert';
      case Biome.unknown:
        return 'somewhere unremarkable';
    }
  }

  Widget _chips(CaptureContext ctx) {
    final chips = <String>[
      '${ctx.temperatureCelsius.round()}°C',
      ctx.weatherCondition,
      ctx.season,
      ctx.isNightTime ? 'night' : 'day',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: chips
          .map((label) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.panelBrown,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  label,
                  style: AppFonts.body(fontSize: 12, color: AppColors.textOnDark),
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
