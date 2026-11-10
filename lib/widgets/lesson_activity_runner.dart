import 'package:flutter/material.dart';
import '../models/lesson_activity_model.dart';
import '../models/lesson_activity_progress_model.dart';
import '../services/lesson_activity_engine.dart';
import '../utils/theme.dart';
import 'sign_gif_tile.dart';
import 'video_player_widget.dart';

class LessonActivityRunner extends StatefulWidget {
  final List<LessonActivityModel> activities;
  final ValueChanged<double>? onCompleted;
  final Map<String, LessonActivityProgressModel> initialProgress;
  final Future<void> Function(
      LessonActivityModel activity, double score, bool passed)? onAttempt;

  const LessonActivityRunner({
    super.key,
    required this.activities,
    this.onCompleted,
    this.initialProgress = const {},
    this.onAttempt,
  });

  @override
  State<LessonActivityRunner> createState() => _LessonActivityRunnerState();
}

class _LessonActivityRunnerState extends State<LessonActivityRunner> {
  int _index = 0;
  int _correctAnswers = 0;
  bool _submitted = false;
  bool _finished = false;
  bool _isSaving = false;
  String? _answer;
  List<String> _orderedItems = [];
  final Map<String, String> _matching = {};

  LessonActivityModel get _activity => widget.activities[_index];

  @override
  void initState() {
    super.initState();
    _resetActivity();
  }

  void _resetActivity() {
    _submitted = false;
    _answer = null;
    _orderedItems = [..._activity.items];
    _matching.clear();
  }

  Future<void> _checkAnswer() async {
    if (_submitted) return;
    final correct = LessonActivityEngine.isCorrect(
      _activity,
      answer: _answer,
      orderedItems: _orderedItems,
      matching: _matching,
    );
    setState(() {
      _submitted = true;
      if (correct) _correctAnswers++;
    });
    if (widget.onAttempt != null) {
      setState(() => _isSaving = true);
      try {
        await widget.onAttempt!(
          _activity,
          correct ? 100 : 0,
          correct,
        );
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  void _nextActivity() {
    if (!_submitted) return;
    if (_index == widget.activities.length - 1) {
      final score = LessonActivityEngine.score(
        correct: _correctAnswers,
        total: widget.activities.length,
      );
      setState(() => _finished = true);
      widget.onCompleted?.call(score);
      return;
    }
    setState(() {
      _index++;
      _resetActivity();
    });
  }

  void _retryActivity() {
    setState(_resetActivity);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activities.isEmpty) return const SizedBox.shrink();
    if (_finished) return _buildSummary();

    final activity = _activity;
    final progress = (_index + 1) / widget.activities.length;
    final correct = _submitted &&
        LessonActivityEngine.isCorrect(
          activity,
          answer: _answer,
          orderedItems: _orderedItems,
          matching: _matching,
        );

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'GUIDED PRACTICE',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Text('${_index + 1}/${widget.activities.length}'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              color: AppColors.primary,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 16),
            if (activity.instruction.trim().isNotEmpty)
              Text(
                activity.instruction,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (activity.prompt.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                activity.prompt,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
            if (widget.initialProgress[activity.id] != null) ...[
              const SizedBox(height: 6),
              Text(
                'Saved best: ${widget.initialProgress[activity.id]!.bestScore.toStringAsFixed(0)}% '
                '(${widget.initialProgress[activity.id]!.attempts} attempt${widget.initialProgress[activity.id]!.attempts == 1 ? '' : 's'})',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            _buildActivityBody(activity),
            if (_submitted) ...[
              const SizedBox(height: 14),
              _FeedbackBanner(correct: correct),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (_submitted && !correct)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _retryActivity,
                      child: const Text('Retry'),
                    ),
                  ),
                if (_submitted && !correct) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _isSaving
                        ? null
                        : (_submitted ? _nextActivity : _checkAnswer),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_submitted
                            ? (_index == widget.activities.length - 1
                                ? 'Finish'
                                : 'Next activity')
                            : 'Check answer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityBody(LessonActivityModel activity) {
    switch (activity.type) {
      case LessonActivityType.identification:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActivityMedia(activity: activity),
            const SizedBox(height: 12),
            _buildOptions(activity.options),
          ],
        );
      case LessonActivityType.conversation:
        return _buildOptions(activity.options);
      case LessonActivityType.ordering:
        return _buildOrdering(activity);
      case LessonActivityType.matching:
        return _buildMatching(activity);
      case LessonActivityType.mixed:
        return const Text('This activity group is empty.');
    }
  }

  Widget _buildOptions(List<String> options) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (option) => ChoiceChip(
              label: Text(option),
              selected: _answer == option,
              onSelected:
                  _submitted ? null : (_) => setState(() => _answer = option),
            ),
          )
          .toList(),
    );
  }

  Widget _buildOrdering(LessonActivityModel activity) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _orderedItems.length,
      onReorderItem: _submitted
          ? (_, __) {}
          : (oldIndex, newIndex) {
              setState(() {
                final item = _orderedItems.removeAt(oldIndex);
                _orderedItems.insert(newIndex, item);
              });
            },
      itemBuilder: (context, index) => Card(
        key: ValueKey('${activity.id}_${_orderedItems[index]}'),
        color: AppColors.surface,
        child: ListTile(
          leading: const Icon(Icons.drag_handle),
          title: Text(_orderedItems[index]),
        ),
      ),
    );
  }

  Widget _buildMatching(LessonActivityModel activity) {
    final rightOptions = activity.pairs.map((pair) => pair.value).toList();
    return Column(
      children: activity.pairs
          .map(
            (pair) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DropdownButtonFormField<String>(
                initialValue: _matching[pair.key],
                decoration: InputDecoration(
                  labelText: pair.key,
                  border: const OutlineInputBorder(),
                ),
                items: rightOptions
                    .map((option) => DropdownMenuItem(
                          value: option,
                          child: Text(option),
                        ))
                    .toList(),
                onChanged: _submitted
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _matching[pair.key] = value);
                        }
                      },
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSummary() {
    final score = LessonActivityEngine.score(
      correct: _correctAnswers,
      total: widget.activities.length,
    );
    return Card(
      elevation: 0,
      color: const Color(0xFFEAF6EE),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.celebration, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Practice complete — ${score.toStringAsFixed(0)}% correct.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityMedia extends StatelessWidget {
  final LessonActivityModel activity;

  const _ActivityMedia({required this.activity});

  @override
  Widget build(BuildContext context) {
    if (activity.mediaUrl.trim().isEmpty) {
      return const SignGifTile(
        gifUrl: '',
        word: '',
        isPlaceholder: true,
      );
    }
    final isVideo = activity.mediaType == 'video' ||
        activity.mediaUrl.toLowerCase().endsWith('.mp4') ||
        activity.mediaUrl.toLowerCase().endsWith('.mov');
    if (isVideo) return SignVideoPlayer(videoUrl: activity.mediaUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        activity.mediaUrl,
        height: 170,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          height: 170,
          color: AppColors.surface,
          alignment: Alignment.center,
          child: const Text('Reference media unavailable'),
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  final bool correct;

  const _FeedbackBanner({required this.correct});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: correct
            ? AppColors.success.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        correct
            ? 'Correct! Great work.'
            : 'Not quite. Try this activity again.',
        style: TextStyle(
          color: correct ? AppColors.success : Colors.red.shade700,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
