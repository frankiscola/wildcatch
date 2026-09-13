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
import 'generating_screen.dart';

/// Battle screen: the player's own Wildkin (already captured) faces
/// a wild Wildkin generated from the sighting in progress.
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

class _BattleScreenState extends ConsumerState<BattleScreen> {
  final _engine = BattleEngine();
  final _levelingService = LevelingService();

  late WildEncounter _wild;
  late Wildkin _own; // mirrors current HP as the battle progresses
  String _log = 'A wild Wildkin appears!';
  bool _busy = false;
  bool _battleOver = false;
  bool _victory = false;

  @override
  void initState() {
    super.initState();
    _wild = widget.initialWild;
    _own = widget.ownWildkin;
  }

  Future<void> _useMove(Move move) async {
    if (_busy || _battleOver) return;
    setState(() => _busy = true);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BATTLE')),
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _WildHpBar(wild: _wild),
                const SizedBox(height: 10),
                _OwnHpBar(wildkin: _own),
                const SizedBox(height: 16),
                Expanded(child: GbaDialogBox(text: _log, fontSize: 16)),
                const SizedBox(height: 16),
                if (!_battleOver) ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _own.moves
                        .map((m) => PixelButton(
                              label: m.move.name.toUpperCase(),
                              background: AppColors.tidalBlue,
                              onPressed: _busy ? null : () => _useMove(m.move),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  PixelButton(
                    label: 'ATTEMPT CAPTURE',
                    background: AppColors.grassGreen,
                    icon: Icons.center_focus_strong,
                    onPressed: _busy ? null : _attemptCatch,
                  ),
                ] else
                  PixelButton(
                    label: _victory ? 'CONTINUE' : 'CLOSE',
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WildHpBar extends StatelessWidget {
  final WildEncounter wild;
  const _WildHpBar({required this.wild});

  @override
  Widget build(BuildContext context) {
    return _HpRow(
      title: 'Wild · Lv.${wild.level}',
      types: wild.types,
      current: wild.currentHp,
      max: wild.maxHp,
    );
  }
}

class _OwnHpBar extends StatelessWidget {
  final Wildkin wildkin;
  const _OwnHpBar({required this.wildkin});

  @override
  Widget build(BuildContext context) {
    return _HpRow(
      title: '${wildkin.nickname} · Lv.${wildkin.level}',
      types: wildkin.types,
      current: wildkin.currentHp,
      max: wildkin.computeStats().maxHp,
    );
  }
}

class _HpRow extends StatelessWidget {
  final String title;
  final List<String> types;
  final int current;
  final int max;

  const _HpRow({
    required this.title,
    required this.types,
    required this.current,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = max == 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    final barColor = fraction > 0.5
        ? AppColors.grassGreen
        : (fraction > 0.2 ? const Color(0xFFE0A62B) : AppColors.emberRed);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppFonts.pixelTitle(fontSize: 10)),
              TypeBadgeRow(types: types),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                    height: 12,
                    color: AppColors.dialogBorderOuter.withValues(alpha: 0.12)),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(height: 12, color: barColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('$current / $max HP', style: AppFonts.body(fontSize: 13)),
        ],
      ),
    );
  }
}
