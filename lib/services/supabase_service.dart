import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/capture_context.dart';
import '../models/creature.dart';
import '../models/sighting.dart';

/// Punto unico di accesso a Supabase: inizializzazione, upload
/// della foto originale e invocazione della edge function che
/// genera la creatura (sprite fronte/retro + tipo assegnato).
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Da chiamare una sola volta in main() prima di runApp().
  /// Credenziali del progetto Supabase "wildcatch" (ref
  /// ffwfyhdorffzzbyvtlpv). Attenzione: la anon key è pubblica per
  /// design (protetta dalle policy RLS, non da segretezza), ma se
  /// pubblichi questo repo evita comunque di versionare chiavi in
  /// chiaro per abitudine — meglio --dart-define o un file .env.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://ffwfyhdorffzzbyvtlpv.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmd2Z5aGRvcmZmenpieXZ0bHB2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgwOTc0MjYsImV4cCI6MjEwMzY3MzQyNn0.aK-34x9Vpe6uOJOLCE2mQkShhD9PLqsMiTWNHmGfu6Q',
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

  /// Invoca la edge function 'generate-creature', percorso "diretto"
  /// (nessun doppio avvistamento). Da qui in poi la UI normale NON la
  /// usa più: il flusso di cattura passa da recordSighting +
  /// confirmSighting (meccanismo 5). La teniamo comunque disponibile
  /// per test manuali da terminale (vedi README) e come riferimento
  /// per la logica condivisa che ora vive lato server in
  /// supabase/functions/_shared/finalize_capture.ts.
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

  /// Meccanismo 5 (doppio avvistamento), primo passo: registra il
  /// primo scatto come "avvistamento" in attesa di conferma, SENZA
  /// ancora generare una creatura. Il server calcola l'hash percettivo
  /// della foto e controlla se combacia in modo sospetto con foto già
  /// viste da altri utenti (vedi resolve-sighting/index.ts).
  Future<SightingRecorded> recordSighting({
    required String originalPhotoUrl,
    required CaptureContext context,
    String? speciesHint,
  }) async {
    final response = await client.functions.invoke(
      'resolve-sighting',
      body: {
        'action': 'record',
        'original_photo_url': originalPhotoUrl,
        'context': context.toJson(),
        'species_hint': speciesHint,
      },
    );

    if (response.status != 200) {
      throw SupabaseServiceException(
        'Impossibile registrare l\'avvistamento (status ${response.status}).',
      );
    }

    return SightingRecorded.fromJson(response.data as Map<String, dynamic>);
  }

  /// Meccanismo 5, secondo passo: conferma l'avvistamento precedente
  /// con una seconda foto. Se il server ritiene plausibile che si
  /// tratti dello stesso animale reale rivisto poco dopo (vicinanza
  /// GPS, tempo trascorso, somiglianza-ma-non-identità dell'immagine),
  /// finalizza la cattura e restituisce la creatura completa.
  ///
  /// Lancia [SightingRejectedException] se il server rifiuta la
  /// conferma, con un motivo già pronto per essere mostrato
  /// all'utente (vedi SightingRejectionReason.userMessage).
  Future<Creature> confirmSighting({
    required String sightingId,
    required String originalPhotoUrl,
    required CaptureContext context,
    String? speciesHint,
  }) async {
    final response = await client.functions.invoke(
      'resolve-sighting',
      body: {
        'action': 'confirm',
        'sighting_id': sightingId,
        'original_photo_url': originalPhotoUrl,
        'context': context.toJson(),
        'species_hint': speciesHint,
      },
    );

    if (response.status == 409) {
      final data = response.data as Map<String, dynamic>?;
      final reason = SightingRejectionReason.fromCode(data?['reason'] as String?);
      throw SightingRejectedException(reason);
    }

    if (response.status != 200) {
      throw SupabaseServiceException(
        'Conferma avvistamento fallita (status ${response.status}).',
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

  /// Aggiorna il nickname di una creatura già salvata. Usato subito
  /// dopo la cattura per sostituire il placeholder '???' con il nome
  /// generato client-side (NameGenerator), combinando la specie
  /// rilevata su device col tipo appena assegnato dal server.
  Future<Creature> renameCreature({
    required String id,
    required String nickname,
  }) async {
    final row = await client
        .from('captures')
        .update({'nickname': nickname})
        .eq('id', id)
        .select()
        .single();

    return Creature.fromJson(row);
  }
}

class SupabaseServiceException implements Exception {
  final String message;
  SupabaseServiceException(this.message);

  @override
  String toString() => message;
}
