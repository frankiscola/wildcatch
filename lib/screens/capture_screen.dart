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
import 'generating_screen.dart';

/// Schermata di cattura, basata solo sulla fotocamera live (niente
/// galleria, vedi CameraCaptureService) e ora con scatto AUTOMATICO:
/// appena il telefono, dopo essere stato puntato, resta fermo per una
/// finestra continua, l'app scatta da sola (vedi AutoCaptureGate). Il
/// pulsante resta comunque premibile in ogni momento per scattare
/// subito, sia per chi lo preferisce sia come fallback sui device (o
/// emulatori) dove il giroscopio non è disponibile o non attiva mai
/// la fase "aiming".
///
/// Serve in due modalità, selezionate da [isConfirmation]:
///  - false: primo avvistamento (meccanismo 5, passo 1)
///  - true: conferma entro la finestra temporale (meccanismi 4 e 5,
///    passo 2) — mostra anche il countdown e, se il server ha
///    rifiutato il tentativo precedente, il motivo del rifiuto.
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

  /// Crea (o ricrea) il gate di auto-scatto. Va richiamato ogni volta
  /// che si torna pronti per un nuovo tentativo: all'avvio della
  /// schermata e dopo ogni scatto che non abbia portato via da questa
  /// schermata (es. un rifiuto del server durante la conferma).
  void _restartAutoGate() {
    if (!_cameraReady || _capturing) return;
    _autoGate?.dispose();
    final gate = AutoCaptureGate()..start();
    _autoGate = gate;
    gate.onReady.then((_) {
      if (mounted && !_capturing) _onShutterPressed();
    });
    setState(() {}); // fa ripartire lo StreamBuilder sul nuovo gate
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
    // Se siamo ancora su questa schermata (es. il server ha
    // rifiutato la conferma ed è tornato indietro), il giocatore può
    // provare di nuovo: si riparte con un gate pulito.
    _restartAutoGate();
  }

  @override
  void dispose() {
    _autoGate?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureFlowProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isConfirmation ? 'CONFERMA AVVISTAMENTO' : 'CATTURA'),
      ),
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (widget.isConfirmation) _CountdownBanner(remaining: state.remaining),
                if (widget.isConfirmation && state.rejectionReason != null) ...[
                  const SizedBox(height: 8),
                  _RejectionBanner(reason: state.rejectionReason!),
                ],
                const SizedBox(height: 12),
                Expanded(child: _CameraFrame(ready: _cameraReady, error: _cameraError)),
                const SizedBox(height: 16),
                GbaDialogBox(
                  text: widget.isConfirmation
                      ? 'Ritrova lo stesso animale e tienilo inquadrato: scatterà da solo, oppure premi CONFERMA quando vuoi.'
                      : 'Inquadra l\'animale e tieni fermo il telefono: scatterà da solo appena sei stabile, oppure premi CATTURA quando vuoi.',
                  fontSize: 16,
                ),
                const SizedBox(height: 20),
                _ShutterButton(
                  label: widget.isConfirmation ? 'CONFERMA!' : 'CATTURA!',
                  enabled: _cameraReady && !_capturing,
                  progressStream: _autoGate?.progress,
                  onPressed: _onShutterPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsante di scatto con un anello di avanzamento intorno: si
/// riempie da solo man mano che AutoCaptureGate rileva stabilità, per
/// far capire all'utente che l'app sta per scattare da sola (invece
/// di sembrare bloccata, come nel primo giro di test).
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
      icon: Icons.catching_pokemon,
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
        color: urgent ? AppColors.rubyRed : AppColors.sapphireBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            'Tempo rimasto per confermare: $label',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _RejectionBanner extends StatelessWidget {
  final Object reason; // SightingRejectionReason, tipizzato debolmente per evitare un altro import qui

  const _RejectionBanner({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.rubyRed.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.rubyRed),
      ),
      child: Text(
        // ignore: avoid_dynamic_calls
        (reason as dynamic).userMessage as String,
        style: TextStyle(color: AppColors.rubyRed.withOpacity(0.9)),
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
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 10, offset: Offset(0, 5)),
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
