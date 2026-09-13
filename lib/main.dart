import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: put your real credentials in
  // lib/services/supabase_service.dart before running the app,
  // otherwise initialization will fail.
  await SupabaseService.initialize();

  // The generate-wildkin edge function requires an authenticated
  // user (RLS policies rely on auth.uid()). For the MVP we use
  // Supabase's anonymous sign-in: it still creates a real row in
  // auth.users with a stable id for the device, without requiring
  // login/sign-up. Must be enabled in the Supabase dashboard under
  // Authentication -> Providers -> Anonymous Sign-Ins.
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession == null) {
    await auth.signInAnonymously();
  }

  runApp(const ProviderScope(child: WildkinApp()));
}
