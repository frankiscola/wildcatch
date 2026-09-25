import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/wildkin.dart';
import '../models/move.dart';
import '../models/wild_encounter.dart';
import '../providers/capture_flow_provider.dart';
import '../services/battle_engine.dart';
import '../services/context_builder.dart';
import '../services/leveling_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pixel_button.dart';
import '../widgets/type_badge.dart';
import '../widgets/sprite_image.dart';
import 'generating_screen.dart';

/// Battle screen, split top/bottom:
///  - top half: the battle scene (opponent + own sprite, HP boxes) —
///    see _Battlefield.
///  - bottom half: a row of your team (tap to switch the active
///    fighter mid-battle — costs the turn, like the classic games),
///    the 4 moves front and center (no submenu), and a slim
///    CATCH / RUN row at the very bottom.
///
/// Team HP persists per-member as the battle happens (not just the
/// Wildkin active at the end): see _persistTeamChanges.
class BattleScreen extends ConsumerStatefulWidget {
  final Wildkin ownWildkin;
  final WildEncounter initialWild;

  const BattleScreen({
    super.key,
    required this.ownWildkin,
    required this.initialWild,
  });

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  final _engine = BattleEngine();
  final _levelingService = LevelingService();

  late WildEncounter _wild;
  List<Wildkin>? _team; // null while loading
  late String _activeId;
  final Map<String, int> _startingHp = {};

  String _log = 'A wild Wildkin appears!';
  bool _busy = false;
  bool _battleOver = false;
  bool _victory = false;
  bool _fled = false;
  bool _mustSwitch = false; // active one fainted, a bench member is left

  Wildkin get _own => _team!.firstWhere((w) => w.id == _activeId);

  @override
  void initState() {
    super.initState();
    _wild = widget.initialWild;
    _activeId = widget.ownWildkin.id;
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    List<Wildkin> team;
    try {
      final all = await ref.read(myWildkinProvider.future);
      team = all.where((w) => w.isInTeam).toList();
      if (!team.any((w) => w.id == widget.ownWildkin.id)) {
        team = [widget.ownWildkin, ...team];
      }
    } catch (_) {
      team = [widget.ownWildkin];
    }
    if (!mounted) return;
    setState(() {
      _team = team;
      _startingHp.addEntries(team.map((w) => MapEntry(w.id, w.currentHp)));
    });
  }

  void _updateOwn(Wildkin updated) {
    setState(() {
      _team = _team!.map((w) => w.id == updated.id ? updated : w).toList();
    });
  }

  Future<void> _useMove(Move move) async {
    if (_busy || _battleOver || _mustSwitch) return;
    setState(() => _busy = true);

    final result = _engine.attackWild(attacker: _own, target: _wild, move: move);

    setState(() {
      if (!result.hit) {
        _log = '${_own.nickname} uses ${move.name}... but it misses!';
      } else {
        _wild = _wild.copyWith(
          currentHp: (_wild.currentHp - result.damage).clamp(0, _wild.maxHp),
        );
        final note = result.effectivenessMessage;
        _log = '${_own.nickname} uses ${move.name}! ${result.damage} damage.'
            '${note != null ? '\n$note' : ''}';
      }
    });

    if (_wild.currentHp <= 0) {
      await _handleVictory();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));
    await _wildCounterAttack();
  }

  /// The wild one's turn. Shared by "used a move" and "switched
  /// Wildkin voluntarily" (a forced switch, after fainting, does NOT
  /// trigger this — the wild already got its hit that caused it).
  Future<void> _wildCounterAttack() async {
    if (_wild.moves.isEmpty) {
      setState(() => _busy = false);
      return;
    }
    final wildMove = _wild.moves[(_wild.moves.length > 1) ? 1 : 0];
    final counter = _engine.attackOwn(attacker: _wild, target: _own, move: wildMove);

    final current = _own;
    Wildkin afterHit = current;
    String logAddition = '';
    if (counter.hit) {
      afterHit = current.copyWith(
        currentHp: (current.currentHp - counter.damage)
            .clamp(0, current.computeStats().maxHp),
      );
      final note = counter.effectivenessMessage;
      logAddition = '\nThe wild Wildkin strikes back with ${wildMove.name}! '
          '${counter.damage} damage to ${current.nickname}.'
          '${note != null ? '\n$note' : ''}';
    }

    setState(() {
      _updateOwn(afterHit);
      _log += logAddition;
      _busy = false;
      if (afterHit.currentHp <= 0) {
        final anyoneLeft = _team!.any((w) => w.id != afterHit.id && w.currentHp > 0);
        _log += '\n${afterHit.nickname} can no longer battle!';
        if (anyoneLeft) {
          _mustSwitch = true;
          _log += ' Choose another Wildkin.';
        } else {
          _battleOver = true;
          _log += ' You have no more Wildkin able to fight!';
          _persistTeamChanges();
        }
      }
    });
  }

  /// Switches the active fighter.
  /// - Voluntary (tapped mid-turn, current one still standing): costs
  ///   the turn, the wild one gets a free hit — same as the classic
  ///   games.
  /// - Forced (current one just fainted, [_mustSwitch] is true): no
  ///   penalty, the wild one already used its turn to cause the faint.
  Future<void> _switchTo(Wildkin target) async {
    if (_battleOver || target.id == _activeId || target.currentHp <= 0) return;
    if (_busy && !_mustSwitch) return;

    final wasForced = _mustSwitch;
    setState(() {
      _mustSwitch = false;
      _activeId = target.id;
      _log = wasForced
          ? 'Go, ${target.nickname}!'
          : "${_team!.firstWhere((w) => w.id == _activeId).nickname}, come back! "
              'Go, ${target.nickname}!';
    });

    if (wasForced) return; // the wild one doesn't get a bonus turn here

    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 400));
    await _wildCounterAttack();
  }

  /// The wild one fainted: grant experience, handle any level-up,
  /// evolution, or new move, and persist everything to Supabase —
  /// for the winner via LevelingService, and for the rest of the
  /// team via _persistTeamChanges.
  Future<void> _handleVictory() async {
    setState(() {
      _log = 'The wild Wildkin is worn out!';
      _busy = true;
    });

    try {
      final gainedExp = _levelingService.expFromVictory(_wild.level);
      final (updated, summary) = await _levelingService.grantExperience(
        wildkin: _own,
        gainedExp: gainedExp,
        fetchCurrentContext: () => ContextBuilder().buildCurrentContext(),
      );

      final persisted = await SupabaseService().updateAfterBattle(updated);

      final messages = <String>['${_own.nickname} won! +$gainedExp EXP.'];
      if (summary.leveledUp) {
        messages.add(
          summary.levelsGained.length == 1
              ? 'It grew to level ${summary.levelsGained.first}!'
              : 'It grew all the way to level ${summary.levelsGained.last}!',
        );
      }
      if (summary.evolved) messages.add('${_own.nickname} evolved!');
      if (summary.learnedMove != null) {
        messages.add('It learned ${summary.learnedMove!.name}!');
      }

      setState(() {
        _updateOwn(persisted);
        _log = messages.join('\n');
        _battleOver = true;
        _victory = true;
        _busy = false;
      });
      await _persistTeamChanges(alreadyPersisted: persisted);
    } catch (e) {
      setState(() {
        _log = "Victory earned, but I couldn't save the progress: $e";
        _battleOver = true;
        _victory = true;
        _busy = false;
      });
    }
  }

  /// Saves the HP of every team member touched during this battle
  /// (skips whoever [alreadyPersisted] refers to, and anyone whose
  /// HP never changed from the start of the battle).
  Future<void> _persistTeamChanges({Wildkin? alreadyPersisted}) async {
    if (_team == null) return;
    for (final member in _team!) {
      if (alreadyPersisted != null && member.id == alreadyPersisted.id) continue;
      if (_startingHp[member.id] == member.currentHp) continue;
      try {
        await SupabaseService().updateAfterBattle(member);
      } catch (_) {
        // Best-effort: a failed HP save here shouldn't block the
        // player from leaving the battle screen.
      }
    }
  }

  /// Attempts a capture: the probability roll is local/immediate, but
  /// if it succeeds the REAL catch still goes through a live
  /// confirmation photo (same mechanism as the double-sighting used
  /// for direct capture) — it never bypasses it.
  Future<void> _attemptCatch() async {
    if (_busy || _battleOver || _mustSwitch) return;

    final probability = _engine.catchProbability(_wild);
    final success = _engine.attemptCatch(_wild);

    if (!success) {
      setState(() {
        _battleOver = true;
        _log = 'The Wildkin got away! (odds were ${(probability * 100).round()}%)';
      });
      await _persistTeamChanges();
      return;
    }

    setState(() {
      _busy = true;
      _log = 'Almost there! Take one more photo to confirm the capture.';
    });

    final userId = Supabase.instance.client.auth.currentUser!.id;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GeneratingScreen(isConfirmation: true)),
    );
    await ref.read(captureFlowProvider.notifier).captureConfirmation(userId: userId);

    if (!mounted) return;
    final state = ref.read(captureFlowProvider);
    setState(() {
      _busy = false;
      _battleOver = true;
      _log = state.errorMessage ??
          "Couldn't confirm the capture. The Wildkin remains free, but "
              'you can go looking for it again.';
    });
    await _persistTeamChanges();
  }

  /// Leaves the fight without a capture attempt — the wild Wildkin
  /// stays free.
  Future<void> _flee() async {
    if (_busy || _battleOver || _mustSwitch) return;
    setState(() {
      _battleOver = true;
      _fled = true;
      _log = "${_own.nickname} backs away. The wild Wildkin wasn't chased.";
    });
    await _persistTeamChanges();
  }

  @override
  Widget build(BuildContext context) {
    final team = _team;
    return Scaffold(
      appBar: AppBar(title: const Text('BATTLE')),
      body: RouteBackground(
        child: SafeArea(
          child: team == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: _Battlefield(wild: _wild, own: _own),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                        child: _battleOver
                            ? _BattleOverPanel(
                                log: _log,
                                buttonLabel: _victory ? 'CONTINUE' : (_fled ? 'OK' : 'CLOSE'),
                                onDone: () =>
                                    Navigator.of(context).popUntil((r) => r.isFirst),
                              )
                            : _BottomPanel(
                                team: team,
                                activeId: _activeId,
                                log: _log,
                                busy: _busy,
                                mustSwitch: _mustSwitch,
                                onSwitch: _switchTo,
                                onMove: _useMove,
                                onCatch: _attemptCatch,
                                onRun: _flee,
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Top half: opponent info box (top-left) + opponent visual
/// (upper-right), own info box with numeric HP (lower-right) + own
/// back sprite (lower-left) — bigger and more spaced out than a
/// cramped classic screen, with a soft ground shadow under each
/// combatant for a bit of depth.
class _Battlefield extends StatelessWidget {
  final WildEncounter wild;
  final Wildkin own;
  const _Battlefield({required this.wild, required this.own});

  @override
  Widget build(BuildContext context) {
    final ownStats = own.computeStats();
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: constraints.maxWidth * 0.42,
              child: _InfoBox(
                title: 'Wild · Lv.${wild.level}',
                types: wild.types,
                fraction: wild.maxHp == 0 ? 0 : wild.currentHp / wild.maxHp,
                hpLabel: null,
              ),
            ),
            Positioned(
              top: constraints.maxHeight * 0.16,
              right: 8,
              child: _GroundedVisual(
                child: _OpponentVisual(photoUrl: wild.photoUrl, types: wild.types),
                size: 130,
              ),
            ),
            Positioned(
              bottom: constraints.maxHeight * 0.02,
              left: 4,
              child: _GroundedVisual(
                child: SpriteImage(url: own.backSpriteUrl),
                size: 150,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              left: constraints.maxWidth * 0.38,
              child: _InfoBox(
                title: '${own.nickname} · Lv.${own.level}',
                types: own.types,
                fraction: ownStats.maxHp == 0 ? 0 : own.currentHp / ownStats.maxHp,
                hpLabel: '${own.currentHp}/${ownStats.maxHp}',
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A sprite with a soft dark ellipse "shadow platform" beneath it —
/// a small, cheap touch that reads as more polished than a sprite
/// floating with no ground contact.
class _GroundedVisual extends StatelessWidget {
  final Widget child;
  final double size;
  const _GroundedVisual({required this.child, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.08,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: size * 0.7,
            height: size * 0.18,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(size),
            ),
          ),
          SizedBox(width: size, height: size, child: child),
        ],
      ),
    );
  }
}

/// The wild opponent's visual during battle is the actual photo
/// taken of it (not a generated sprite — those only exist once it's
/// actually caught). Falls back to a type-colored placeholder when
/// there's no photo yet (e.g. the debug preview harness).
class _OpponentVisual extends StatelessWidget {
  final String photoUrl;
  final List<String> types;
  const _OpponentVisual({required this.photoUrl, required this.types});

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isEmpty) {
      final color = types.isEmpty ? AppColors.textMuted : TypeColors.of(types.first);
      return Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: const Icon(Icons.help_outline, color: Colors.white, size: 48),
      );
    }
    return ClipOval(child: SpriteImage(url: photoUrl));
  }
}

/// Compact name/level + HP bar box (no numeric HP unless [hpLabel]
/// is given — the opponent's exact number is never shown, only
/// yours, same as the classic games).
class _InfoBox extends StatelessWidget {
  final String title;
  final List<String> types;
  final double fraction;
  final String? hpLabel;

  const _InfoBox({
    required this.title,
    required this.types,
    required this.fraction,
    required this.hpLabel,
  });

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    final barColor = f > 0.5
        ? AppColors.grassGreen
        : (f > 0.2 ? const Color(0xFFE0A62B) : AppColors.emberRed);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: AppFonts.pixelTitle(fontSize: 8), overflow: TextOverflow.ellipsis),
              ),
              TypeBadgeRow(types: types),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 8, color: AppColors.dialogBorderOuter.withValues(alpha: 0.12)),
                FractionallySizedBox(widthFactor: f, child: Container(height: 8, color: barColor)),
              ],
            ),
          ),
          if (hpLabel != null) ...[
            const SizedBox(height: 3),
            Text(hpLabel!, style: AppFonts.body(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

/// Bottom half while the battle is ongoing: team switch row, a
/// one-line log, the 4 moves (the main event, gets the most space),
/// and a slim CATCH / RUN row at the very bottom.
class _BottomPanel extends StatelessWidget {
  final List<Wildkin> team;
  final String activeId;
  final String log;
  final bool busy;
  final bool mustSwitch;
  final void Function(Wildkin) onSwitch;
  final void Function(Move) onMove;
  final VoidCallback onCatch;
  final VoidCallback onRun;

  const _BottomPanel({
    required this.team,
    required this.activeId,
    required this.log,
    required this.busy,
    required this.mustSwitch,
    required this.onSwitch,
    required this.onMove,
    required this.onCatch,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    final own = team.firstWhere((w) => w.id == activeId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TeamSwitchRow(team: team, activeId: activeId, busy: busy && !mustSwitch, onTap: onSwitch),
        const SizedBox(height: 6),
        Text(
          mustSwitch ? 'Choose a Wildkin to send out!' : log,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.body(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _MovesGrid(
            moves: own.moves,
            enabled: !busy && !mustSwitch,
            onMove: onMove,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: PixelButton(
                label: 'CATCH',
                icon: Icons.center_focus_strong,
                background: AppColors.grassGreen,
                onPressed: (busy || mustSwitch) ? null : onCatch,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PixelButton(
                label: 'RUN',
                icon: Icons.directions_run,
                background: AppColors.emberRed,
                onPressed: (busy || mustSwitch) ? null : onRun,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Row of up to 4 team avatars — tap to switch the active fighter.
/// The active one is outlined; fainted ones are dimmed and disabled.
class _TeamSwitchRow extends StatelessWidget {
  final List<Wildkin> team;
  final String activeId;
  final bool busy;
  final void Function(Wildkin) onTap;

  const _TeamSwitchRow({
    required this.team,
    required this.activeId,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: team.map((w) {
          final isActive = w.id == activeId;
          final fainted = w.currentHp <= 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: (busy || fainted || isActive) ? null : () => onTap(w),
              child: Opacity(
                opacity: fainted ? 0.35 : 1.0,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.panelCream,
                    border: Border.all(
                      color: isActive ? AppColors.emberRed : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: ClipOval(child: SpriteImage(url: w.frontSpriteUrl)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// The 4 moves, front and center — no submenu. Fills whatever
/// vertical space is left, so it's the biggest thing on screen.
class _MovesGrid extends StatelessWidget {
  final List<LearnedMove> moves;
  final bool enabled;
  final void Function(Move) onMove;

  const _MovesGrid({required this.moves, required this.enabled, required this.onMove});

  @override
  Widget build(BuildContext context) {
    final slots = List<LearnedMove?>.from(moves);
    while (slots.length < 4) {
      slots.add(null);
    }
    return Column(
      children: [
        Expanded(child: Row(children: [_cell(slots[0]), const SizedBox(width: 8), _cell(slots[1])])),
        const SizedBox(height: 8),
        Expanded(child: Row(children: [_cell(slots[2]), const SizedBox(width: 8), _cell(slots[3])])),
      ],
    );
  }

  Widget _cell(LearnedMove? learned) {
    if (learned == null) {
      return const Expanded(child: SizedBox.shrink());
    }
    final move = learned.move;
    final canUse = enabled && learned.currentPp > 0;
    return Expanded(
      child: GestureDetector(
        onTap: canUse ? () => onMove(move) : null,
        child: Container(
          decoration: BoxDecoration(
            color: canUse ? TypeColors.of(move.type) : AppColors.textMuted,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowSoft, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                move.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.pixelTitle(fontSize: 11, color: AppColors.textOnDark),
              ),
              const SizedBox(height: 4),
              Text(
                'PP ${learned.currentPp}/${move.maxPp}',
                style: AppFonts.body(fontSize: 11, color: AppColors.textOnDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom half once the battle has ended: the final message and a
/// single button to leave. The battlefield above stays visible,
/// frozen on its last state.
class _BattleOverPanel extends StatelessWidget {
  final String log;
  final String buttonLabel;
  final VoidCallback onDone;

  const _BattleOverPanel({required this.log, required this.buttonLabel, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: GbaDialogBox(text: log, fontSize: 16)),
        const SizedBox(height: 16),
        PixelButton(label: buttonLabel, onPressed: onDone),
      ],
    );
  }
}
