import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pixel_button.dart';
import '../providers/capture_flow_provider.dart';
import '../services/auto_capture_gate.dart';
import '../services/context_builder.dart';
import '../services/wild_encounter_generator.dart';
import 'generating_screen.dart';
import 'wildkin_picker_screen.dart';

/// Capture screen, based only on the live camera (no gallery, see
/// CameraCaptureService) and now with an AUTOMATIC shutter: as soon
/// as the phone, after being pointed at something, holds still for a
/// continuous window, the app captures on its own (see
/// AutoCaptureGate). The button is still always pressable to capture
/// immediately, both for players who prefer that and as a fallback
/// on devices (or emulators) where the gyroscope isn't available or
/// never triggers the "aiming" phase.
///
/// Used in two modes, selected by [isConfirmation]:
///  - false: first sighting (mechanism 5, step 1)
///  - true: confirmation within the time window (mechanisms 4 and 5,
///    step 2) — also shows the countdown and, if the server rejected
///    the previous attempt, the rejection reason.
class CaptureScreen extends ConsumerStatefulWidget {
  final bool isConfirmation;

  const CaptureScreen({super.key, this.isConfirmation = false});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  bool _cameraReady = false;
  String? _cameraError;
  bool _capturing = false;
  bool _generatingEncounter = false;

  AutoCaptureGate? _autoGate;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      await ref.read(captureFlowProvider.notifier).initializeCamera();
      if (!mounted) return;
      setState(() => _cameraReady = true);
      _restartAutoGate();
    } catch (e) {
      if (!mounted) return;
      setState(() => _cameraError = e.toString());
    }
  }

  /// Creates (or recreates) the auto-capture gate. Must be called
  /// again every time we're ready for a new attempt: on screen
  /// startup and after any shot that didn't navigate away from this
  /// screen (e.g. a server rejection during confirmation).
  void _restartAutoGate() {
    if (!_cameraReady || _capturing) return;
    _autoGate?.dispose();
    final gate = AutoCaptureGate()..start();
    _autoGate = gate;
    gate.onReady.then((_) {
      if (mounted && !_capturing) _onShutterPressed();
    });
    setState(() {}); // restarts the StreamBuilder on the new gate
  }

  Future<void> _onShutterPressed() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    await _autoGate?.stop();

    final userId = Supabase.instance.client.auth.currentUser!.id;
    final notifier = ref.read(captureFlowProvider.notifier);

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GeneratingScreen(isConfirmation: widget.isConfirmation),
      ),
    );

    if (widget.isConfirmation) {
      await notifier.captureConfirmation(userId: userId);
    } else {
      await notifier.captureFirstSighting(userId: userId);
    }

    if (!mounted) return;
    setState(() => _capturing = false);
    // If we're still on this screen (e.g. the server rejected the
    // confirmation and navigated back), the player can try again:
    // start fresh with a clean gate.
    _restartAutoGate();
  }

  @override
  void dispose() {
    _autoGate?.dispose();
    super.dispose();
  }

  /// Generates a wild encounter from the CURRENT context (no new
  /// shot needed: the sighting's existing photo is enough) and opens
  /// the picker for which Wildkin to fight with. The pending sighting
  /// stays open (countdown included) while battling.
  Future<void> _fightBeforeConfirming() async {
    if (_generatingEncounter || _capturing) return;
    setState(() => _generatingEncounter = true);
    await _autoGate?.stop();

    try {
      final context = await ContextBuilder().buildCurrentContext();
      final wild = WildEncounterGenerator().generate(context);

      if (!mounted) return;
      await Navigator.of(context as BuildContext).push(
        MaterialPageRoute(
          builder: (_) => WildkinPickerScreen(wildEncounter: wild),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate the encounter: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _generatingEncounter = false);
        _restartAutoGate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureFlowProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isConfirmation ? 'CONFIRM SIGHTING' : 'CAPTURE'),
      ),
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (widget.isConfirmation)
                  _CountdownBanner(remaining: state.remaining),
                if (widget.isConfirmation && state.rejectionReason != null) ...[
                  const SizedBox(height: 8),
                  _RejectionBanner(reason: state.rejectionReason!),
                ],
                const SizedBox(height: 12),
                Expanded(
                    child:
                        _CameraFrame(ready: _cameraReady, error: _cameraError)),
                const SizedBox(height: 16),
                GbaDialogBox(
                  text: widget.isConfirmation
                      ? 'Find the same animal again and keep it in frame: it will fire on its own, or press CONFIRM whenever you want.'
                      : 'Frame the animal and hold the phone steady: it will fire on its own once you\'re stable, or press CAPTURE whenever you want.',
                  fontSize: 16,
                ),
                const SizedBox(height: 20),
                _ShutterButton(
                  label: widget.isConfirmation ? 'CONFIRM!' : 'CAPTURE!',
                  enabled: _cameraReady && !_capturing && !_generatingEncounter,
                  progressStream: _autoGate?.progress,
                  onPressed: _onShutterPressed,
                ),
                if (widget.isConfirmation && state.pendingSighting != null) ...[
                  const SizedBox(height: 12),
                  PixelButton(
                    label: 'FIGHT FIRST',
                    icon: Icons.sports_martial_arts,
                    background: AppColors.tidalBlue,
                    onPressed: (_capturing || _generatingEncounter)
                        ? null
                        : _fightBeforeConfirming,
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

/// Shutter button with a progress ring around it: it fills on its
/// own as AutoCaptureGate detects stability, to let the player know
/// the app is about to fire on its own (instead of looking stuck,
/// like in the first round of testing).
class _ShutterButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final Stream<double>? progressStream;
  final VoidCallback onPressed;

  const _ShutterButton({
    required this.label,
    required this.enabled,
    required this.progressStream,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final stream = progressStream;

    final button = PixelButton(
      label: label,
      icon: Icons.center_focus_strong,
      background: AppColors.grassGreen,
      onPressed: enabled ? onPressed : null,
    );

    if (stream == null) return button;

    return StreamBuilder<double>(
      stream: stream,
      initialData: 0,
      builder: (context, snapshot) {
        final progress = snapshot.data ?? 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 4,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(
                  progress > 0 ? AppColors.grassGreen : Colors.transparent,
                ),
              ),
            ),
            button,
          ],
        );
      },
    );
  }
}

class _CountdownBanner extends StatelessWidget {
  final Duration? remaining;

  const _CountdownBanner({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final remaining = this.remaining;
    final label = remaining == null
        ? '...'
        : '${remaining.inMinutes.toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

    final urgent = remaining != null && remaining.inSeconds < 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: urgent ? AppColors.emberRed : AppColors.tidalBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            'Time left to confirm: $label',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _RejectionBanner extends StatelessWidget {
  final Object
      reason; // SightingRejectionReason, loosely typed here to avoid another import

  const _RejectionBanner({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.emberRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.emberRed),
      ),
      child: Text(
        // ignore: avoid_dynamic_calls
        (reason as dynamic).userMessage as String,
        style: TextStyle(color: AppColors.emberRed.withValues(alpha: 0.9)),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CameraFrame extends ConsumerWidget {
  final bool ready;
  final String? error;

  const _CameraFrame({required this.ready, required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.panelCream,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 10,
              offset: Offset(0, 5)),
        ],
      ),
      padding: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(ref),
    );
  }

  Widget _buildContent(WidgetRef ref) {
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    if (!ready) {
      return const Center(child: CircularProgressIndicator());
    }

    final controller = ref.read(captureFlowProvider.notifier).camera.controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }
}
