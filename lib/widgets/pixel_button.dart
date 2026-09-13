import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A rounded button with a subtle gradient and a soft shadow, in a
/// retro menu style (rather than the squared rectangle with a solid
/// "stepped" shadow of the original pixel version). On tap it
/// presses down slightly and the shadow shrinks, for playful
/// physical-feeling feedback.
///
/// The class is still called `PixelButton` to avoid touching every
/// place in the app that already uses it.
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
    this.background = AppColors.emberRed,
    this.foreground = AppColors.textOnDark,
    this.icon,
  });

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _pressed = false;

  Color _darken(Color color, [double amount = 0.18]) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

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
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bg, _darken(bg)],
          ),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: _darken(bg, 0.3).withOpacity(0.55),
                    blurRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: widget.foreground, size: 20),
              const SizedBox(width: 10),
            ],
            Text(
              widget.label,
              style: AppFonts.pixelTitle(fontSize: 12, color: widget.foreground),
            ),
          ],
        ),
      ),
    );
  }
}
