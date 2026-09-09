import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'tutorial_screen.dart';

/// Primo widget mostrato all'avvio: controlla se il tutorial è già
/// stato visto (persistito con shared_preferences) e decide se
/// mostrarlo o andare dritto alla home. Il controllo è quasi
/// istantaneo, ma essendo comunque asincrono serve un piccolo stato
/// di caricamento per evitare un frame vuoto.
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
