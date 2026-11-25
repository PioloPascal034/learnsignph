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
    'Greetings',
    'Everyday Words',
    'Food & Drinks',
    'Colors & Time',
  ];
  String _selectedCategory = 'All';
  List<LessonModel> _cachedLessons = const [];
  late Stream<List<LessonModel>> _lessonsStream;

  @override
  void initState() {
    super.initState();
    _updateLessonStream();
  }

  void _updateLessonStream() {
    _cachedLessons = const [];
    _lessonsStream = _firestoreService.streamLessons(
      category: _selectedCategory == 'All'
          ? null
          : _selectedCategory
              .toLowerCase()
              .replaceAll(' & ', ' ')
              .replaceAll(' ', '_'),
    );
  }

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
            onSelected: (_) => setState(() {
              _selectedCategory = category;
              _updateLessonStream();
            }),
          );
        },
      ),
    );
  }

  Widget _buildLessonList() {
    return StreamBuilder<List<LessonModel>>(
      stream: _lessonsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError && _cachedLessons.isEmpty) {
          return _lessonErrorView(snapshot.error!);
        }

        if (snapshot.hasData) {
          _cachedLessons = snapshot.data!;
        }
        var lessons = snapshot.data ?? _cachedLessons;
        lessons = lessons.where((lesson) => lesson.isActive).toList();
        final query = _searchController.text.trim().toLowerCase();
        if (query.isNotEmpty) {
          lessons = lessons.where((lesson) {
            final haystack =
                '${lesson.title} ${lesson.description}'.toLowerCase();
            return haystack.contains(query);
          }).toList();
        }

        if (lessons.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _selectedCategory == 'All' && query.isEmpty
                    ? 'No lessons are available in the configured Firebase project yet.'
                    : 'No lessons match your search.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          );
        }

        return Column(
          children: [
            if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Showing cached lessons. ${_lessonErrorText(snapshot.error!)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: lessons.length,
                itemBuilder: (context, index) =>
                    _LessonCard(lesson: lessons[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _lessonErrorView(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _lessonErrorText(error),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ),
    );
  }

  String _lessonErrorText(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Firestore denied access to lessons for this account. Check the signed-in session and Firestore rules.';
        case 'unauthenticated':
          return 'Your authentication session is unavailable. Reopen the app or sign in again.';
        case 'unavailable':
          return 'Firestore is temporarily unavailable. Previously cached lessons remain usable when available.';
        case 'failed-precondition':
          return 'Firestore could not complete the lesson query because the configured database or index is unavailable.';
        default:
          return 'Firestore could not load lessons (${error.code}).';
      }
    }
    return 'Lessons could not be loaded: $error';
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

class _LessonCard extends StatelessWidget {
  final LessonModel lesson;
  const _LessonCard({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: null,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        tileColor: Colors.white,
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: lesson.imageUrl.trim().isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ContentImage(
                    source: lesson.imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.contain,
                    fallback: const Icon(
                      Icons.sign_language,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : const Icon(
                  Icons.sign_language,
                  color: AppColors.primary,
                ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                lesson.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${lesson.signIds.length} signs \u2022 ${lesson.description}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textMuted,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => LessonDetailScreen(lessonId: lesson.id)),
          );
        },
      ),
    );
  }
}
