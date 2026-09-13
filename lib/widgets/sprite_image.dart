import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Renders a Wildkin sprite from [url]. In the real app this is
/// always an https:// URL pointing at Supabase Storage; the
/// lib/dev/ preview harness passes a local file path instead (no
/// Supabase project needed to look at the UI), which this widget
/// picks up transparently via [Image.file].
class SpriteImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const SpriteImage({super.key, required this.url, this.fit = BoxFit.contain});

  bool get _isNetwork => url.startsWith('http://') || url.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final errorIcon = Center(
      child: Icon(Icons.image_not_supported, color: AppColors.textMuted),
    );

    if (_isNetwork) {
      return Image.network(
        url,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => errorIcon,
      );
    }

    return Image.file(
      File(url),
      fit: fit,
      errorBuilder: (context, error, stackTrace) => errorIcon,
    );
  }
}
