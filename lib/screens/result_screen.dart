import 'package:flutter/material.dart';
import '../models/creature.dart';
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

    return Scaffold(
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      GbaDialogBox(
                        text: 'Congratulazioni! Hai catturato una nuova creatura!',
                        fontSize: 16,
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _SpriteStage(
                        creature: creature,
                        showFront: _showFront,
                      )),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => setState(() => _showFront = !_showFront),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.panelCream,
                            border: Border.all(
                                color: AppColors.dialogBorderOuter, width: 2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flip, size: 16, color: AppColors.panelBrown),
                              const SizedBox(width: 8),
                              Text(
                                _showFront
                                    ? 'MOSTRA VISTA BATTAGLIA (RETRO)'
                                    : 'MOSTRA VISTA POKEDEX (FRONTE)',
                                style: AppFonts.pixelTitle(
                                  fontSize: 9,
                                  color: AppColors.panelBrown,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TypeBadgeRow(types: creature.types),
                      const SizedBox(height: 12),
                      _ContextSummary(creature: creature),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
      decoration: BoxDecoration(
        color: AppColors.panelCream,
        border: Border.all(color: AppColors.dialogBorderOuter, width: 4),
      ),
      padding: const EdgeInsets.all(16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Image.network(
          spriteUrl,
          key: ValueKey(spriteUrl),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(Icons.image_not_supported,
                size: 48, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

/// Riepilogo delle condizioni di cattura, come una piccola scheda
/// "meteo" nel taccuino del Pokedex.
class _ContextSummary extends StatelessWidget {
  final Creature creature;

  const _ContextSummary({required this.creature});

  @override
  Widget build(BuildContext context) {
    final ctx = creature.context;
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.panelBrown,
                  border: Border.all(color: AppColors.dialogBorderOuter, width: 1.5),
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
