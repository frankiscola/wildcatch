import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/capture_context.dart';
import '../models/wildkin.dart';
import '../models/sighting.dart';

/// Single point of access to Supabase: initialization, uploading the
/// original photo, and invoking the edge function that generates the
/// Wildkin (front/back sprites + assigned type).
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Call once in main() before runApp().
  /// Credentials for the "wildkin" Supabase project (ref
  /// ffwfyhdorffzzbyvtlpv). Note: the anon key is public by design
  /// (protected by RLS policies, not by secrecy), but if you publish
  /// this repo it's still good habit to avoid committing keys in
  /// plain text — prefer --dart-define or a .env file.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://ffwfyhdorffzzbyvtlpv.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmd2Z5aGRvcmZmenpieXZ0bHB2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgwOTc0MjYsImV4cCI6MjEwMzY3MzQyNn0.aK-34x9Vpe6uOJOLCE2mQkShhD9PLqsMiTWNHmGfu6Q',
    );
  }

  /// Uploads the captured photo to the 'captures' storage bucket and
  /// returns the path of the uploaded file.
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

  /// Invokes the 'generate-wildkin' edge function, the "direct" path
  /// (no double sighting). The normal UI no longer uses this from
  /// here on: the capture flow now goes through recordSighting +
  /// confirmSighting (mechanism 5). Still kept available for manual
  /// testing from the terminal (see README) and as a reference for
  /// the shared logic that now lives server-side in
  /// supabase/functions/_shared/finalize_capture.ts.
  Future<Wildkin> generateWildkin({
    required String originalPhotoUrl,
    required CaptureContext context,
  }) async {
    final response = await client.functions.invoke(
      'generate-wildkin',
      body: {
        'original_photo_url': originalPhotoUrl,
        'context': context.toJson(),
      },
    );

    if (response.status != 200) {
      throw SupabaseServiceException(
        'Generation failed (status ${response.status}).',
      );
    }

    return Wildkin.fromJson(response.data as Map<String, dynamic>);
  }

  /// Mechanism 5 (double sighting), first step: records the first
  /// shot as a "sighting" awaiting confirmation, WITHOUT generating a
  /// Wildkin yet. The server computes the photo's perceptual hash and
  /// checks whether it suspiciously matches photos already seen from
  /// other users (see resolve-sighting/index.ts).
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
        'Could not record the sighting (status ${response.status}).',
      );
    }

    return SightingRecorded.fromJson(response.data as Map<String, dynamic>);
  }

  /// Mechanism 5, second step: confirms the previous sighting with a
  /// second photo. If the server finds it plausible that this is the
  /// same real animal seen again shortly after (GPS proximity, time
  /// elapsed, image similar-but-not-identical), it finalizes the
  /// capture and returns the complete Wildkin.
  ///
  /// Throws [SightingRejectedException] if the server rejects the
  /// confirmation, with a reason already prepared to show the player
  /// (see SightingRejectionReason.userMessage).
  Future<Wildkin> confirmSighting({
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
        'Sighting confirmation failed (status ${response.status}).',
      );
    }

    return Wildkin.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fetches all the Wildkin caught by the current user, to populate
  /// the personal Field Journal.
  Future<List<Wildkin>> getMyWildkin() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await client
        .from('captures')
        .select()
        .eq('user_id', userId)
        .order('captured_at', ascending: false);

    return (rows as List)
        .map((row) => Wildkin.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Updates the nickname of an already-saved Wildkin. Used right
  /// after capture to replace the '???' placeholder with the name
  /// generated client-side (NameGenerator), combining the
  /// on-device-detected species with the type just assigned by the
  /// server.
  Future<Wildkin> renameWildkin({
    required String id,
    required String nickname,
  }) async {
    final row = await client
        .from('captures')
        .update({'nickname': nickname})
        .eq('id', id)
        .select()
        .single();

    return Wildkin.fromJson(row);
  }

  /// Persists a Wildkin's state after a won battle: level,
  /// experience, HP, and possibly updated type/stats/moves if an
  /// evolution triggered (see LevelingService).
  Future<Wildkin> updateAfterBattle(Wildkin wildkin) async {
    final row = await client
        .from('captures')
        .update({
          'level': wildkin.level,
          'current_exp': wildkin.currentExp,
          'current_hp': wildkin.currentHp,
          'assigned_type': wildkin.types,
          'base_stats': wildkin.baseStats.toJson(),
          'moves': wildkin.moves
              .map((m) => {'move': m.move.toJson(), 'current_pp': m.currentPp})
              .toList(),
          'evolution_plan': wildkin.evolutionPlan.toJson(),
          if (wildkin.evolutionContext != null)
            'evolution_context': {
              'captured_at':
                  wildkin.evolutionContext!.capturedAt.toIso8601String(),
              'latitude': wildkin.evolutionContext!.latitude,
              'longitude': wildkin.evolutionContext!.longitude,
              'elevation_m': wildkin.evolutionContext!.elevationMeters,
              'weather_condition': wildkin.evolutionContext!.weatherCondition,
              'temperature_c': wildkin.evolutionContext!.temperatureCelsius,
              'humidity_percent': wildkin.evolutionContext!.humidityPercent,
              'wind_speed_kmh': wildkin.evolutionContext!.windSpeedKmh,
            },
        })
        .eq('id', wildkin.id)
        .select()
        .single();

    return Wildkin.fromJson(row);
  }
}

class SupabaseServiceException implements Exception {
  final String message;
  SupabaseServiceException(this.message);

  @override
  String toString() => message;
}
