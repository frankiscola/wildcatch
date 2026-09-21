import 'package:supabase_flutter/supabase_flutter.dart';
// NOTE: `LaunchMode` below is the url_launcher enum, re-exported by
// supabase_flutter for exactly this parameter. If your analyzer
// can't find it, add `url_launcher: ^6.0.0` to pubspec.yaml and
// `import 'package:url_launcher/url_launcher.dart';` here.

/// Upgrades the existing anonymous Supabase account to a Google
/// account, WITHOUT losing any data: same `auth.uid()`, so every
/// captured Wildkin stays exactly where it is. This is deliberately
/// not a "log out and sign in again" flow — the app should stay
/// playable with zero friction (anonymous by default), and Google
/// Sign-In is only offered as an optional "save your progress" step.
///
/// Uses Supabase's own browser-based OAuth (`linkIdentity`/
/// `signInWithOAuth`) instead of the native google_sign_in package:
/// no per-platform client ID, no SHA-1 fingerprint, no ID-token/
/// access-token juggling — just one Google OAuth client (type "Web
/// application") configured directly in the Supabase dashboard. The
/// trade-off is a browser tab opens for a moment instead of the
/// native account picker.
///
/// Setup required (see README for the full checklist):
///  1. Google Cloud Console: one OAuth client, type "Web application".
///  2. Supabase dashboard -> Authentication -> Providers -> Google:
///     paste that client's ID + secret.
///  3. Supabase dashboard -> Authentication -> URL Configuration ->
///     Redirect URLs: add `io.wildkin.app://login-callback/**`.
///  4. "Enable Manual Linking" turned on (Authentication -> Settings)
///     — required for [linkToCurrentUser], not for [signIn].
///  5. The matching scheme is already declared in AndroidManifest.xml
///     and Info.plist (see the diffs in this same delivery).
class GoogleAuthService {
  static const _redirectUrl = 'io.wildkin.app://login-callback';

  SupabaseClient get _client => Supabase.instance.client;

  /// Links a Google identity to the CURRENT (anonymous) user. Opens a
  /// browser tab; the app regains control via the deep link once the
  /// user finishes signing in with Google. [AccountScreen] listens to
  /// `onAuthStateChange` to update itself when that happens — this
  /// method itself returns as soon as the browser is launched, not
  /// once linking is actually confirmed.
  Future<void> linkToCurrentUser() async {
    await _client.auth.linkIdentity(
      OAuthProvider.google,
      redirectTo: _redirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Signs into an existing Google-linked account, replacing whatever
  /// session (anonymous or not) is currently active — for recovering
  /// an account on a new device/reinstall, same idea as
  /// EmailAuthService.signIn.
  Future<void> signIn() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }
}
