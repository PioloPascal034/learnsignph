import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/lesson_activity_model.dart';
import '../../models/lesson_activity_progress_model.dart';
import '../../models/lesson_model.dart';
import '../../models/sign_model.dart';
import '../../services/firestore_service.dart';
import '../../services/grammar_firestore_service.dart';
import '../../utils/theme.dart';
import '../grammar/grammar_practice_screen.dart';
import '../../widgets/sign_gif_tile.dart';
import '../../widgets/video_player_widget.dart';
import '../../widgets/lesson_activity_runner.dart';
import '../../services/lesson_activity_engine.dart';

class LessonDetailScreen extends StatefulWidget {
  final String lessonId;
  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonQuizQuestion {
  final SignModel sign;
  final List<String> options;

  const _LessonQuizQuestion({required this.sign, required this.options});
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final GrammarFirestoreService _grammarFirestoreService =
      GrammarFirestoreService();

  LessonModel? _lesson;
  String? _grammarExerciseId;
  String? _grammarLoadError;
  List<SignModel> _signs = [];
  List<_LessonQuizQuestion> _quizQuestions = [];
  final Map<int, String> _selectedAnswers = {};
  bool _isLoading = true;
  bool _isCompleted = false;
  double _bestQuizScore = 0;
  bool _isSubmittingQuiz = false;
  bool _quizSubmitted = false;
  String? _loadError;
  Map<String, LessonActivityProgressModel> _activityProgress = {};

  List<LessonActivityModel> get _interactiveActivities {
    final configured = LessonActivityEngine.validActivities(
      _lesson?.activities ?? const [],
    );
    if (configured.isNotEmpty) return configured;

    final words = _signs.map((sign) => sign.word.trim()).toSet().toList();
    return LessonActivityEngine.validActivities(
      _signs.asMap().entries.map((entry) {
        final sign = entry.value;
        final distractors =
            words.where((word) => word != sign.word.trim()).take(3).toList();
        final mediaUrl = sign.gifUrl.trim().isNotEmpty
            ? sign.gifUrl
            : (sign.imageUrl.trim().isNotEmpty ? sign.imageUrl : sign.videoUrl);
        final mediaType = sign.gifUrl.trim().isNotEmpty
            ? 'gif'
            : (sign.imageUrl.trim().isNotEmpty ? 'image' : 'video');
        return LessonActivityModel.fromSign(
          id: 'legacy_sign_${entry.key}',
          word: sign.word.trim(),
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          distractors: distractors,
        );
      }),
    );
  }

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
      final userId = FirebaseAuth.instance.currentUser?.uid;
      var isCompleted = false;
      var activityProgress = <String, LessonActivityProgressModel>{};
      if (userId != null) {
        final progress = await _firestoreService
            .getLessonProgress(userId, widget.lessonId)
            .timeout(const Duration(seconds: 20));
        activityProgress = await _firestoreService
            .getLessonActivityProgress(userId, widget.lessonId)
            .timeout(const Duration(seconds: 20));
        isCompleted = progress?.status == 'completed';
        _bestQuizScore = progress?.score ?? 0;
      }

      final lessonSigns =
          signs.where((sign) => sign.word.trim().isNotEmpty).toList();
      final questions = <_LessonQuizQuestion>[];
      final sampleSigns = lessonSigns.length > 4
          ? (lessonSigns.toList()..shuffle()).take(4)
          : lessonSigns;
      for (final sign in sampleSigns) {
        final distractors = lessonSigns
            .where((item) =>
                item.id != sign.id &&
                item.word.trim().isNotEmpty &&
                item.word != sign.word)
            .map((item) => item.word.trim())
            .toSet()
            .toList();
        distractors.shuffle();
        final options = <String>[sign.word.trim()];
        options.addAll(distractors.take(3));
        options.shuffle();
        questions.add(_LessonQuizQuestion(sign: sign, options: options));
      }

      if (!mounted) return;
      setState(() {
        _lesson = lesson;
        _signs = lessonSigns;
        _quizQuestions = questions;
        _isCompleted = isCompleted;
        _activityProgress = activityProgress;
        _selectedAnswers.clear();
        _quizSubmitted = false;
        _isLoading = false;
      });
      _loadGrammarExercise();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError =
            'Could not load this lesson. Check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _recordActivityAttempt(
    LessonActivityModel activity,
    double score,
    bool passed,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    await _firestoreService.recordLessonActivityResult(
      userId: userId,
      lessonId: widget.lessonId,
      activityId: activity.id,
      score: score,
      passed: passed,
    );
    final updated = await _firestoreService.getLessonActivityProgress(
      userId,
      widget.lessonId,
    );
    if (mounted) setState(() => _activityProgress = updated);
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

  Widget _buildQuizSignMedia(SignModel sign, String fallbackVideoUrl) {
    if (sign.gifUrl.trim().isNotEmpty) {
      return SignGifTile(gifUrl: sign.gifUrl, word: sign.word, isLarge: true);
    }

    final videoUrl =
        sign.videoUrl.trim().isNotEmpty ? sign.videoUrl : fallbackVideoUrl;
    if (videoUrl.trim().isNotEmpty) {
      return SignVideoPlayer(videoUrl: videoUrl);
    }

    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.hide_image_outlined, color: AppColors.textMuted),
      ),
    );
  }

  bool get _allQuestionsAnswered =>
      _quizQuestions.isNotEmpty &&
      _selectedAnswers.length == _quizQuestions.length &&
      List.generate(_quizQuestions.length, (index) => index)
          .every(_selectedAnswers.containsKey);

  Future<void> _submitQuiz() async {
    if (_quizQuestions.isEmpty || !_allQuestionsAnswered || _isSubmittingQuiz) {
      return;
    }

    setState(() => _isSubmittingQuiz = true);

    int correctCount = 0;
    for (int i = 0; i < _quizQuestions.length; i++) {
      final selected = _selectedAnswers[i];
      if (selected == _quizQuestions[i].sign.word.trim()) {
        correctCount++;
      }
    }

    final score = FirestoreService.calculateQuizScore(
      correctCount,
      _quizQuestions.length,
    );
    final perfect = score == 100;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await _firestoreService.recordLessonQuizResult(
          userId: userId,
          lessonId: widget.lessonId,
          score: score,
          passed: perfect,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quizSubmitted = true;
        _isSubmittingQuiz = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Your quiz result could not be saved. Please try again.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _bestQuizScore = FirestoreService.bestQuizScore(_bestQuizScore, score);
      _isCompleted = _isCompleted || perfect;
      _quizSubmitted = true;
      _isSubmittingQuiz = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(perfect
            ? 'Perfect! Lesson completed.'
            : 'Score: ${score.toStringAsFixed(0)}%. Retry to improve your score.'),
        backgroundColor: perfect ? AppColors.success : Colors.red,
      ),
    );
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
              child: Image.network(
                lesson.imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
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
          if (lesson.contentValidationStatus.isNotEmpty ||
              lesson.mediaStatus.isNotEmpty) ...[
            const SizedBox(height: 12),
            _LessonInfoCard(
              title: 'Content status',
              child: Text(
                [
                  if (lesson.contentValidationStatus.isNotEmpty)
                    lesson.contentValidationStatus,
                  if (lesson.mediaStatus.isNotEmpty) lesson.mediaStatus,
                ].join(' · '),
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Signs in this lesson (${_signs.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._signs.map((sign) => _SignTile(sign: sign)),
          if (_interactiveActivities.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Interactive practice',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            LessonActivityRunner(
              key: ValueKey('activities_${lesson.id}'),
              activities: _interactiveActivities,
              initialProgress: _activityProgress,
              onAttempt: _recordActivityAttempt,
            ),
          ],
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
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isCompleted ? const Color(0xFFEAF6EE) : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _isCompleted ? AppColors.success : AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCompleted ? 'Lesson complete' : 'Quick quiz',
                  style: TextStyle(
                    color: _isCompleted ? AppColors.success : AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                if (_bestQuizScore > 0) ...[
                  Text(
                    'Best score: ${_bestQuizScore.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  _isCompleted
                      ? 'You answered the quiz perfectly and this lesson is complete.'
                      : 'Answer the quiz 100% to complete this lesson.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_quizQuestions.isNotEmpty) ...[
            for (int index = 0; index < _quizQuestions.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 206,
                        child: Center(
                          child: _buildQuizSignMedia(
                            _quizQuestions[index].sign,
                            lesson.videoUrl,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'What does this sign mean?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quizQuestions[index].options.map((option) {
                          final correctAnswer =
                              _quizQuestions[index].sign.word.trim();
                          final selected = _selectedAnswers[index] == option;
                          final isCorrect =
                              _quizSubmitted && option == correctAnswer;
                          final isWrongSelection = _quizSubmitted &&
                              selected &&
                              option != correctAnswer;

                          return ChoiceChip(
                            label: Text(option),
                            selected: selected,
                            selectedColor: isCorrect
                                ? AppColors.success
                                : (isWrongSelection
                                    ? Colors.red
                                    : AppColors.primary),
                            onSelected: _isCompleted || _isSubmittingQuiz
                                ? null
                                : (_) {
                                    setState(() {
                                      _selectedAnswers[index] = option;
                                      _quizSubmitted = false;
                                    });
                                  },
                            labelStyle: TextStyle(
                              color:
                                  selected ? Colors.white : AppColors.textDark,
                              fontWeight: FontWeight.w700,
                            ),
                            backgroundColor: isCorrect
                                ? Colors.green.shade100
                                : (isWrongSelection
                                    ? Colors.red.shade100
                                    : Colors.white),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            if (_quizSubmitted && !_isCompleted)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  'Not perfect yet. Retry and answer every question correctly to mark this lesson complete.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isCompleted ||
                        _isSubmittingQuiz ||
                        !_allQuestionsAnswered)
                    ? null
                    : _submitQuiz,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isCompleted ? AppColors.success : Colors.red,
                  foregroundColor: Colors.white,
                ),
                icon: _isSubmittingQuiz
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_isCompleted ? Icons.check_circle : Icons.quiz),
                label: Text(
                  _isCompleted
                      ? 'Completed'
                      : (_isSubmittingQuiz ? 'Checking...' : 'Check my quiz'),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_quizQuestions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('There are no quiz questions for this lesson yet.'),
            ),
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
                child: Image.network(
                  sign.imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
        title: Text(sign.word,
            style: const TextStyle(fontWeight: FontWeight.w600)),
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
