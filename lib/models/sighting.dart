/// Result of recording the FIRST sighting (see
/// resolve-sighting/index.ts, function record-sighting).
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

/// Reasons the confirmation of the second sighting can be rejected
/// by the server. Kept as an enum (instead of scattered strings) so
/// it's easier to show consistent user-facing messages across the app.
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

  /// User-facing message, styled consistently with the rest of the
  /// UI (see GbaDialogBox).
  String get userMessage {
    switch (this) {
      case SightingRejectionReason.expired:
        return 'Too much time has passed since the first sighting: spot the animal again before taking the shot.';
      case SightingRejectionReason.tooFar:
        return 'This spot is too far from the first sighting: it needs to be the same animal, not too far away.';
      case SightingRejectionReason.speciesMismatch:
        return 'This looks like a different animal from the one first spotted.';
      case SightingRejectionReason.duplicateImage:
        return 'This photo looks identical to the previous one: try photographing it again live, maybe from another angle.';
      case SightingRejectionReason.suspiciousDuplicateOfOtherUser:
        return 'This image looks like it\'s already been seen elsewhere: make sure you\'re photographing a real animal in front of you.';
      case SightingRejectionReason.unknown:
        return 'The sighting could not be confirmed. Please try again.';
    }
  }
}

class SightingRejectedException implements Exception {
  final SightingRejectionReason reason;
  const SightingRejectedException(this.reason);

  @override
  String toString() => reason.userMessage;
}
