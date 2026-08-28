import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pokeball_spinner.dart';
import '../widgets/pixel_button.dart';
import '../providers/capture_flow_provider.dart';
import 'result_screen.dart';

/// Schermata mostrata durante tutta la pipeline: raccolta contesto,
/// upload della foto, generazione della creatura. Il testo del
/// dialog box cambia in base allo step corrente, imitando la
/// sequenza di cattura dei giochi originali.
class GeneratingScreen extends ConsumerWidget {
  const GeneratingScreen({super.key});

  String _messageFor(CaptureStep step) {
    switch (step) {
      case CaptureStep.requestingContext:
        return 'Rilevo posizione, meteo e ora della cattura...';
      case CaptureStep.uploadingPhoto:
        return 'Invio la foto al Pokedex...';
      case CaptureStep.generatingCreature:
        return 'La pokeball trema... sta per uscire qualcosa!';
      case CaptureStep.error:
        return 'Qualcosa è andato storto durante la cattura.';
      case CaptureStep.done:
        return 'Cattura riuscita!';
      case CaptureStep.idle:
        return 'Preparo la cattura...';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureFlowProvider);

    ref.listen(captureFlowProvider, (previous, next) {
      if (next.step == CaptureStep.done && next.result != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResultScreen(creature: next.result!),
          ),
        );
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
                if (state.step != CaptureStep.error) ...[
                  const PokeballSpinner(size: 96),
                  const SizedBox(height: 32),
                ] else ...[
                  Icon(Icons.error_outline, size: 72, color: AppColors.rubyRed),
                  const SizedBox(height: 24),
                ],
                GbaDialogBox(text: _messageFor(state.step), fontSize: 18),
                if (state.step == CaptureStep.error) ...[
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
