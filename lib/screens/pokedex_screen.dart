import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/creature.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/type_badge.dart';
import '../providers/capture_flow_provider.dart';
import 'result_screen.dart';

class PokedexScreen extends ConsumerWidget {
  const PokedexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creaturesAsync = ref.watch(myCreaturesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('POKEDEX')),
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: creaturesAsync.when(
              data: (creatures) {
                if (creatures.isEmpty) {
                  return const Center(
                    child: GbaDialogBox(
                      text: 'Non hai ancora catturato nessuna creatura. '
                          'Torna al menu e scatta la tua prima foto!',
                      fontSize: 16,
                    ),
                  );
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: creatures.length,
                  itemBuilder: (context, index) =>
                      _CreatureCard(creature: creatures[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: GbaDialogBox(
                  text: 'Impossibile caricare il Pokedex: $error',
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatureCard extends StatelessWidget {
  final Creature creature;

  const _CreatureCard({required this.creature});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultScreen(creature: creature)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panelCream,
          border: Border.all(color: AppColors.dialogBorderOuter, width: 3),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(
              child: Image.network(
                creature.frontSpriteUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.image_not_supported, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              creature.nickname,
              style: AppFonts.pixelTitle(fontSize: 9, color: AppColors.panelBrown),
            ),
            const SizedBox(height: 4),
            TypeBadgeRow(types: creature.types),
          ],
        ),
      ),
    );
  }
}
