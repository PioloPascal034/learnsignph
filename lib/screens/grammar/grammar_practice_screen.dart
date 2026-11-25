import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/grammar_exercise_model.dart';
import '../../models/sign_model.dart';
import '../../services/grammar_firestore_service.dart';
import '../../utils/theme.dart';
import '../../widgets/sign_gif_tile.dart';
import '../../widgets/video_player_widget.dart';

/// Drag-and-drop grammar exercise screen.
///
/// [exerciseId] identifies which grammarExercises document to load.
/// [mode] is 'lesson' (in-lesson practice, low stakes) or 'test'
/// (part of the standalone category-based grammar test) - this is passed
/// straight through to GrammarProgress so the two contexts stay separate
/// per the schema design (GrammarProgress.mode).
class GrammarPracticeScreen extends StatefulWidget {
  final String exerciseId;
  final String mode;
  final GrammarFirestoreService? service;

  const GrammarPracticeScreen({
    super.key,
    required this.exerciseId,
    this.mode = 'lesson',
    this.service,
  });

  @override
  State<GrammarPracticeScreen> createState() => _GrammarPracticeScreenState();
}

class _GrammarPracticeScreenState extends State<GrammarPracticeScreen> {
  late final GrammarFirestoreService _grammarService =
      widget.service ?? GrammarFirestoreService();

  GrammarExerciseModel? _exercise;
  Map<String, SignModel> _signsById = {};

  // Ordered slots the learner fills in; null = empty slot.
  List<String?> _slots = [];
  // Tiles still available to drag (signIds not yet placed in a slot).
  List<String> _pool = [];

  bool _isLoading = true;
  bool? _lastResultCorrect; // null = not checked yet this attempt
  bool _isSubmitting = false;
  String? _loadError;
  int _earnedPointsThisAttempt = 0;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _loadExercise();
  }

  Future<void> _loadExercise() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final exercise = await _grammarService
          .getExercise(widget.exerciseId)
          .timeout(const Duration(seconds: 20));
      if (exercise == null) {
        throw StateError('This exercise could not be found.');
      }
      if (exercise.tiles.isEmpty) {
        throw StateError('This exercise does not contain any sign tiles.');
      }
      final signIds = exercise.tiles.map((tile) => tile.signId).toList();
      if (!exercise.canPracticeSentenceOrder) {
        throw StateError(
            'This activity is not ready for grammar practice. Please choose another exercise.');
      }

      final signs = await _grammarService
          .getSignsForExercise(exercise)
          .timeout(const Duration(seconds: 20));
      if (signIds.any((signId) => !signs.containsKey(signId))) {
        throw StateError(
            'One or more signs in this exercise could not be found.');
      }
      signIds.shuffle();

      if (!mounted) return;
      setState(() {
        _exercise = exercise;
        _signsById = signs;
        _pool = signIds;
        _slots = List<String?>.filled(exercise.tiles.length, null);
        _isLoading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loadError =
            'Loading this exercise took too long. Check your connection and try again.';
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error is StateError
            ? error.message
            : 'Could not load this exercise. Check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  void _placeTile(String signId, int slotIndex) {
    if (_lastResultCorrect != null || _isSubmitting) return;
    setState(() {
      // If the target slot already holds a tile, return it to the pool first.
      final existing = _slots[slotIndex];
      if (existing != null) _pool.add(existing);

      _pool.remove(signId);
      _slots[slotIndex] = signId;
      _lastResultCorrect = null; // editing invalidates the last check
    });
  }

  void _returnTileToPool(String signId) {
    if (_lastResultCorrect != null || _isSubmitting) return;
    setState(() {
      final slotIndex = _slots.indexOf(signId);
      if (slotIndex != -1) _slots[slotIndex] = null;
      if (!_pool.contains(signId)) _pool.add(signId);
      _lastResultCorrect = null;
    });
  }

  bool get _allSlotsFilled => _slots.every((s) => s != null);

  Future<void> _checkAnswer() async {
    if (_exercise == null ||
        !_allSlotsFilled ||
        _isSubmitting ||
        (_lastResultCorrect != null && !_saveFailed)) {
      return;
    }

    // tiles are stored with 1-based correctPosition per the schema example.
    final correctOrder = _exercise!.correctSignOrder;

    final isCorrect =
        List.generate(_slots.length, (i) => _slots[i] == correctOrder[i])
            .every((v) => v);

    setState(() {
      _lastResultCorrect = isCorrect;
      _earnedPointsThisAttempt = 0;
      _saveFailed = false;
      _isSubmitting = true;
    });

    try {
      final userId = _grammarService.currentUserId;
      if (userId == null) {
        throw StateError('Sign in to save your exercise progress.');
      }
      final earnedPoints = await _grammarService
          .recordAttempt(
            userId: userId,
            exerciseId: widget.exerciseId,
            mode: widget.mode,
            wasCorrect: isCorrect,
          )
          .timeout(const Duration(seconds: 20));
      if (mounted && isCorrect) {
        setState(
          () => _earnedPointsThisAttempt = earnedPoints,
        );
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _saveFailed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Your answer was checked, but saving progress took too long. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saveFailed = true);
        debugPrint('[Grammar] progress save failed: $error');
        final message = error is StateError
            ? error.message
            : 'Your answer was checked, but progress could not be saved. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetAttempt() {
    setState(() {
      final signIds = _exercise!.tiles.map((t) => t.signId).toList()..shuffle();
      _pool = signIds;
      _slots = List<String?>.filled(_exercise!.tiles.length, null);
      _lastResultCorrect = null;
      _earnedPointsThisAttempt = 0;
      _saveFailed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Grammar Practice')),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Grammar Practice')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.textMuted, size: 36),
                const SizedBox(height: 12),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadExercise,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_exercise == null) {
      return const Scaffold(body: Center(child: Text('Exercise not found.')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Grammar Practice'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(
                children: [
                  const Icon(Icons.drag_indicator, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'SENTENCE ORDER',
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    _exercise!.difficulty,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                color: AppColors.background,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'TARGET MEANING',
                                    style: TextStyle(
                                      fontSize: 13,
                                      letterSpacing: 0.8,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4DDAA),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _exercise!.difficulty,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _exercise!.learnerPrompt,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Study the example first. Then arrange the word tiles to match its order. Tap a tile to fill the next space, or drag it into place.',
                            ),
                            _buildStudyGuide(),
                            if (_exercise!.explanation.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                _exercise!.explanation,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          const Text(
                            'YOUR ANSWER',
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1C867),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _pointsLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children:
                            List.generate(_slots.length, (i) => _buildSlot(i)),
                      ),
                      const SizedBox(height: 18),
                      if (_lastResultCorrect != null) _buildResultBanner(),
                      const SizedBox(height: 24),
                      const Text(
                        'SIGN BANK — TAP OR DRAG TO ARRANGE',
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: 0.7,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F0F7),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: AppColors.border, width: 1.2),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: _pool
                              .map((signId) => _buildDraggableTile(signId))
                              .toList(),
                        ),
                      ),
                      if (_saveFailed) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _isSubmitting ? null : _checkAnswer,
                          icon: const Icon(Icons.sync),
                          label: const Text('Retry saving progress'),
                        ),
                      ] else if (_lastResultCorrect == null) ...[
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_allSlotsFilled && !_isSubmitting)
                                ? _checkAnswer
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.card,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.card),
                                    ),
                                  )
                                : const Text('Check Answer'),
                          ),
                        ),
                      ] else if (_lastResultCorrect == false) ...[
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _resetAttempt,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.textDark,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: const Text('Restart'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(int index) {
    final placedSignId = _slots[index];
    final sign = placedSignId != null ? _signsById[placedSignId] : null;

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) =>
          !_isSubmitting && _lastResultCorrect == null,
      onAcceptWithDetails: (details) {
        if (!_isSubmitting && _lastResultCorrect == null) {
          _placeTile(details.data, index);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: isHovering
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                )
              : null,
          child: GestureDetector(
            onTap: placedSignId != null && !_isSubmitting
                ? () => _returnTileToPool(placedSignId)
                : null,
            child: sign != null
                ? _signTile(sign)
                : const SignGifTile(gifUrl: '', word: '', isPlaceholder: true),
          ),
        );
      },
    );
  }

  Widget _buildDraggableTile(String signId) {
    final sign = _signsById[signId];
    if (sign == null) return const SizedBox.shrink();

    final tile = _signTile(sign, compact: true);

    return Draggable<String>(
      data: signId,
      maxSimultaneousDrags:
          _isSubmitting || _lastResultCorrect != null ? 0 : null,
      feedback: Material(
          color: Colors.transparent,
          child: Opacity(opacity: 0.85, child: tile)),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: GestureDetector(
        onTap: () {
          final nextSlot = _slots.indexOf(null);
          if (nextSlot >= 0) _placeTile(signId, nextSlot);
        },
        child: tile,
      ),
    );
  }

  Widget _buildResultBanner() {
    final correct = _lastResultCorrect!;
    final pointsLabel = _isSubmitting
        ? 'Saving progress…'
        : _saveFailed
            ? 'Progress is not saved yet. Retry saving below.'
            : correct
                ? _earnedPointsThisAttempt > 0
                    ? '+$_earnedPointsThisAttempt pts earned'
                    : 'Already completed; no additional points'
                : 'Review the example before trying again';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: correct
            ? AppColors.success.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: correct ? AppColors.success : Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(correct ? Icons.check_circle : Icons.cancel_outlined,
              color: correct ? AppColors.success : Colors.red.shade400,
              size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              correct ? 'Correct! $pointsLabel.' : 'Not quite. $pointsLabel.',
              style: TextStyle(
                color: correct ? AppColors.success : Colors.red.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _pointsLabel {
    if (_isSubmitting) return 'Saving…';
    if (_saveFailed) return 'Not saved';
    if (_lastResultCorrect == null) {
      return 'First completion: ${GrammarFirestoreService.completionReward} pts';
    }
    if (_lastResultCorrect == false) return 'Try again';
    return _earnedPointsThisAttempt > 0
        ? '+$_earnedPointsThisAttempt pts'
        : 'Completed';
  }

  Widget _signTile(SignModel sign, {bool compact = false}) {
    if (sign.gifUrl.trim().isNotEmpty) {
      return SignGifTile(
          gifUrl: sign.gifUrl, word: sign.word, isCompact: compact);
    }
    return Container(
      width: 106,
      constraints: const BoxConstraints(minHeight: 72),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(sign.word,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildStudyGuide() {
    final signs =
        _exercise!.correctSignOrder.map((id) => _signsById[id]!).toList();
    return Material(
      color: Colors.transparent,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Study the example'),
        subtitle: const Text('See the order before answering'),
        children: [
          const Text('Example order for this exercise:'),
          const SizedBox(height: 8),
          for (final entry in signs.asMap().entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${entry.key + 1}')),
              title: Text(entry.value.word),
              subtitle: Text(entry.value.videoUrl.trim().isNotEmpty ||
                      entry.value.gifUrl.trim().isNotEmpty
                  ? 'Tap to watch this sign'
                  : 'No sign demonstration is available yet'),
              trailing: entry.value.videoUrl.trim().isNotEmpty ||
                      entry.value.gifUrl.trim().isNotEmpty
                  ? const Icon(Icons.play_circle_outline)
                  : null,
              onTap: entry.value.videoUrl.trim().isNotEmpty ||
                      entry.value.gifUrl.trim().isNotEmpty
                  ? () => _showSign(entry.value)
                  : null,
            ),
        ],
      ),
    );
  }

  void _showSign(SignModel sign) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sign.word),
        content: SizedBox(
          width: 320,
          child: sign.videoUrl.trim().isNotEmpty
              ? SignVideoPlayer(videoUrl: sign.videoUrl, autoPlay: true)
              : SignGifTile(
                  gifUrl: sign.gifUrl, word: sign.word, isLarge: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
