import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Disegna una pokeball stilizzata (metà rossa, metà bianca,
/// bottone centrale nero) che oscilla come durante una cattura.
class PokeballSpinner extends StatefulWidget {
  final double size;

  const PokeballSpinner({super.key, this.size = 72});

  @override
  State<PokeballSpinner> createState() => _PokeballSpinnerState();
}

class _PokeballSpinnerState extends State<PokeballSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
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
        final angle = (_controller.value - 0.5) * 0.35; // radianti
        return Transform.rotate(angle: angle, child: child);
      },
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _PokeballPainter(),
      ),
    );
  }
}

class _PokeballPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final topHalf = Paint()..color = AppColors.pokeballRed;
    final bottomHalf = Paint()..color = AppColors.pokeballWhite;
    final outline = Paint()
      ..color = AppColors.dialogBorderOuter
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045;

    // Metà superiore rossa
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159,
      3.14159,
      true,
      topHalf,
    );
    // Metà inferiore bianca
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      3.14159,
      true,
      bottomHalf,
    );
    // Contorno esterno
    canvas.drawCircle(center, radius - outline.strokeWidth / 2, outline);
    // Fascia centrale
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      outline,
    );
    // Bottone centrale
    canvas.drawCircle(center, radius * 0.22, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius * 0.22, outline);
    canvas.drawCircle(center, radius * 0.11, Paint()..color = AppColors.pokeballWhite);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
