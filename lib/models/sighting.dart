/// Esito della registrazione del PRIMO avvistamento (vedi
/// resolve-sighting/index.ts, funzione record-sighting).
class SightingRecorded {
  final String sightingId;
  final DateTime expiresAt;
  final double latitude;
  final double longitude;

  const SightingRecorded({
    required this.sightingId,
    required this.expiresAt,
    required this.latitude,
    required this.longitude,
  });

  factory SightingRecorded.fromJson(Map<String, dynamic> json) => SightingRecorded(
        sightingId: json['sighting_id'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}

/// Motivi per cui la conferma del secondo avvistamento può essere
/// rifiutata dal server. Tenerli come enum (invece di stringhe sparse)
/// rende più facile mostrare messaggi utente coerenti in tutta l'app.
enum SightingRejectionReason {
  expired,
  tooFar,
  speciesMismatch,
  duplicateImage,
  suspiciousDuplicateOfOtherUser,
  unknown;

  static SightingRejectionReason fromCode(String? code) {
    switch (code) {
      case 'expired':
        return SightingRejectionReason.expired;
      case 'too_far':
        return SightingRejectionReason.tooFar;
      case 'species_mismatch':
        return SightingRejectionReason.speciesMismatch;
      case 'duplicate_image':
        return SightingRejectionReason.duplicateImage;
      case 'suspicious_duplicate_of_other_user':
        return SightingRejectionReason.suspiciousDuplicateOfOtherUser;
      default:
        return SightingRejectionReason.unknown;
    }
  }

  /// Messaggio pensato per l'utente finale, in stile Pokédex/GBA
  /// coerente col resto della UI (vedi GbaDialogBox).
  String get userMessage {
    switch (this) {
      case SightingRejectionReason.expired:
        return 'Troppo tempo è passato dal primo avvistamento: individua di nuovo l\'animale prima di scattare.';
      case SightingRejectionReason.tooFar:
        return 'Questo punto è troppo lontano dal primo avvistamento: deve trattarsi dello stesso animale, non troppo lontano.';
      case SightingRejectionReason.speciesMismatch:
        return 'Questo sembra un animale diverso da quello avvistato per primo.';
      case SightingRejectionReason.duplicateImage:
        return 'Questa foto sembra identica alla precedente: prova a fotografarlo di nuovo dal vivo, magari da un\'altra angolazione.';
      case SightingRejectionReason.suspiciousDuplicateOfOtherUser:
        return 'Questa immagine sembra già vista altrove: assicurati di fotografare un animale reale davanti a te.';
      case SightingRejectionReason.unknown:
        return 'Non è stato possibile confermare l\'avvistamento. Riprova.';
    }
  }
}

class SightingRejectedException implements Exception {
  final SightingRejectionReason reason;
  const SightingRejectedException(this.reason);

  @override
  String toString() => reason.userMessage;
}
