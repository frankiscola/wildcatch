import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Sfondo con gradiente cielo + striscia d'erba in basso,
/// che richiama le schermate "overworld" dei giochi gen 3.
/// Da usare come sfondo delle schermate principali.
class RouteBackground extends StatelessWidget {
  final Widget child;

  const RouteBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.routeSkyTop, AppColors.routeSkyBottom],
              stops: [0.0, 0.75],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 90,
            decoration: const BoxDecoration(
              color: AppColors.grassGreen,
              border: Border(
                top: BorderSide(color: AppColors.dialogBorderOuter, width: 3),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
