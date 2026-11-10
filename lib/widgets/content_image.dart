import 'package:flutter/material.dart';

/// Displays a contextual lesson/grammar image from a remote URL or bundled
/// asset. It is intentionally separate from sign media, which requires its
/// own accuracy and licensing review.
class ContentImage extends StatelessWidget {
  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;

  const ContentImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final value = source.trim();
    if (value.isEmpty) return fallback ?? const SizedBox.shrink();

    final image = value.startsWith('asset:')
        ? Image.asset(
            value.substring('asset:'.length),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => fallback ?? _fallbackIcon(),
          )
        : Image.network(
            value,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => fallback ?? _fallbackIcon(),
          );
    return image;
  }

  Widget _fallbackIcon() {
    return const Center(child: Icon(Icons.image_not_supported_outlined));
  }
}
