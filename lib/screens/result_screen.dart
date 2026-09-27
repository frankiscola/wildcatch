import 'package:flutter/material.dart';
import '../models/wildkin.dart';
import '../models/capture_context.dart';
import '../models/move.dart';
import '../models/type_chart.dart';
import '../models/wildkin_physique.dart';
import '../models/biome_imprints.dart';
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

  /// Adding to the team happens immediately; removing always asks
  /// for confirmation first, since it's the one accidental tap that
  /// actually costs the player something (a battle-ready teammate).
  Future<void> _handleTeamButtonPressed() async {
    if (_wildkin.isInTeam) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove from team?'),
          content: Text('${_wildkin.nickname} will be benched. You can add it back anytime.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('REMOVE', style: TextStyle(color: AppColors.emberRed)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _toggleTeam();
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
                      : _descriptionLine(wildkin),
                  fontSize: 15,
                ),
                const SizedBox(height: 16),
                _SpriteStage(
                  wildkin: wildkin,
                  showFront: _showFront,
                  onFlip: () => setState(() => _showFront = !_showFront),
                ),
                const SizedBox(height: 8),
                Text(
                  _showFront ? 'Front view' : 'Back view',
                  style: AppFonts.body(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
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
                _PhysiqueCard(wildkin: wildkin),
                const SizedBox(height: 14),
                _TypeMatchupsCard(types: wildkin.types),
                const SizedBox(height: 14),
                _StatsCard(stats: stats),
                const SizedBox(height: 14),
                _MovesCard(moves: wildkin.moves.map((m) => m.move).toList()),
                const SizedBox(height: 14),
                _CaptureStoryCard(wildkin: wildkin),
                if (wildkin.imprint != null) ...[
                  const SizedBox(height: 14),
                  _ImprintCard(imprint: wildkin.imprint!),
                ],
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
                const SizedBox(height: 14),
                PixelButton(
                  label: wildkin.isInTeam ? 'REMOVE FROM TEAM' : 'ADD TO TEAM',
                  background: wildkin.isInTeam ? AppColors.emberRed : AppColors.grassGreen,
                  onPressed: _updatingTeam ? null : _handleTeamButtonPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Combines the random flavor line with a short, narrative nod to
  /// the real animal this Wildkin came from (when known) — e.g.
  /// "Loyal and always watching. Beetle walking." — instead of a
  /// separate, dry "Derived from a beetle" label.
  String _descriptionLine(Wildkin wildkin) {
    final flavor = _flavorLine(wildkin);
    final species = wildkin.speciesHint;
    if (species == null || species.isEmpty) return flavor;
    return '$flavor ${_speciesPhrase(species)}';
  }

  String _speciesPhrase(String speciesHint) {
    final capitalized = speciesHint[0].toUpperCase() + speciesHint.substring(1);
    return '$capitalized walking.';
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

class _SpriteStage extends StatelessWidget {
  final Wildkin wildkin;
  final bool showFront;
  final VoidCallback onFlip;

  const _SpriteStage({
    required this.wildkin,
    required this.showFront,
    required this.onFlip,
  });

  @override
  Widget build(BuildContext context) {
    final spriteUrl = showFront ? wildkin.frontSpriteUrl : wildkin.backSpriteUrl;

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        gradient: TypeColors.backgroundGradient(wildkin.types),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: SpriteImage(url: spriteUrl, key: ValueKey(spriteUrl)),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _FlipButton(onTap: onFlip),
          ),
        ],
      ),
    );
  }
}

/// The flip button now lives INSIDE the sprite rectangle (top-right),
/// instead of as a separate pill underneath it.
class _FlipButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FlipButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(9),
          child: Icon(Icons.flip, size: 18, color: AppColors.panelBrown),
        ),
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

/// Weight and size, now a proper card of their own instead of a tiny
/// caption squeezed under the sprite.
class _PhysiqueCard extends StatelessWidget {
  final Wildkin wildkin;
  const _PhysiqueCard({required this.wildkin});

  @override
  Widget build(BuildContext context) {
    final physique = wildkin.physique;
    return _Panel(
      title: 'PHYSIQUE',
      child: Row(
        children: [
          Expanded(
            child: _PhysiqueStat(
              label: 'WEIGHT',
              value: '${physique.weightKg.toStringAsFixed(1)} kg',
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: AppColors.dialogBorderOuter.withValues(alpha: 0.15),
          ),
          Expanded(
            child: _PhysiqueStat(label: 'SIZE', value: physique.size.label),
          ),
        ],
      ),
    );
  }
}

class _PhysiqueStat extends StatelessWidget {
  final String label;
  final String value;
  const _PhysiqueStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppFonts.pixelTitle(fontSize: 9, color: AppColors.textMuted)),
        const SizedBox(height: 6),
        Text(value, style: AppFonts.body(fontSize: 17, color: AppColors.panelBrown)),
      ],
    );
  }
}

/// Shows the number of stages in the evolutionary line and the
/// qualitative hint about the next evolution, without ever revealing
/// the exact level. Now a visual stage tracker (nodes + connecting
/// bars) instead of plain "Current stage: X/Y" text.
class _EvolutionCard extends StatelessWidget {
  final Wildkin wildkin;
  const _EvolutionCard({required this.wildkin});

  @override
  Widget build(BuildContext context) {
    final plan = wildkin.evolutionPlan;

    return _Panel(
      title: 'EVOLUTION',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.totalStages == 3 ? 'Up to 2 evolutions possible' : 'Up to 1 evolution possible',
            style: AppFonts.body(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          _EvolutionTrack(currentStage: plan.currentStage, totalStages: plan.totalStages),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.emberRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              plan.timingLabel(),
              style: AppFonts.body(fontSize: 13, color: AppColors.emberRed).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of stage "nodes" connected by bars — filled/green up to the
/// current stage, hollow with a "?" beyond it (an evolution not yet
/// reached should look genuinely unknown, not just grayed out text).
class _EvolutionTrack extends StatelessWidget {
  final int currentStage;
  final int totalStages;
  const _EvolutionTrack({required this.currentStage, required this.totalStages});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var stage = 1; stage <= totalStages; stage++) {
      if (stage > 1) {
        final barReached = stage <= currentStage;
        children.add(
          Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: barReached
                  ? AppColors.grassGreen
                  : AppColors.dialogBorderOuter.withValues(alpha: 0.15),
            ),
          ),
        );
      }
      children.add(_StageNode(stage: stage, reached: stage <= currentStage));
    }
    return Row(children: children);
  }
}

class _StageNode extends StatelessWidget {
  final int stage;
  final bool reached;
  const _StageNode({required this.stage, required this.reached});

  @override
  Widget build(BuildContext context) {
    final outline = reached ? AppColors.grassGreen : AppColors.dialogBorderOuter.withValues(alpha: 0.25);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: reached ? AppColors.grassGreen : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: outline, width: 2),
          ),
          child: Center(
            child: reached
                ? Text(
                    '$stage',
                    style: AppFonts.pixelTitle(fontSize: 12, color: Colors.white),
                  )
                : Icon(Icons.question_mark, size: 14, color: AppColors.textMuted.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(height: 4),
        Text('STAGE $stage', style: AppFonts.body(fontSize: 9, color: AppColors.textMuted)),
      ],
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
    required this.value,
    required this.max,
    required this.color,
  }) : subtitle = null;

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
                  Container(height: 14, color: AppColors.dialogBorderOuter.withValues(alpha: 0.12)),
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
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(m.name, style: AppFonts.body(fontSize: 16)),
                          ),
                          const SizedBox(width: 8),
                          TypeBadge(type: m.type),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: m.category == MoveCategory.status
                            ? [_MoveStatChip(label: 'PP', value: '${m.maxPp}')]
                            : [
                                _MoveStatChip(label: 'POW', value: '${m.power}'),
                                const SizedBox(width: 8),
                                _MoveStatChip(label: 'ACC', value: '${m.accuracy}%'),
                                const SizedBox(width: 8),
                                _MoveStatChip(label: 'PP', value: '${m.maxPp}'),
                              ],
                      ),
                      if (_mechanicLabel(m) != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _mechanicLabel(m)!,
                            style: AppFonts.body(fontSize: 11, color: AppColors.tidalBlue),
                          ),
                        ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  /// One-line callout for a move's special mechanic, if it has one —
  /// at most one of these is ever set on a given move.
  String? _mechanicLabel(Move m) {
    if (m.weatherAffinity != null) {
      return '☀ +${m.weatherBonusPct}% if the weather right now matches';
    }
    if (m.timeAffinity != null) {
      return '🌙 +${m.timeBonusPct}% if it\'s really ${m.timeAffinity} right now';
    }
    if (m.inflictsStatus != null) {
      return '☠ ${m.statusChancePct}% chance to inflict a status';
    }
    if (m.scalesWithTargetWeight) {
      return '⚖ Hits harder against a heavier target';
    }
    return null;
  }
}

/// Small labeled stat chip (POW/ACC/PP), used inside the moves list
/// so the three numbers read as distinct values instead of one
/// run-together string.
class _MoveStatChip extends StatelessWidget {
  final String label;
  final String value;
  const _MoveStatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.dialogBorderOuter.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppFonts.pixelTitle(fontSize: 7, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppFonts.body(fontSize: 13, color: AppColors.panelBrown).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
    final temperature = _temperatureLabel(ctx.temperatureCelsius).toLowerCase();
    return '$verb $timeOfDay, $weather, $place, in ${ctx.season}. It was $temperature.';
  }

  /// A descriptive word instead of a raw number — "18°C" doesn't mean
  /// much at a glance, "Chill" does.
  String _temperatureLabel(double celsius) {
    if (celsius <= -5) return 'Freezing';
    if (celsius <= 5) return 'Very cold';
    if (celsius <= 12) return 'Cold';
    if (celsius <= 18) return 'Chill';
    if (celsius <= 24) return 'Mild';
    if (celsius <= 29) return 'Warm';
    if (celsius <= 34) return 'Hot';
    if (celsius <= 39) return 'Very hot';
    return 'Melting';
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
      _temperatureLabel(ctx.temperatureCelsius),
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
/// Shows the permanent biome imprint this Wildkin rolled at capture
/// (see BiomeImprints) — its name, flavor line, and the bonus it
/// grants.
class _ImprintCard extends StatelessWidget {
  final BiomeImprint imprint;
  const _ImprintCard({required this.imprint});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'IMPRINT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            imprint.name,
            style: AppFonts.pixelTitle(fontSize: 11, color: AppColors.emberRed),
          ),
          const SizedBox(height: 4),
          Text(
            imprint.description,
            style: AppFonts.body(fontSize: 13, color: AppColors.panelBrown).copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '+${imprint.bonusPct}% ${imprint.effect.label}',
            style: AppFonts.body(fontSize: 13, color: AppColors.grassGreen),
          ),
        ],
      ),
    );
  }
}

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
