import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'tutorial_screen.dart';

/// First widget shown at startup: checks whether the tutorial has
/// already been seen (persisted with shared_preferences) and decides
/// whether to show it or go straight to the home screen. The check
/// is nearly instant, but since it's still async a small loading
/// state is needed to avoid an empty frame.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool? _showTutorial;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('has_seen_tutorial') ?? false;
    if (mounted) setState(() => _showTutorial = !seen);
  }

  @override
  Widget build(BuildContext context) {
    final showTutorial = _showTutorial;
    if (showTutorial == null) {
      return const Scaffold(
        backgroundColor: AppColors.routeSkyBottom,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return showTutorial ? const TutorialScreen(isFirstLaunch: true) : const HomeScreen();
  }
}
