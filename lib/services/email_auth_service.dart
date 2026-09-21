import 'package:supabase_flutter/supabase_flutter.dart';

/// Email/password as a second optional "save your progress" path,
/// alongside Google (see google_auth_service.dart). Two different
/// operations, not to be confused with each other:
///
///  - [linkToCurrentUser]: the player is CURRENTLY anonymous and
///    wants to add an email+password to that same account (same
///    `auth.uid()`, same captures — nothing is lost).
///  - [signIn]: the player is recovering an account they created
///    earlier (e.g. after reinstalling the app, so they're back to a
///    brand-new anonymous session). This SWITCHES to the old
///    account/uid — anything captured under the current anonymous
///    session before signing in is left behind, which is the
///    expected trade-off of "log into my old account".
class EmailAuthService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Adds email+password to the current anonymous user. Supabase
  /// sends a confirmation email; until the player taps the link
  /// in it, `currentUser.email` stays unconfirmed and
  /// `currentUser.isAnonymous` stays true. No deep-link-back-into-the-app
  /// is wired up (see the note in AccountScreen), so the simplest
  /// flow is: confirm in the browser, then just reopen the app —
  /// Supabase revalidates the session on next launch.
  Future<void> linkToCurrentUser(String email, String password) async {
    await _client.auth.updateUser(
      UserAttributes(email: email, password: password),
    );
  }

  /// Signs into an existing email/password account, replacing
  /// whatever session (anonymous or not) is currently active.
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }
}
