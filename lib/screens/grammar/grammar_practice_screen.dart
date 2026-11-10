import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/grammar_exercise_model.dart';
import '../../models/sign_model.dart';
import '../../services/grammar_firestore_service.dart';
import '../../utils/theme.dart';
import '../../widgets/sign_gif_tile.dart';
import '../../widgets/content_image.dart';

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

  const GrammarPracticeScreen({
    super.key,
    required this.exerciseId,
    this.mode = 'lesson',
  });

  @override
  State<GrammarPracticeScreen> createState() => _GrammarPracticeScreenState();
}

class _GrammarPracticeScreenState extends State<GrammarPracticeScreen> {
  final GrammarFirestoreService _grammarService = GrammarFirestoreService();

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
      if (!exercise.hasValidSentenceOrder) {
        throw StateError('This exercise has incomplete or invalid tile data.');
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
    setState(() {
      final slotIndex = _slots.indexOf(signId);
      if (slotIndex != -1) _slots[slotIndex] = null;
      if (!_pool.contains(signId)) _pool.add(signId);
      _lastResultCorrect = null;
    });
  }

  bool get _allSlotsFilled => _slots.every((s) => s != null);

  Future<void> _checkAnswer() async {
    if (_exercise == null || !_allSlotsFilled || _isSubmitting) return;

    // tiles are stored with 1-based correctPosition per the schema example.
    final correctOrder = _exercise!.correctSignOrder;

    final isCorrect =
        List.generate(_slots.length, (i) => _slots[i] == correctOrder[i])
            .every((v) => v);

    setState(() {
      _lastResultCorrect = isCorrect;
      _earnedPointsThisAttempt = 0;
      _isSubmitting = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw StateError('Sign in to save your exercise progress.');
      }
      await _grammarService
          .recordAttempt(
            userId: userId,
            exerciseId: widget.exerciseId,
            mode: widget.mode,
            wasCorrect: isCorrect,
          )
          .timeout(const Duration(seconds: 20));
      if (mounted && isCorrect) {
        setState(
          () => _earnedPointsThisAttempt = widget.mode == 'test' ? 60 : 40,
        );
      }
    } on TimeoutException {
      if (mounted) {
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
                                    'SENTENCE ORDER',
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
                              'Arrange the signs to say: "${_exercise!.promptText}"',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                                height: 1.3,
                              ),
                            ),
                            if (_exercise!.imageUrl.trim().isNotEmpty) ...[
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ContentImage(
                                  source: _exercise!.imageUrl,
                                  width: double.infinity,
                                  height: 150,
                                  fit: BoxFit.cover,
                                  fallback: Container(
                                    height: 150,
                                    color: AppColors.surface,
                                    alignment: Alignment.center,
                                    child:
                                        const Text('Illustration unavailable'),
                                  ),
                                ),
                              ),
                            ],
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
                            if (_exercise!
                                .contentValidationStatus.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                _exercise!.contentValidationStatus,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'YOUR ANSWER',
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
                              color: const Color(0xFFF1C867),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$_earnedPointsThisAttempt pts',
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
                        'SIGN BANK — DRAG TO ARRANGE',
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
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _resetAttempt,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.textDark,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side:
                                      const BorderSide(color: AppColors.border),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: (_allSlotsFilled && !_isSubmitting)
                                  ? _checkAnswer
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Text('Check Answer'),
                            ),
                          ),
                        ],
                      ),
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
      onWillAcceptWithDetails: (_) => !_isSubmitting,
      onAcceptWithDetails: (details) {
        if (!_isSubmitting) _placeTile(details.data, index);
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
                ? SignGifTile(gifUrl: sign.gifUrl, word: sign.word)
                : const SignGifTile(gifUrl: '', word: '', isPlaceholder: true),
          ),
        );
      },
    );
  }

  Widget _buildDraggableTile(String signId) {
    final sign = _signsById[signId];
    if (sign == null) return const SizedBox.shrink();

    final tile =
        SignGifTile(gifUrl: sign.gifUrl, word: sign.word, isCompact: true);

    return Draggable<String>(
      data: signId,
      maxSimultaneousDrags: _isSubmitting ? 0 : null,
      feedback: Material(
          color: Colors.transparent,
          child: Opacity(opacity: 0.85, child: tile)),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: tile,
    );
  }

  Widget _buildResultBanner() {
    final correct = _lastResultCorrect!;
    final pointsLabel = correct
        ? '+$_earnedPointsThisAttempt pts earned'
        : 'No points earned this round';

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
              correct
                  ? 'Correct! Well done. $pointsLabel.'
                  : 'Not quite \u2014 try rearranging the signs. $pointsLabel.',
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
}
