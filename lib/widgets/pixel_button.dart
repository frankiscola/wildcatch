import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Pulsante rettangolare con bordo squadrato spesso e una piccola
/// "ombra" solida in basso a destra che simula la profondità
/// pixel-art dei menu GBA. Cambia leggermente posizione al tocco
/// per dare la sensazione di essere premuto.
class PixelButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.background = AppColors.rubyRed,
    this.foreground = AppColors.textOnDark,
    this.icon,
  });

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final bg = disabled ? AppColors.textMuted : widget.background;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(
          _pressed ? 2 : 0,
          _pressed ? 2 : 0,
          0,
        ),
        child: Stack(
          children: [
            // Ombra solida squadrata
            Positioned(
              left: 4,
              top: 4,
              right: 0,
              bottom: 0,
              child: Container(color: AppColors.panelBrown),
            ),
            // Corpo del pulsante
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: AppColors.dialogBorderOuter, width: 3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: widget.foreground, size: 18),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    widget.label,
                    style: AppFonts.pixelTitle(
                      fontSize: 12,
                      color: widget.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
