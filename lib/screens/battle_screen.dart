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

/// Battle screen: the player's own Wildkin (already captured) faces
/// a wild Wildkin generated from the sighting in progress.
///
/// Layout deliberately mirrors the classic GBA-era battle screen:
/// opponent info box top-left + opponent visual upper-right, own
/// info box (with numeric HP) + own back sprite lower-left, and a
/// message box + a 2-level action menu (main -> moves) along the
/// bottom, in a 2x2 grid. See _Battlefield and _ActionPanel.
///
/// Two possible outcomes:
///  - the wild one faints: the player's Wildkin gains experience
///    (LevelingService), which can level it up, evolve it, and teach
///    it new moves — all persisted to Supabase.
///  - the player attempts a capture: if the probability roll
///    (BattleEngine) succeeds, the actual catch still goes through
///    the existing double-sighting mechanism (a live confirmation
///    photo) — it never bypasses it, so the server-side anti-spoofing
///    check still applies here too.
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

enum _MenuMode { main, moves }

class _BattleScreenState extends ConsumerState<BattleScreen> {
  final _engine = BattleEngine();
  final _levelingService = LevelingService();

  late WildEncounter _wild;
  late Wildkin _own; // mirrors current HP as the battle progresses
  String _log = 'A wild Wildkin appears!';
  bool _busy = false;
  bool _battleOver = false;
  bool _victory = false;
  bool _fled = false;
  _MenuMode _menu = _MenuMode.main;

  @override
  void initState() {
    super.initState();
    _wild = widget.initialWild;
    _own = widget.ownWildkin;
  }

  Future<void> _useMove(Move move) async {
    if (_busy || _battleOver) return;
    setState(() {
      _busy = true;
      _menu = _MenuMode.main;
    });

    final result =
        _engine.attackWild(attacker: _own, target: _wild, move: move);

    setState(() {
      if (!result.hit) {
        _log = '${_own.nickname} uses ${move.name}... but it misses!';
      } else {
        _wild = _wild.copyWith(
          currentHp: (_wild.currentHp - result.damage).clamp(0, _wild.maxHp),
        );
        final effectivenessNote = result.effectivenessMessage;
        _log = '${_own.nickname} uses ${move.name}! ${result.damage} damage.'
            '${effectivenessNote != null ? '\n$effectivenessNote' : ''}';
      }
    });

    if (_wild.currentHp <= 0) {
      await _handleVictory();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (_wild.moves.isEmpty) {
      setState(() => _busy = false);
      return;
    }
    final wildMove = _wild.moves[(_wild.moves.length > 1) ? 1 : 0];
    final counter =
        _engine.attackOwn(attacker: _wild, target: _own, move: wildMove);

    setState(() {
      if (counter.hit) {
        _own = _own.copyWith(
          currentHp: (_own.currentHp - counter.damage)
              .clamp(0, _own.computeStats().maxHp),
        );
        final effectivenessNote = counter.effectivenessMessage;
        _log += '\nThe wild Wildkin strikes back with ${wildMove.name}! '
            '${counter.damage} damage to ${_own.nickname}.'
            '${effectivenessNote != null ? '\n$effectivenessNote' : ''}';
      }
      _busy = false;
      if (_own.currentHp <= 0) {
        _battleOver = true;
        _log += '\n${_own.nickname} can no longer battle!';
      }
    });
  }

  /// The wild one fainted: grant experience, handle any level-up,
  /// evolution, or new move, and persist everything to Supabase.
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
      if (summary.evolved) {
        messages.add('${_own.nickname} evolved!');
      }
      if (summary.learnedMove != null) {
        messages.add('It learned ${summary.learnedMove!.name}!');
      }

      setState(() {
        _own = persisted;
        _log = messages.join('\n');
        _battleOver = true;
        _victory = true;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _log = 'Victory earned, but I couldn\'t save the progress: $e';
        _battleOver = true;
        _victory = true;
        _busy = false;
      });
    }
  }

  /// Attempts a capture: the probability roll is local/immediate, but
  /// if it succeeds the REAL catch still goes through a live
  /// confirmation photo (same mechanism as the double-sighting used
  /// for direct capture) — it never bypasses it.
  Future<void> _attemptCatch() async {
    if (_busy || _battleOver) return;
    setState(() => _menu = _MenuMode.main);

    final probability = _engine.catchProbability(_wild);
    final success = _engine.attemptCatch(_wild);

    if (!success) {
      setState(() {
        _battleOver = true;
        _log = 'The Wildkin got away! (odds were '
            '${(probability * 100).round()}%)';
      });
      return;
    }

    setState(() {
      _busy = true;
      _log = 'Almost there! Take one more photo to confirm the capture.';
    });

    final userId = Supabase.instance.client.auth.currentUser!.id;

    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const GeneratingScreen(isConfirmation: true)),
    );
    await ref
        .read(captureFlowProvider.notifier)
        .captureConfirmation(userId: userId);

    // If we get here, GeneratingScreen came back without completing
    // the capture (rejection or error) — on success, navigation goes
    // straight to ResultScreen, clearing the stack, and this widget
    // is no longer mounted.
    if (!mounted) return;
    final state = ref.read(captureFlowProvider);
    setState(() {
      _busy = false;
      _battleOver = true;
      _log = state.errorMessage ??
          "Couldn't confirm the capture. The Wildkin remains free, but "
              'you can go looking for it again.';
    });
  }

  /// Leaves the fight without a capture attempt — the wild Wildkin
  /// stays free.
  void _flee() {
    if (_busy || _battleOver) return;
    setState(() {
      _menu = _MenuMode.main;
      _battleOver = true;
      _fled = true;
      _log = "${_own.nickname} backs away. The wild Wildkin wasn't chased.";
    });
  }

  void _showInfo() {
    final stats = _own.computeStats();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        title: Text(_own.nickname, style: AppFonts.pixelTitle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TypeBadgeRow(types: _own.types),
            const SizedBox(height: 10),
            Text('Lv.${_own.level} · ${_own.currentHp}/${stats.maxHp} HP',
                style: AppFonts.body(fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              'Atk ${stats.attack} · Def ${stats.defense} · '
              'Sp.Atk ${stats.elementalAttack} · Sp.Def ${stats.elementalDefense} · Spd ${stats.speed}',
              style: AppFonts.body(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BATTLE')),
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _Battlefield(wild: _wild, own: _own),
                const SizedBox(height: 12),
                Expanded(
                  child: _battleOver
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GbaDialogBox(text: _log, fontSize: 16),
                              const SizedBox(height: 16),
                              PixelButton(
                                label: _victory
                                    ? 'CONTINUE'
                                    : (_fled ? 'OK' : 'CLOSE'),
                                onPressed: () => Navigator.of(context)
                                    .popUntil((route) => route.isFirst),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 5,
                              child: GbaDialogBox(
                                text: _log,
                                fontSize: 14,
                                padding: const EdgeInsets.all(14),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 4,
                              child: _ActionPanel(
                                mode: _menu,
                                busy: _busy,
                                own: _own,
                                onOpenMoves: () =>
                                    setState(() => _menu = _MenuMode.moves),
                                onBack: () =>
                                    setState(() => _menu = _MenuMode.main),
                                onMove: _useMove,
                                onCatch: _attemptCatch,
                                onRun: _flee,
                                onInfo: _showInfo,
                              ),
                            ),
                          ],
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

/// The battlefield: opponent info box (top-left) + opponent visual
/// (upper-right), own info box with numeric HP (lower-right) + own
/// back sprite (lower-left) — same diagonal composition as the
/// classic GBA battle screen.
class _Battlefield extends StatelessWidget {
  final WildEncounter wild;
  final Wildkin own;
  const _Battlefield({required this.wild, required this.own});

  @override
  Widget build(BuildContext context) {
    final ownStats = own.computeStats();
    return SizedBox(
      height: 270,
      child: Stack(
        children: [
          Positioned(
            top: 60,
            right: 4,
            child: _OpponentVisual(photoUrl: wild.photoUrl, types: wild.types),
          ),
          Positioned(
            bottom: 46,
            left: 0,
            child: SizedBox(
              width: 140,
              height: 140,
              child: SpriteImage(url: own.backSpriteUrl),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 110,
            child: _InfoBox(
              title: 'Wild · Lv.${wild.level}',
              types: wild.types,
              fraction: wild.maxHp == 0 ? 0 : wild.currentHp / wild.maxHp,
              hpLabel: null, // classic games hide the opponent's exact HP
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            left: 90,
            child: _InfoBox(
              title: '${own.nickname} · Lv.${own.level}',
              types: own.types,
              fraction: ownStats.maxHp == 0 ? 0 : own.currentHp / ownStats.maxHp,
              hpLabel: '${own.currentHp}/${ownStats.maxHp}',
            ),
          ),
        ],
      ),
    );
  }
}

/// The wild opponent's visual during battle is the actual photo
/// taken of it (not a generated sprite — those only exist once it's
/// actually caught). Falls back to a type-colored placeholder when
/// there's no photo yet (e.g. this debug preview harness).
class _OpponentVisual extends StatelessWidget {
  final String photoUrl;
  final List<String> types;
  const _OpponentVisual({required this.photoUrl, required this.types});

  @override
  Widget build(BuildContext context) {
    const size = 120.0;
    if (photoUrl.isEmpty) {
      final color = types.isEmpty ? AppColors.textMuted : TypeColors.of(types.first);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: const Icon(Icons.help_outline, color: Colors.white, size: 48),
      );
    }
    return ClipOval(
      child: SizedBox(width: size, height: size, child: SpriteImage(url: photoUrl)),
    );
  }
}

/// Compact name/level + HP bar box (no numeric HP unless [hpLabel]
/// is given — the classic screen never shows the opponent's exact
/// number, only yours).
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
                child: Text(
                  title,
                  style: AppFonts.pixelTitle(fontSize: 8),
                  overflow: TextOverflow.ellipsis,
                ),
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
                FractionallySizedBox(
                  widthFactor: f,
                  child: Container(height: 8, color: barColor),
                ),
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

/// The bottom-right 2x2 menu. Main mode: FIGHT / CATCH / RUN / INFO.
/// Moves mode (after FIGHT): the 4 actual moves, with a back arrow.
class _ActionPanel extends StatelessWidget {
  final _MenuMode mode;
  final bool busy;
  final Wildkin own;
  final VoidCallback onOpenMoves;
  final VoidCallback onBack;
  final void Function(Move) onMove;
  final VoidCallback onCatch;
  final VoidCallback onRun;
  final VoidCallback onInfo;

  const _ActionPanel({
    required this.mode,
    required this.busy,
    required this.own,
    required this.onOpenMoves,
    required this.onBack,
    required this.onMove,
    required this.onCatch,
    required this.onRun,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: mode == _MenuMode.main
          ? _grid([
              _Slot('FIGHT', AppColors.tidalBlue, busy ? null : onOpenMoves),
              _Slot('CATCH', AppColors.grassGreen, busy ? null : onCatch),
              _Slot('RUN', AppColors.emberRed, busy ? null : onRun),
              _Slot('INFO', AppColors.panelBrown, busy ? null : onInfo),
            ])
          : Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: busy ? null : onBack,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ),
                Expanded(
                  child: _grid(
                    own.moves
                        .map((m) => _Slot(
                              '${m.move.name}\n(${m.currentPp}/${m.move.maxPp})',
                              TypeColors.of(m.move.type),
                              busy ? null : () => onMove(m.move),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _grid(List<_Slot> slots) {
    while (slots.length < 4) {
      slots.add(_Slot('—', AppColors.textMuted, null));
    }
    return Column(
      children: [
        Expanded(child: Row(children: [_cell(slots[0]), _cell(slots[1])])),
        const SizedBox(height: 6),
        Expanded(child: Row(children: [_cell(slots[2]), _cell(slots[3])])),
      ],
    );
  }

  Widget _cell(_Slot slot) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: _MenuSlotButton(slot: slot),
        ),
      );
}

class _Slot {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _Slot(this.label, this.color, this.onTap);
}

/// A single grid cell in the 2x2 action menu — same gradient/shadow
/// language as PixelButton, but sized to fill its cell instead of
/// hugging its content.
class _MenuSlotButton extends StatelessWidget {
  final _Slot slot;
  const _MenuSlotButton({required this.slot});

  Color _darken(Color color, [double amount = 0.18]) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = slot.onTap == null;
    final bg = disabled ? AppColors.textMuted : slot.color;

    return GestureDetector(
      onTap: slot.onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bg, _darken(bg)],
          ),
        ),
        child: Text(
          slot.label.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.pixelTitle(fontSize: 8, color: AppColors.textOnDark),
        ),
      ),
    );
  }
}
