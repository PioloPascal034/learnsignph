import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/lesson_model.dart';
import '../../models/sign_model.dart';
import '../../services/firestore_service.dart';
import '../../services/grammar_firestore_service.dart';
import '../../utils/theme.dart';
import '../../widgets/content_image.dart';
import '../grammar/grammar_practice_screen.dart';
import '../../widgets/sign_gif_tile.dart';
import '../../widgets/video_player_widget.dart';

class LessonDetailScreen extends StatefulWidget {
  final String lessonId;
  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final GrammarFirestoreService _grammarFirestoreService =
      GrammarFirestoreService();

  LessonModel? _lesson;
  String? _grammarExerciseId;
  String? _grammarLoadError;
  List<SignModel> _signs = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  Future<void> _loadLesson() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final lesson = await _firestoreService
          .getLesson(widget.lessonId)
          .timeout(const Duration(seconds: 20));
      if (lesson == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final signs = await _firestoreService
          .getSignsByIds(lesson.signIds)
          .timeout(const Duration(seconds: 20));
      final lessonSigns =
          signs.where((sign) => sign.word.trim().isNotEmpty).toList();

      if (!mounted) return;
      setState(() {
        _lesson = lesson;
        _signs = lessonSigns;
        _isLoading = false;
      });
      _loadGrammarExercise();
    } catch (error) {
      debugPrint(
          '[LessonDetail] content failed lesson=${widget.lessonId}: $error');
      if (!mounted) return;
      setState(() {
        _loadError = _loadErrorText(error);
        _isLoading = false;
      });
    }
  }

  String _loadErrorText(Object error) {
    if (error is FirebaseException) {
      return 'Firestore could not complete this request (${error.code}). ${error.message ?? ''}';
    }
    return 'This request could not be completed: $error';
  }

  Future<void> _loadGrammarExercise() async {
    try {
      final exerciseId = await _grammarFirestoreService
          .getExerciseIdForLesson(widget.lessonId)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _grammarExerciseId = exerciseId;
        _grammarLoadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _grammarLoadError = 'Grammar practice could not be loaded.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _loadLesson, child: const Text('Try again')),
            ]),
          ),
        ),
      );
    }

    if (_lesson == null) {
      return const Scaffold(
        body: Center(child: Text('Lesson not found.')),
      );
    }

    final lesson = _lesson!;

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (lesson.imageUrl.trim().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ContentImage(
                source: lesson.imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.contain,
                fallback: Container(
                  height: 180,
                  color: AppColors.surface,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            color: AppColors.textMuted),
                        SizedBox(height: 8),
                        Text('Lesson image unavailable',
                            style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (lesson.videoUrl.trim().isNotEmpty)
            SignVideoPlayer(videoUrl: lesson.videoUrl),
          const SizedBox(height: 16),
          Text(lesson.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(lesson.description,
              style: Theme.of(context).textTheme.bodyMedium),
          if (lesson.learningObjectives.isNotEmpty) ...[
            const SizedBox(height: 16),
            _LessonInfoCard(
              title: 'Learning objectives',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lesson.learningObjectives
                    .map((objective) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $objective'),
                        ))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Signs in this lesson (${_signs.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._signs.map((sign) => _SignTile(sign: sign)),
          if (_grammarExerciseId != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GrammarPracticeScreen(
                        exerciseId: _grammarExerciseId!,
                        mode: 'lesson',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.drag_indicator),
                label: const Text('Practice Grammar'),
              ),
            ),
          ] else if (_grammarLoadError != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Grammar practice could not be loaded.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                TextButton(
                    onPressed: _loadGrammarExercise,
                    child: const Text('Retry')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LessonInfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _LessonInfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SignTile extends StatelessWidget {
  final SignModel sign;
  const _SignTile({required this.sign});

  void _scheduleViewReward() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    Future<void>.delayed(const Duration(seconds: 3), () async {
      try {
        await FirestoreService().awardSignViewPoints(userId, sign.id);
      } catch (error) {
        debugPrint('[SignViewReward] failed sign=${sign.id}: $error');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        tileColor: Colors.white,
        leading: sign.imageUrl.trim().isEmpty
            ? const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.play_arrow, color: Colors.white),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ContentImage(
                  source: sign.imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                  fallback: const Icon(Icons.broken_image_outlined),
                ),
              ),
        title: Text(sign.word,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Difficulty: ${sign.difficulty}'),
        onTap: () {
          _scheduleViewReward();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(sign.word,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (sign.gifUrl.trim().isNotEmpty)
                    SignGifTile(
                        gifUrl: sign.gifUrl, word: sign.word, isLarge: true)
                  else if (sign.videoUrl.trim().isNotEmpty)
                    SizedBox(
                      height: 220,
                      child: SignVideoPlayer(
                          videoUrl: sign.videoUrl, autoPlay: true),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.hide_image_outlined,
                              color: AppColors.textMuted, size: 32),
                          SizedBox(height: 8),
                          Text(
                              'No demonstration media is available for this sign.'),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
