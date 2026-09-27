import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/location_prompt_dialog.dart';
import 'battle_online_screen.dart';
import 'capture_screen.dart';
import 'collection_screen.dart';
import 'field_journal_screen.dart';
import 'team_screen.dart';

/// Root navigation shell: a colorful bottom bar with four tabs
/// (Journal, Collection, Team, Online Battle) and a circular button
/// docked in the notch at the center that opens a new capture.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;
  final _locationService = LocationService();

  static const _tabs = [
    FieldJournalScreen(),
    CollectionScreen(),
    TeamScreen(),
    BattleOnlineScreen(),
  ];

  static const _tabSpecs = [
    _TabSpec(icon: Icons.menu_book, label: 'JOURNAL', color: AppColors.tidalBlue),
    _TabSpec(icon: Icons.style, label: 'COLLECTION', color: AppColors.grassGreen),
    _TabSpec(icon: Icons.groups, label: 'TEAM', color: AppColors.captureOrbGold),
    _TabSpec(icon: Icons.bolt, label: 'ONLINE', color: AppColors.emberRed),
  ];

  /// Same GPS pre-check that used to live in the old HomeScreen: the
  /// whole capture pipeline depends on location (weather lookup,
  /// biome estimate, type assignment), so it's better to catch this
  /// here than let it fail deep inside the capture flow.
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
      body: IndexedStack(index: _tabIndex, children: _tabs),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _CaptureFab(onTap: _startNewCapture),
      bottomNavigationBar: _BottomNavBar(
        specs: _tabSpecs,
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
      ),
    );
  }
}

class _TabSpec {
  final IconData icon;
  final String label;
  final Color color;
  const _TabSpec({required this.icon, required this.label, required this.color});
}

/// The circular button that protrudes above the bottom bar, styled
/// with the app's cool→warm brand gradient — deliberately bigger and
/// higher than a normal FAB so it reads as the app's primary action,
/// not just one more nav icon.
class _CaptureFab extends StatelessWidget {
  final VoidCallback onTap;
  const _CaptureFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.brandGradient,
            border: Border.all(color: AppColors.panelCream, width: 5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 14,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.camera_alt,
            color: AppColors.panelCream,
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final List<_TabSpec> specs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.specs,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Split the tabs around the center notch: first half left, rest
    // right, so the FAB sits naturally in the middle regardless of
    // how many tabs there are.
    final left = specs.sublist(0, (specs.length / 2).ceil());
    final right = specs.sublist((specs.length / 2).ceil());

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 12,
        color: AppColors.panelBrown,
        height: 74,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < left.length; i++)
              _NavItem(
                spec: left[i],
                selected: currentIndex == i,
                onTap: () => onTap(i),
              ),
            const SizedBox(width: 76), // room for the notch/FAB
            for (var i = 0; i < right.length; i++)
              _NavItem(
                spec: right[i],
                selected: currentIndex == left.length + i,
                onTap: () => onTap(left.length + i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.spec, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? spec.color : Colors.transparent,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: spec.color.withValues(alpha: 0.55),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                spec.icon,
                size: 20,
                color: selected ? Colors.white : AppColors.textOnDark.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              spec.label,
              style: AppFonts.pixelTitle(
                fontSize: 6.5,
                color: selected ? spec.color : AppColors.textOnDark.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
