import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'services/supabase_service.dart';
import 'services/purchases_service.dart';

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

  // RevenueCat must be configured before any screen can read
  // entitlements or offerings, and logged in as the SAME id Supabase
  // uses — that's what lets revenuecat-webhook/index.ts write to the
  // right `profiles` row when a purchase comes in.
  await PurchasesService.configure();
  final initialUserId = auth.currentUser?.id;
  if (initialUserId != null) {
    await PurchasesService.logIn(initialUserId);
  }

  // auth.uid() isn't necessarily permanent: linking an email to an
  // anonymous session keeps the same id, but RECOVERING an existing
  // account on a new device switches to that account's id instead
  // (see email_auth_service.dart). Whenever that happens, RevenueCat
  // needs to be told, or it would keep tracking entitlements under
  // the old, now-abandoned id.
  auth.onAuthStateChange.listen((event) {
    final userId = event.session?.user.id;
    if (userId != null) {
      PurchasesService.logIn(userId);
    }
  });

  runApp(const ProviderScope(child: WildkinApp()));
}
