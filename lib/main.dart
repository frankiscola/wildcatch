import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: inserisci le tue credenziali reali in
  // lib/services/supabase_service.dart prima di eseguire l'app,
  // altrimenti l'inizializzazione fallirà.
  await SupabaseService.initialize();

  // L'edge function generate-creature richiede un utente autenticato
  // (le policy RLS si basano su auth.uid()). Per l'MVP usiamo il
  // sign-in anonimo di Supabase: crea comunque una riga vera in
  // auth.users con un id stabile per il dispositivo, senza chiedere
  // login/registrazione. Va abilitato nella dashboard Supabase in
  // Authentication -> Providers -> Anonymous Sign-Ins.
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession == null) {
    await auth.signInAnonymously();
  }

  runApp(const ProviderScope(child: WildcatchApp()));
}
