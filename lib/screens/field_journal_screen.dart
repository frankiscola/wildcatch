import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wildkin.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/type_badge.dart';
import '../widgets/sprite_image.dart';
import '../providers/capture_flow_provider.dart';
import 'result_screen.dart';

class FieldJournalScreen extends ConsumerWidget {
  const FieldJournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wildkinAsync = ref.watch(myWildkinProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('FIELD JOURNAL')),
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: wildkinAsync.when(
              data: (wildkinList) {
                if (wildkinList.isEmpty) {
                  return const Center(
                    child: GbaDialogBox(
                      text: 'You haven\'t caught any Wildkin yet. '
                          'Head back to the menu and take your first photo!',
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
                  itemCount: wildkinList.length,
                  itemBuilder: (context, index) =>
                      _WildkinCard(wildkin: wildkinList[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: GbaDialogBox(
                  text: 'Could not load the Field Journal: $error',
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

class _WildkinCard extends StatelessWidget {
  final Wildkin wildkin;

  const _WildkinCard({required this.wildkin});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultScreen(wildkin: wildkin)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panelCream,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: SpriteImage(url: wildkin.frontSpriteUrl),
            ),
            const SizedBox(height: 6),
            Text(
              wildkin.nickname,
              style: AppFonts.pixelTitle(fontSize: 9, color: AppColors.panelBrown),
            ),
            const SizedBox(height: 4),
            TypeBadgeRow(types: wildkin.types),
          ],
        ),
      ),
    );
  }
}
