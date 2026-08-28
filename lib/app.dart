import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

class WildcatchApp extends StatelessWidget {
  const WildcatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wildcatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
