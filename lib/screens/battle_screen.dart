import 'package:flutter/material.dart';
import '../models/creature.dart';
import '../models/move.dart';
import '../models/wild_encounter.dart';
import '../services/battle_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pixel_button.dart';
import '../widgets/type_badge.dart';

/// Schermata di battaglia: il proprio Pokemon (già catturato) affronta
/// una creatura selvatica appena fotografata. Il giocatore può
/// attaccare per indebolirla (aumentando le chance di cattura) oppure
/// tentare la cattura in qualunque momento — esattamente come nel
/// ciclo classico "indebolisci poi lancia la pokeball".
class BattleScreen extends StatefulWidget {
  final Creature ownCreature;
  final WildEncounter initialWild;

  const BattleScreen({
    super.key,
    required this.ownCreature,
    required this.initialWild,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  final _engine = BattleEngine();
  late WildEncounter _wild;
  late int _ownHp;
  String _log = 'Una creatura selvatica appare!';
  bool _busy = false;
  bool _battleOver = false;

  @override
  void initState() {
    super.initState();
    _wild = widget.initialWild;
    _ownHp = widget.ownCreature.computeStats().maxHp;
  }

  Future<void> _useMove(Move move) async {
    if (_busy || _battleOver) return;
    setState(() => _busy = true);

    final result = _engine.attackWild(
      attacker: widget.ownCreature,
      target: _wild,
      move: move,
    );

    setState(() {
      if (!result.hit) {
        _log = '${widget.ownCreature.nickname} usa ${move.name}... ma fallisce!';
      } else {
        _wild = _wild.copyWith(
          currentHp: (_wild.currentHp - result.damage).clamp(0, _wild.maxHp),
        );
        _log = '${widget.ownCreature.nickname} usa ${move.name}! '
            '${result.damage} danni.';
      }
    });

    if (_wild.currentHp <= 0) {
      setState(() {
        _log = 'La creatura selvatica è esausta! Ora è più facile catturarla.';
        _battleOver = true;
        _busy = false;
      });
      return;
    }

    // Contrattacco della creatura selvatica.
    await Future.delayed(const Duration(milliseconds: 500));
    if (_wild.moves.isEmpty) {
      setState(() => _busy = false);
      return;
    }
    final wildMove = _wild.moves[(_wild.moves.length > 1) ? 1 : 0];
    final counter = _engine.attackOwn(
      attacker: _wild,
      target: widget.ownCreature,
      move: wildMove,
    );

    setState(() {
      if (counter.hit) {
        _ownHp = (_ownHp - counter.damage).clamp(0, widget.ownCreature.computeStats().maxHp);
        _log += '\nLa creatura selvatica risponde con ${wildMove.name}! '
            '${counter.damage} danni a ${widget.ownCreature.nickname}.';
      }
      _busy = false;
      if (_ownHp <= 0) {
        _battleOver = true;
        _log += '\n${widget.ownCreature.nickname} non può più combattere!';
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
          ? 'Cattura riuscita! (probabilità era ${(probability * 100).round()}%)'
          : 'La creatura è scappata! (probabilità era ${(probability * 100).round()}%)';
    });

    // TODO: se success, qui va invocata la logica che trasforma la
    // WildEncounter in una vera Creature (nuovo EvolutionPlan,
    // moveset iniziale) e la salva su Supabase.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BATTAGLIA')),
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _WildHpBar(wild: _wild),
                const SizedBox(height: 10),
                _OwnHpBar(
                  creature: widget.ownCreature,
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
                    children: widget.ownCreature.moves
                        .map((m) => PixelButton(
                              label: m.move.name.toUpperCase(),
                              background: AppColors.sapphireBlue,
                              onPressed: _busy ? null : () => _useMove(m.move),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  PixelButton(
                    label: 'TENTA CATTURA',
                    background: AppColors.grassGreen,
                    icon: Icons.catching_pokemon,
                    onPressed: _busy ? null : _attemptCatch,
                  ),
                ] else
                  PixelButton(
                    label: 'CHIUDI',
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
      title: 'Selvatico · Lv.${wild.level}',
      types: wild.types,
      current: wild.currentHp,
      max: wild.maxHp,
    );
  }
}

class _OwnHpBar extends StatelessWidget {
  final Creature creature;
  final int currentHp;
  const _OwnHpBar({required this.creature, required this.currentHp});

  @override
  Widget build(BuildContext context) {
    return _HpRow(
      title: '${creature.nickname} · Lv.${creature.level}',
      types: creature.types,
      current: currentHp,
      max: creature.computeStats().maxHp,
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
        : (fraction > 0.2 ? const Color(0xFFE0A62B) : AppColors.rubyRed);

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
          Text('$current / $max PS', style: AppFonts.body(fontSize: 13)),
        ],
      ),
    );
  }
}
