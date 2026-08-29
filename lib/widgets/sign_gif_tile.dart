import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Compact sign display used in the grammar drag-and-drop screen.
/// Flutter's Image widget decodes animated GIFs natively (no extra
/// package needed) - Image.network on a .gif URL will loop automatically.
class SignGifTile extends StatelessWidget {
  final String gifUrl;
  final String word;
  final bool isPlaceholder;
  final bool isCompact;

  const SignGifTile({
    super.key,
    required this.gifUrl,
    required this.word,
    this.isPlaceholder = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isCompact ? 64.0 : 84.0;

    return Container(
      width: size + 24,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isPlaceholder ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlaceholder ? AppColors.textMuted.withOpacity(0.4) : AppColors.primaryLight,
          width: isPlaceholder ? 1.5 : 2,
          style: isPlaceholder ? BorderStyle.solid : BorderStyle.solid,
        ),
        boxShadow: isPlaceholder
            ? []
            : [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPlaceholder)
            SizedBox(
              width: size,
              height: size,
              child: const Center(
                child: Icon(Icons.add, color: AppColors.textMuted, size: 22),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                gifUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    width: size,
                    height: size,
                    child: const Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => SizedBox(
                  width: size, height: size,
                  child: const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted)),
                ),
              ),
            ),
          if (!isPlaceholder) ...[
            const SizedBox(height: 4),
            Text(
              word,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
          ],
        ],
      ),
    );
  }
}
