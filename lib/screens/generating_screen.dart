import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pokeball_spinner.dart';
import '../widgets/pixel_button.dart';
import '../providers/capture_flow_provider.dart';
import 'capture_screen.dart';
import 'result_screen.dart';

/// Schermata mostrata durante ogni singolo scatto (sia il primo
/// avvistamento sia la conferma): raccolta contesto, analisi di
/// liveness, upload, chiamata server. Il testo del dialog box cambia
/// in base allo step corrente, imitando la sequenza di cattura dei
/// giochi originali.
///
/// [isConfirmation] indica se questo scatto è il primo avvistamento
/// o la conferma, solo per scegliere i messaggi e la navigazione
/// giusta al termine.
class GeneratingScreen extends ConsumerWidget {
  final bool isConfirmation;

  const GeneratingScreen({super.key, this.isConfirmation = false});

  String _messageFor(CaptureStep step) {
    switch (step) {
      case CaptureStep.idle:
        return 'Preparo la cattura...';
      case CaptureStep.requestingContext:
        return 'Rilevo posizione, meteo e ora...';
      case CaptureStep.capturingBurst:
        return 'Tieni fermo il telefono un istante...';
      case CaptureStep.uploadingPhoto:
        return 'Invio la foto al Pokedex...';
      case CaptureStep.recordingSighting:
        return 'Registro l\'avvistamento...';
      case CaptureStep.awaitingConfirmation:
        return 'Avvistamento registrato! Ora conferma.';
      case CaptureStep.confirmingSighting:
        return 'Verifico che sia lo stesso animale...';
      case CaptureStep.naming:
        return 'Le sto dando un nome...';
      case CaptureStep.done:
        return 'Cattura riuscita!';
      case CaptureStep.sightingExpired:
        return 'Il tempo per confermare è scaduto.';
      case CaptureStep.rejected:
        return 'Non sono riuscito a confermare l\'avvistamento.';
      case CaptureStep.error:
        return 'Qualcosa è andato storto durante la cattura.';
    }
  }

  bool _isTerminal(CaptureStep step) => switch (step) {
        CaptureStep.error ||
        CaptureStep.rejected ||
        CaptureStep.sightingExpired =>
          true,
        _ => false,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureFlowProvider);

    ref.listen<CaptureFlowState>(captureFlowProvider, (previous, next) {
      if (next.step == CaptureStep.done && next.result != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => ResultScreen(creature: next.result!)),
          (route) => route.isFirst,
        );
        return;
      }

      // Primo scatto riuscito: si passa alla schermata di conferma,
      // sostituendo questa (non si torna indietro a "Cattura").
      if (!isConfirmation && next.step == CaptureStep.awaitingConfirmation) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CaptureScreen(isConfirmation: true)),
        );
        return;
      }

      // Conferma rifiutata ma la finestra è ancora aperta: si torna
      // alla schermata di conferma (che mostrerà il motivo del
      // rifiuto e permetterà di riprovare subito un altro scatto).
      if (isConfirmation && next.step == CaptureStep.rejected) {
        Navigator.of(context).pop();
        return;
      }
    });

    return Scaffold(
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isTerminal(state.step)) ...[
                  const PokeballSpinner(size: 96),
                  const SizedBox(height: 32),
                ] else ...[
                  Icon(Icons.error_outline, size: 72, color: AppColors.rubyRed),
                  const SizedBox(height: 24),
                ],
                GbaDialogBox(text: _messageFor(state.step), fontSize: 18),
                if (state.step == CaptureStep.sightingExpired) ...[
                  const SizedBox(height: 20),
                  PixelButton(
                    label: 'RICOMINCIA',
                    onPressed: () {
                      ref.read(captureFlowProvider.notifier).reset();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const CaptureScreen()),
                        (route) => route.isFirst,
                      );
                    },
                  ),
                ] else if (state.step == CaptureStep.error) ...[
                  const SizedBox(height: 20),
                  PixelButton(
                    label: 'TORNA INDIETRO',
                    onPressed: () {
                      ref.read(captureFlowProvider.notifier).reset();
                      Navigator.of(context).pop();
                    },
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
