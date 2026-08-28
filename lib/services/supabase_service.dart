import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/capture_context.dart';
import '../models/creature.dart';

/// Punto unico di accesso a Supabase: inizializzazione, upload
/// della foto originale e invocazione della edge function che
/// genera la creatura (sprite fronte/retro + tipo assegnato).
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Da chiamare una sola volta in main() prima di runApp().
  /// TODO: sostituire con le tue vere credenziali del progetto
  /// Supabase (Settings -> API nel dashboard). Non committare
  /// la chiave anon in chiaro in repository pubblici: usa
  /// --dart-define o un file .env escluso da git.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://YOUR_PROJECT_REF.supabase.co',
      anonKey: 'YOUR_SUPABASE_ANON_KEY',
    );
  }

  /// Carica la foto scattata nello storage bucket 'captures'
  /// e restituisce il path del file caricato.
  Future<String> uploadOriginalPhoto({
    required String userId,
    required Uint8List photoBytes,
  }) async {
    final fileName =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await client.storage.from('captures').uploadBinary(
          fileName,
          photoBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    return client.storage.from('captures').getPublicUrl(fileName);
  }

  /// Invoca la edge function 'generate-creature', che si occupa di:
  /// 1. determinare il tipo tramite il motore di regole lato server
  /// 2. chiamare il servizio di generazione immagini per fronte/retro
  /// 3. salvare il record nella tabella 'captures'
  /// 4. restituire la creatura completa
  Future<Creature> generateCreature({
    required String originalPhotoUrl,
    required CaptureContext context,
  }) async {
    final response = await client.functions.invoke(
      'generate-creature',
      body: {
        'original_photo_url': originalPhotoUrl,
        'context': context.toJson(),
      },
    );

    if (response.status != 200) {
      throw SupabaseServiceException(
        'Generazione fallita (status ${response.status}).',
      );
    }

    return Creature.fromJson(response.data as Map<String, dynamic>);
  }

  /// Recupera tutte le creature catturate dall'utente corrente,
  /// per popolare il "pokedex" personale.
  Future<List<Creature>> getMyCreatures() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await client
        .from('captures')
        .select()
        .eq('user_id', userId)
        .order('captured_at', ascending: false);

    return (rows as List)
        .map((row) => Creature.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}

class SupabaseServiceException implements Exception {
  final String message;
  SupabaseServiceException(this.message);

  @override
  String toString() => message;
}
