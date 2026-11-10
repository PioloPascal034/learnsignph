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
  final bool isLarge;

  const SignGifTile({
    super.key,
    required this.gifUrl,
    required this.word,
    this.isPlaceholder = false,
    this.isCompact = false,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isLarge ? 150.0 : (isCompact ? 60.0 : 74.0);
    final horizontalPadding = isCompact ? 8.0 : 10.0;
    final bgColor = isPlaceholder ? const Color(0xFFEAF1F8) : Colors.white;
    final borderColor =
        isPlaceholder ? AppColors.border : const Color(0xFFD5E4F2);

    return Container(
      width: size + horizontalPadding * 2 + 3,
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: isPlaceholder ? 1.5 : 1.4,
        ),
        boxShadow: isPlaceholder
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
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
          else if (gifUrl.trim().isEmpty)
            SizedBox(
              width: size,
              height: size,
              child: const Center(
                child: Icon(
                  Icons.hide_image_outlined,
                  color: AppColors.textMuted,
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: size,
                height: size,
                color: const Color(0xFFDDEAF5),
                child: Image.network(
                  gifUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => SizedBox(
                    width: size,
                    height: size,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!isPlaceholder) ...[
            const SizedBox(height: 6),
            Text(
              word,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
