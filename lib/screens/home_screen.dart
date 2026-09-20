import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/pixel_button.dart';
import '../widgets/location_prompt_dialog.dart';
import 'capture_screen.dart';
import 'field_journal_screen.dart';
import 'help_screen.dart';
import 'team_screen.dart';
import 'tutorial_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _locationService = LocationService();

  /// Checks GPS before opening the camera at all: the whole capture
  /// pipeline depends on location (weather lookup, biome estimate,
  /// type assignment), so it's better to catch this here than let it
  /// fail deep inside the capture flow after the player has already
  /// gone through camera setup.
  Future<void> _startNewCapture() async {
    final enabled = await _locationService.isServiceEnabled();
    if (enabled) {
      _openCaptureScreen();
      return;
    }

    if (!mounted) return;
    final enabledNow = await showLocationRequiredDialog(context);
    if (enabledNow && mounted) {
      _openCaptureScreen();
    }
  }

  void _openCaptureScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CaptureScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: const Text('WILDKIN'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TitleLockup(),
                Spacer(),
                const SizedBox(height: 56),
                PixelButton(
                  label: 'NEW CAPTURE',
                  icon: Icons.camera_alt,
                  onPressed: _startNewCapture,
                ),
                const SizedBox(height: 18),
                PixelButton(
                  label: 'MY FIELD JOURNAL',
                  icon: Icons.menu_book,
                  background: AppColors.tidalBlue,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const FieldJournalScreen()),
                  ),
                ),
                const SizedBox(height: 18),
                PixelButton(
                  label: 'MY TEAM',
                  icon: Icons.groups,
                  background: AppColors.grassGreen,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TeamScreen()),
                  ),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  icon: const Icon(Icons.play_circle_outline,
                      color: AppColors.panelBrown),
                  label: Text(
                    'How does it work?',
                    style: AppFonts.body(
                        color: AppColors.panelBrown, fontSize: 15),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TutorialScreen()),
                  ),
                ),
                Spacer(),
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
        Image.asset(
          'assets/branding/wordmark.png',
          width: 220,
          fit: BoxFit.contain,
        ),
        // Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        //   decoration: BoxDecoration(
        //     color: AppColors.panelCream,
        //     borderRadius: BorderRadius.circular(24),
        //     boxShadow: const [
        //       BoxShadow(
        //         color: AppColors.shadowSoft,
        //         blurRadius: 14,
        //         offset: Offset(0, 8),
        //       ),
        //     ],
        //   ),
        //   child: Column(
        //     children: [
        //       Image.asset(
        //         'assets/branding/wordmark.png',
        //         width: 220,
        //         fit: BoxFit.contain,
        //       ),
        //       const SizedBox(height: 6),
        //       Text(
        //         'edition',
        //         style: AppFonts.body(fontSize: 18, color: AppColors.tidalBlue),
        //       ),
        //     ],
        //   ),
        // ),
        // const SizedBox(height: 14),
        Text(
          'Photograph an animal.\nDiscover the Wildkin hiding within.',
          textAlign: TextAlign.center,
          style: AppFonts.body(fontSize: 18, color: AppColors.panelBrown),
        ),
      ],
    );
  }
}
