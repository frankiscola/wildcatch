import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/app_gate.dart';

class WildcatchApp extends StatelessWidget {
  const WildcatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WildKin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppGate(),
    );
  }
}
