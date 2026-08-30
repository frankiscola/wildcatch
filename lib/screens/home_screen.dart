import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/pixel_button.dart';
import 'capture_screen.dart';
import 'pokedex_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TitleLockup(),
                const SizedBox(height: 56),
                PixelButton(
                  label: 'NUOVA CATTURA',
                  icon: Icons.camera_alt,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CaptureScreen()),
                  ),
                ),
                const SizedBox(height: 18),
                PixelButton(
                  label: 'IL MIO POKEDEX',
                  icon: Icons.menu_book,
                  background: AppColors.sapphireBlue,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PokedexScreen()),
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

class _TitleLockup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.panelCream,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'WILDCATCH',
                style: AppFonts.pixelTitle(
                  fontSize: 22,
                  color: AppColors.rubyRed,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'edition',
                style: AppFonts.body(fontSize: 18, color: AppColors.sapphireBlue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Fotografa un animale.\nScopri la creatura che nasconde.',
          textAlign: TextAlign.center,
          style: AppFonts.body(fontSize: 18, color: AppColors.panelBrown),
        ),
      ],
    );
  }
}
