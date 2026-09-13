import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/app_gate.dart';

class WildkinApp extends StatelessWidget {
  const WildkinApp({super.key});

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
