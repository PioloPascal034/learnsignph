import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
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
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  bool _hasError = false;
  int _initializationId = 0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final initializationId = ++_initializationId;
    final previousController = _videoController;
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _videoController = controller;

    try {
      await previousController?.dispose();
      if (!mounted || initializationId != _initializationId) {
        await controller.dispose();
        return;
      }
      await controller.initialize().timeout(const Duration(seconds: 20));
      await controller.setLooping(widget.looping);
      if (widget.autoPlay) {
        await controller.play();
      }
      if (!mounted || initializationId != _initializationId) {
        await controller.dispose();
        return;
      }
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted && initializationId == _initializationId) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant SignVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
      _initializePlayer();
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _initializePlayer();
  }

  @override
  void dispose() {
    _initializationId++;
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return SizedBox(
        height: 220,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.textMuted),
                const SizedBox(height: 8),
                const Text(
                  'Video could not be loaded',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final controller = _videoController;
    if (_isLoading || controller == null || !controller.value.isInitialized) {
      return const SizedBox(
        height: 220,
        child:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final videoWidth =
        controller.value.size.width > 0 ? controller.value.size.width : 320.0;
    final videoHeight =
        controller.value.size.height > 0 ? controller.value.size.height : 180.0;

    return SizedBox(
      width: double.infinity,
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: videoWidth,
            height: videoHeight,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}
