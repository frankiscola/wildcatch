import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_colors.dart';

/// Draws a stylized camera-scanner orb (an outer ring, a rotating
/// segmented arc, and a glowing lens center) used while the app is
/// "scanning" a photo — a camera-viewfinder motif, not a
/// ball-and-button design.
class CaptureSpinner extends StatefulWidget {
  final double size;

  const CaptureSpinner({super.key, this.size = 72});

  @override
  State<CaptureSpinner> createState() => _CaptureSpinnerState();
}

class _CaptureSpinnerState extends State<CaptureSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _CaptureSpinnerPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _CaptureSpinnerPainter extends CustomPainter {
  final double progress;

  _CaptureSpinnerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final outline = Paint()
      ..color = AppColors.dialogBorderOuter
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045;

    final trackPaint = Paint()
      ..color = AppColors.captureOrbRed.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = AppColors.captureOrbRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;

    // Outer track ring
    canvas.drawCircle(center, radius - outline.strokeWidth, trackPaint);

    // Rotating scan arc
    final startAngle = progress * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - outline.strokeWidth),
      startAngle,
      math.pi * 0.65,
      false,
      arcPaint,
    );

    // Outer ring outline
    canvas.drawCircle(center, radius - outline.strokeWidth / 2, outline);

    // Lens center
    canvas.drawCircle(center, radius * 0.32, Paint()..color = AppColors.captureOrbDark);
    canvas.drawCircle(center, radius * 0.32, outline);
    canvas.drawCircle(center, radius * 0.14, Paint()..color = AppColors.captureOrbGold);
  }

  @override
  bool shouldRepaint(covariant _CaptureSpinnerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
