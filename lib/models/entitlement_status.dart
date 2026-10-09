/// Read-only snapshot of the player's monetization status, as
/// returned by the get-entitlements edge function. Shown in the UI
/// ("2 captures left today") — never used to gate anything itself,
/// since the server independently re-checks before spending any
/// real money (see entitlements.ts).
class EntitlementStatus {
  final bool isPremium;
  final DateTime? premiumExpiresAt;
  final int captureTokens;

  /// Null when premium (unlimited, not worth showing a number for).
  final int? freeCapturesRemaining;

  const EntitlementStatus({
    required this.isPremium,
    required this.premiumExpiresAt,
    required this.captureTokens,
    required this.freeCapturesRemaining,
  });

  /// true if the player can capture or reroll right now without
  /// buying anything — used to decide whether to even show a "running
  /// low" nudge in the UI.
  bool get hasAnyFreeOption =>
      isPremium || captureTokens > 0 || (freeCapturesRemaining ?? 0) > 0;

  factory EntitlementStatus.fromJson(Map<String, dynamic> json) {
    return EntitlementStatus(
      isPremium: json['is_premium'] as bool,
      premiumExpiresAt: json['premium_expires_at'] == null
          ? null
          : DateTime.parse(json['premium_expires_at'] as String),
      captureTokens: json['capture_tokens'] as int,
      freeCapturesRemaining: json['free_captures_remaining'] as int?,
    );
  }
}
