import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/lesson_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';
import '../../widgets/content_image.dart';
import 'lesson_detail_screen.dart';

class LessonListScreen extends StatefulWidget {
  const LessonListScreen({super.key});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = const [
    'All',
    'Alphabet',
    'Numbers',
    'Basic Signs',
    'Greetings',
    'Daily Life',
    'Family',
    'Education',
    'Emergency',
    'Travel',
    'Community',
    'Health',
  ];
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Your Lessons',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const _StreakPill(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.14),
                      hintText: 'Search lessons',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                      prefixIcon: Icon(Icons.search,
                          color: Colors.white.withValues(alpha: 0.8)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildCategoryFilter(),
            Expanded(child: _buildLessonList()),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            showCheckmark: false,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
            onSelected: (_) => setState(() => _selectedCategory = category),
          );
        },
      ),
    );
  }

  Widget _buildLessonList() {
    final categoryFilter = _selectedCategory == 'All'
        ? null
        : _selectedCategory
            .toLowerCase()
            .replaceAll(' & ', ' ')
            .replaceAll(' ', '_');

    return StreamBuilder<List<LessonModel>>(
      stream: _firestoreService.streamLessons(category: categoryFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Something went wrong: ${snapshot.error}'));
        }

        var lessons = snapshot.data ?? [];
        final query = _searchController.text.trim().toLowerCase();
        if (query.isNotEmpty) {
          lessons = lessons.where((lesson) {
            final haystack =
                '${lesson.title} ${lesson.description}'.toLowerCase();
            return haystack.contains(query);
          }).toList();
        }

        if (lessons.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No lessons match your search.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          itemCount: lessons.length,
          itemBuilder: (context, index) => _LessonCard(lesson: lessons[index]),
        );
      },
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill();

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Text(
        'Streak unavailable',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      );
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: FirestoreService().streamStreakInfo(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 72,
            height: 16,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white24,
              color: Colors.white70,
            ),
          );
        }
        final streak = snapshot.data!['streak'] as int? ?? 0;
        return Text(
          '$streak day streak',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        );
      },
    );
  }
}

class _LessonCard extends StatefulWidget {
  final LessonModel lesson;
  const _LessonCard({required this.lesson});

  @override
  State<_LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<_LessonCard> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isCompleted = false;
  bool _isLoading = true;
  bool _progressLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final progress =
          await _firestoreService.getLessonProgress(userId, widget.lesson.id);
      if (!mounted) return;
      setState(() {
        _isCompleted = progress?.status == 'completed';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _progressLoadFailed = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _isCompleted ? const Color(0xFFEAF6EE) : null,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        tileColor: Colors.white,
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _isCompleted
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: widget.lesson.imageUrl.trim().isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ContentImage(
                    source: widget.lesson.imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    fallback: Icon(
                      _isCompleted ? Icons.check_circle : Icons.sign_language,
                      color:
                          _isCompleted ? AppColors.success : AppColors.primary,
                    ),
                  ),
                )
              : Icon(
                  _isCompleted ? Icons.check_circle : Icons.sign_language,
                  color: _isCompleted ? AppColors.success : AppColors.primary,
                ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.lesson.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (!_isLoading && _isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.lesson.signIds.length} signs \u2022 ${widget.lesson.description}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (_progressLoadFailed)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Progress unavailable',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              )
            else if (!_isLoading && !_isCompleted)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Answer the quiz 100% to complete this lesson',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        trailing: Icon(
          _isCompleted ? Icons.check : Icons.chevron_right,
          color: _isCompleted ? AppColors.success : AppColors.textMuted,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => LessonDetailScreen(lessonId: widget.lesson.id)),
          );
        },
      ),
    );
  }
}
