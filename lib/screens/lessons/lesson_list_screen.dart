import 'package:flutter/material.dart';
import '../../models/lesson_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';
import 'lesson_detail_screen.dart';

class LessonListScreen extends StatefulWidget {
  const LessonListScreen({super.key});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Matches the scenario/lesson categories used throughout the project
  // documentation (classroom, hospital, government office, emergency, etc.)
  final List<String> _categories = const [
    'All', 'Classroom', 'Hospital', 'Government Office', 'Emergency', 'Everyday',
  ];
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FSL Lessons')),
      body: Column(
        children: [
          _buildCategoryFilter(),
          Expanded(child: _buildLessonList()),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textDark),
            onSelected: (_) => setState(() => _selectedCategory = category),
          );
        },
      ),
    );
  }

  Widget _buildLessonList() {
    final categoryFilter = _selectedCategory == 'All'
        ? null
        : _selectedCategory.toLowerCase().replaceAll(' ', '_');

    return StreamBuilder<List<LessonModel>>(
      stream: _firestoreService.streamLessons(category: categoryFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Something went wrong: ${snapshot.error}'));
        }
        final lessons = snapshot.data ?? [];
        if (lessons.isEmpty) {
          return const Center(
            child: Text('No lessons in this category yet.', style: TextStyle(color: AppColors.textMuted)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: lessons.length,
          itemBuilder: (context, index) => _LessonCard(lesson: lessons[index]),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.sign_language, color: AppColors.primary),
        ),
        title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${lesson.signIds.length} signs \u2022 ${lesson.description}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LessonDetailScreen(lessonId: lesson.id)),
          );
        },
      ),
    );
  }
}
