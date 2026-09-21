import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pixel_button.dart';
import '../services/supabase_service.dart';
import '../services/google_auth_service.dart';
import '../services/email_auth_service.dart';

/// "Save your progress" screen: while the player is on the default
/// anonymous account, offers two optional ways to attach a real
/// identity to it — Google, or email+password — so the same Wildkin
/// can be recovered after a reinstall or on a new device.
/// Deliberately NOT shown anywhere in the main capture flow —
/// reachable from an icon in TeamScreen's AppBar, entirely optional.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

/// Which email form is showing: creating a fresh email/password for
/// the current anonymous account, or signing into one that already
/// exists (account recovery — see EmailAuthService.signIn).
enum _EmailMode { create, signIn }

class _AccountScreenState extends State<AccountScreen> {
  final _supabaseService = SupabaseService();
  final _googleAuth = GoogleAuthService();
  final _emailAuth = EmailAuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _EmailMode _emailMode = _EmailMode.create;
  bool _busy = false;
  bool _confirmationSent = false;
  String? _error;

  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Google sign-in and email confirmation both finish in a browser
    // and hand control back to the app via deep link (see
    // AndroidManifest.xml/Info.plist) — this is what makes the screen
    // update itself once that happens, instead of looking stuck.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _linkGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Only opens the browser and returns — it does NOT wait for the
      // person to actually finish signing in. The onAuthStateChange
      // listener above is what reflects the real outcome once they
      // come back to the app.
      await _googleAuth.linkToCurrentUser();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmailForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_emailMode == _EmailMode.create) {
        await _emailAuth.linkToCurrentUser(email, password);
        if (!mounted) return;
        setState(() => _confirmationSent = true);
      } else {
        await _emailAuth.signIn(email, password);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnonymous = _supabaseService.isAnonymous;
    final email = _supabaseService.linkedEmail;

    return Scaffold(
      appBar: AppBar(title: const Text('ACCOUNT')),
      body: RouteBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isAnonymous) ...[
                  const GbaDialogBox(
                    text: "You're currently playing as a guest: your "
                        'Wildkin are saved, but only on this device. '
                        'Link an account to keep them if you reinstall '
                        'the app or switch phones.',
                    fontSize: 15,
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: AppFonts.body(
                          fontSize: 13, color: AppColors.emberRed),
                    ),
                    const SizedBox(height: 12),
                  ],
                  PixelButton(
                    label: _busy ? 'OPENING BROWSER...' : 'SIGN IN WITH GOOGLE',
                    icon: Icons.login,
                    background: AppColors.tidalBlue,
                    onPressed: _busy ? null : _linkGoogle,
                  ),
                  const SizedBox(height: 24),
                  const _OrDivider(),
                  const SizedBox(height: 16),
                  _EmailSection(
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    mode: _emailMode,
                    busy: _busy,
                    confirmationSent: _confirmationSent,
                    onModeChanged: (mode) => setState(() {
                      _emailMode = mode;
                      _confirmationSent = false;
                      _error = null;
                    }),
                    onSubmit: _submitEmailForm,
                  ),
                ] else ...[
                  GbaDialogBox(
                    text: 'Your progress is saved to $email. '
                        "You'll keep your Wildkin even after "
                        'reinstalling the app or switching devices.',
                    fontSize: 15,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Divider(color: AppColors.textMuted.withValues(alpha: 0.4))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('OR',
              style: AppFonts.body(fontSize: 12, color: AppColors.textMuted)),
        ),
        Expanded(
            child: Divider(color: AppColors.textMuted.withValues(alpha: 0.4))),
      ],
    );
  }
}

class _EmailSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final _EmailMode mode;
  final bool busy;
  final bool confirmationSent;
  final ValueChanged<_EmailMode> onModeChanged;
  final VoidCallback onSubmit;

  const _EmailSection({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.mode,
    required this.busy,
    required this.confirmationSent,
    required this.onModeChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (confirmationSent) {
      return GbaDialogBox(
        text: 'Almost done! We sent a confirmation link to '
            '${emailController.text.trim()} — tap it, then just '
            'reopen the app.',
        fontSize: 15,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_EmailMode>(
          segments: const [
            ButtonSegment(value: _EmailMode.create, label: Text('Sign Up')),
            ButtonSegment(value: _EmailMode.signIn, label: Text('Log In')),
          ],
          selected: {mode},
          onSelectionChanged: (selection) => onModeChanged(selection.first),
        ),
        const SizedBox(height: 14),
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  filled: true,
                  fillColor: AppColors.panelCream,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || !value.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  filled: true,
                  fillColor: AppColors.panelCream,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.length < 6)
                    ? 'At least 6 characters'
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PixelButton(
          label: busy
              ? 'PLEASE WAIT...'
              : (mode == _EmailMode.create ? 'CREATE ACCOUNT' : 'SIGN IN'),
          background: AppColors.grassGreen,
          onPressed: busy ? null : onSubmit,
        ),
      ],
    );
  }
}
