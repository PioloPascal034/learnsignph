import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../utils/theme.dart';

/// Wraps video_player + chewie so every screen that shows a sign
/// demonstration video (lesson detail, scenario practice, etc.) gets the
/// same player controls without repeating setup code.
class SignVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool looping;

  const SignVideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
    this.looping = true,
  });

  @override
  State<SignVideoPlayer> createState() => _SignVideoPlayerState();
}

class _SignVideoPlayerState extends State<SignVideoPlayer> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _videoController.initialize();
      if (!mounted) return;
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          autoPlay: widget.autoPlay,
          looping: widget.looping,
          aspectRatio: _videoController.value.aspectRatio == 0
              ? 16 / 9
              : _videoController.value.aspectRatio,
          materialProgressColors: ChewieProgressColors(
            playedColor: AppColors.primary,
            handleColor: AppColors.primary,
            bufferedColor: AppColors.primaryLight.withValues(alpha: 0.4),
          ),
        );
      });
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black12,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: AppColors.textMuted),
                SizedBox(height: 8),
                Text('Video could not be loaded', style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      );
    }

    if (_chewieController == null) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Chewie(controller: _chewieController!),
    );
  }
}
