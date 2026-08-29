import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/lesson_model.dart';
import '../../models/sign_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';
import '../../widgets/video_player_widget.dart';
import '../grammar/grammar_practice_screen.dart';

class LessonDetailScreen extends StatefulWidget {
  final String lessonId;
  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  LessonModel? _lesson;
  List<SignModel> _signs = [];
  bool _isLoading = true;
  bool _isMarkingComplete = false;

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  Future<void> _loadLesson() async {
    final lesson = await _firestoreService.getLesson(widget.lessonId);
    if (lesson == null) {
      setState(() => _isLoading = false);
      return;
    }
    final signs = await _firestoreService.getSignsByIds(lesson.signIds);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _firestoreService.markLessonStarted(userId, widget.lessonId);
    }

    if (!mounted) return;
    setState(() {
      _lesson = lesson;
      _signs = signs;
      _isLoading = false;
    });
  }

  Future<void> _handleMarkComplete() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isMarkingComplete = true);
    await _firestoreService.markLessonCompleted(userId, widget.lessonId);
    setState(() => _isMarkingComplete = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lesson marked as completed!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_lesson == null) {
      return const Scaffold(
        body: Center(child: Text('Lesson not found.')),
      );
    }

    final lesson = _lesson!;

    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (lesson.videoUrl.isNotEmpty)
            SignVideoPlayer(videoUrl: lesson.videoUrl),
          const SizedBox(height: 16),
          Text(lesson.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(lesson.description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          Text('Signs in this lesson (${_signs.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._signs.map((sign) => _SignTile(sign: sign)),
            const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GrammarPracticeScreen(
                      exerciseId: 'grammar_hospital_help',
                      mode: 'lesson',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.extension_outlined),
              label: const Text('Practice Grammar'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isMarkingComplete ? null : _handleMarkComplete,
              icon: _isMarkingComplete
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_isMarkingComplete ? 'Saving...' : 'Mark Lesson as Completed'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignTile extends StatelessWidget {
  final SignModel sign;
  const _SignTile({required this.sign});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Icon(Icons.play_arrow, color: Colors.white),
        ),
        title: Text(sign.word, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Difficulty: ${sign.difficulty}'),
        onTap: () {
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
                  Text(sign.word, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SignVideoPlayer(videoUrl: sign.videoUrl, autoPlay: true),
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
