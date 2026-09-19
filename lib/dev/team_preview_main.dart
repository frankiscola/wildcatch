// LOCAL PREVIEW ONLY — never referenced by the real app (main.dart).
// Lets you look at TeamScreen/ResultScreen with 3 sample Wildkin
// without a working Supabase project, by overriding myWildkinProvider
// instead of hitting the network.
//
// Run from the project root:
//   flutter run -t lib/dev/team_preview_main.dart
//
// Needs the 6 images to already be sitting in dev_preview_assets/
// at the project root (cat.webp, cat_back.webp, parrot.webp,
// parrot_back.webp, worm.webp, worm_back.webp) — NOT registered in
// pubspec.yaml, loaded straight off disk via Image.file, so nothing
// here gets bundled into a real build.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/capture_flow_provider.dart';
import '../screens/team_screen.dart';
import '../theme/app_theme.dart';
import 'sample_wildkin.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        myWildkinProvider.overrideWith((ref) async {
          // Tiny artificial delay so the loading state is visible
          // too, same as it would be against a real network call.
          await Future.delayed(const Duration(milliseconds: 300));
          return buildSampleWildkin();
        }),
      ],
      child: const _PreviewApp(),
    ),
  );
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wildkin — Team preview',
      theme: AppTheme.light,
      home: const TeamScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
