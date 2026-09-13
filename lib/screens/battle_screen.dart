import 'package:flutter/material.dart';
import '../models/wildkin.dart';
import '../models/move.dart';
import '../models/wild_encounter.dart';
import '../services/battle_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pixel_button.dart';
import '../widgets/type_badge.dart';

/// Battle screen: the player's own Wildkin (already captured) faces
/// a wild Wildkin that was just photographed. The player can attack
/// to weaken it (raising the capture odds) or attempt a capture at
/// any time — the classic "weaken it, then try to catch it" loop.
class BattleScreen extends StatefulWidget {
  final Wildkin ownWildkin;
  final WildEncounter initialWild;

  const BattleScreen({
    super.key,
    required this.ownWildkin,
    required this.initialWild,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  final _engine = BattleEngine();
  late WildEncounter _wild;
  late int _ownHp;
  String _log = 'A wild Wildkin appears!';
  bool _busy = false;
  bool _battleOver = false;

  @override
  void initState() {
    super.initState();
    _wild = widget.initialWild;
    _ownHp = widget.ownWildkin.computeStats().maxHp;
  }

  Future<void> _useMove(Move move) async {
    if (_busy || _battleOver) return;
    setState(() => _busy = true);

    final result = _engine.attackWild(
      attacker: widget.ownWildkin,
      target: _wild,
      move: move,
    );

    setState(() {
      if (!result.hit) {
        _log = '${widget.ownWildkin.nickname} uses ${move.name}... but it misses!';
      } else {
        _wild = _wild.copyWith(
          currentHp: (_wild.currentHp - result.damage).clamp(0, _wild.maxHp),
        );
        _log = '${widget.ownWildkin.nickname} uses ${move.name}! '
            '${result.damage} damage.';
        if (result.effectivenessMessage != null) {
          _log += '\n${result.effectivenessMessage}';
        }
      }
    });

    if (_wild.currentHp <= 0) {
      setState(() {
        _log = 'The wild Wildkin is worn out! It should be easier to catch now.';
        _battleOver = true;
        _busy = false;
      });
      return;
    }

    // The wild Wildkin counterattacks.
    await Future.delayed(const Duration(milliseconds: 500));
    if (_wild.moves.isEmpty) {
      setState(() => _busy = false);
      return;
    }
    final wildMove = _wild.moves[(_wild.moves.length > 1) ? 1 : 0];
    final counter = _engine.attackOwn(
      attacker: _wild,
      target: widget.ownWildkin,
      move: wildMove,
    );

    setState(() {
      if (counter.hit) {
        _ownHp = (_ownHp - counter.damage).clamp(0, widget.ownWildkin.computeStats().maxHp);
        _log += '\nThe wild Wildkin strikes back with ${wildMove.name}! '
            '${counter.damage} damage to ${widget.ownWildkin.nickname}.';
        if (counter.effectivenessMessage != null) {
          _log += '\n${counter.effectivenessMessage}';
        }
      }
      _busy = false;
      if (_ownHp <= 0) {
        _battleOver = true;
        _log += '\n${widget.ownWildkin.nickname} can no longer battle!';
      }
    });
  }

  void _attemptCatch() {
    if (_busy) return;
    final probability = _engine.catchProbability(_wild);
    final success = _engine.attemptCatch(_wild);

    setState(() {
      _battleOver = true;
      _log = success
          ? 'Capture successful! (odds were ${(probability * 100).round()}%)'
          : 'The Wildkin got away! (odds were ${(probability * 100).round()}%)';
    });

    // TODO: on success, this is where the logic that turns the
    // WildEncounter into a real Wildkin (new EvolutionPlan, starter
    // moveset) and saves it to Supabase should be invoked.
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
                _OwnHpBar(
                  wildkin: widget.ownWildkin,
                  currentHp: _ownHp,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GbaDialogBox(text: _log, fontSize: 16),
                ),
                const SizedBox(height: 16),
                if (!_battleOver) ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: widget.ownWildkin.moves
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
                    label: 'CLOSE',
                    onPressed: () => Navigator.of(context).pop(),
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
  final int currentHp;
  const _OwnHpBar({required this.wildkin, required this.currentHp});

  @override
  Widget build(BuildContext context) {
    return _HpRow(
      title: '${wildkin.nickname} · Lv.${wildkin.level}',
      types: wildkin.types,
      current: currentHp,
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
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 4)),
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
                Container(height: 12, color: AppColors.dialogBorderOuter.withOpacity(0.12)),
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
