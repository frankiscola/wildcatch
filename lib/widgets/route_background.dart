import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A background with a sky gradient plus a wavy grass hill at the
/// bottom, evoking retro overworld screens with a soft outline
/// instead of a sharp, squared border line.
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
              stops: [0.0, 0.8],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ClipPath(
            clipper: _HillClipper(),
            child: Container(
              height: 110,
              color: AppColors.grassGreen,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Draws a soft hill outline instead of a sharp rectangle.
class _HillClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(0, size.height * 0.35);
    path.quadraticBezierTo(
      size.width * 0.25, 0,
      size.width * 0.5, size.height * 0.22,
    );
    path.quadraticBezierTo(
      size.width * 0.75, size.height * 0.42,
      size.width, size.height * 0.1,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
