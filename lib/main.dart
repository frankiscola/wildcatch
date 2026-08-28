import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: inserisci le tue credenziali reali in
  // lib/services/supabase_service.dart prima di eseguire l'app,
  // altrimenti l'inizializzazione fallirà.
  await SupabaseService.initialize();

  runApp(const ProviderScope(child: WildcatchApp()));
}
