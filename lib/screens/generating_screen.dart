import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/capture_spinner.dart';
import '../widgets/pixel_button.dart';
import '../providers/capture_flow_provider.dart';
import 'capture_screen.dart';
import 'result_screen.dart';

/// Screen shown during each individual shot (both the first sighting
/// and the confirmation): gathering context, liveness analysis,
/// upload, server call. The dialog box text changes based on the
/// current step, mirroring the capture sequence of classic games.
///
/// [isConfirmation] indicates whether this shot is the first
/// sighting or the confirmation, only used to pick the right
/// messages and navigation at the end.
class GeneratingScreen extends ConsumerWidget {
  final bool isConfirmation;

  const GeneratingScreen({super.key, this.isConfirmation = false});

  String _messageFor(CaptureStep step) {
    switch (step) {
      case CaptureStep.idle:
        return 'Getting ready to capture...';
      case CaptureStep.requestingContext:
        return 'Reading location, weather, and time...';
      case CaptureStep.capturingBurst:
        return 'Hold the phone steady for a moment...';
      case CaptureStep.uploadingPhoto:
        return 'Sending the photo to the Field Journal...';
      case CaptureStep.recordingSighting:
        return 'Recording the sighting...';
      case CaptureStep.awaitingConfirmation:
        return 'Sighting recorded! Now confirm it.';
      case CaptureStep.confirmingSighting:
        return 'Checking it\'s the same animal...';
      case CaptureStep.naming:
        return 'Giving it a name...';
      case CaptureStep.done:
        return 'Capture successful!';
      case CaptureStep.sightingExpired:
        return 'The time to confirm has run out.';
      case CaptureStep.rejected:
        return 'Couldn\'t confirm the sighting.';
      case CaptureStep.error:
        return 'Something went wrong during the capture.';
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
          MaterialPageRoute(builder: (_) => ResultScreen(wildkin: next.result!)),
          (route) => route.isFirst,
        );
        return;
      }

      // First shot successful: move on to the confirmation screen,
      // replacing this one (no going back to "Capture").
      if (!isConfirmation && next.step == CaptureStep.awaitingConfirmation) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CaptureScreen(isConfirmation: true)),
        );
        return;
      }

      // Confirmation rejected but the window is still open: go back
      // to the confirmation screen (which will show the rejection
      // reason and let the player immediately try another shot).
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
                  const CaptureSpinner(size: 96),
                  const SizedBox(height: 32),
                ] else ...[
                  Icon(Icons.error_outline, size: 72, color: AppColors.emberRed),
                  const SizedBox(height: 24),
                ],
                GbaDialogBox(text: _messageFor(state.step), fontSize: 18),
                if (state.step == CaptureStep.sightingExpired) ...[
                  const SizedBox(height: 20),
                  PixelButton(
                    label: 'START OVER',
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
                    label: 'GO BACK',
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
