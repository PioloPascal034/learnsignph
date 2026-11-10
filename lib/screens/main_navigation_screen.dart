import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/grammar_exercise_model.dart';
import '../services/firestore_service.dart';
import '../services/grammar_firestore_service.dart';
import '../utils/theme.dart';
import 'grammar/grammar_practice_screen.dart';
import 'lessons/lesson_list_screen.dart';
import 'live_practice_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1;

  List<Widget> get _pages => [
        const DashboardScreen(),
        const LessonListScreen(),
        LivePracticeScreen(
          key: const ValueKey('live_practice'),
          isActive: _currentIndex == 2,
        ),
        const GrammarHubScreen(),
        const ProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Lessons',
            ),
            NavigationDestination(
              icon: Icon(Icons.videocam_outlined),
              selectedIcon: Icon(Icons.videocam),
              label: 'Live',
            ),
            NavigationDestination(
              icon: Icon(Icons.quiz_outlined),
              selectedIcon: Icon(Icons.quiz),
              label: 'Grammar',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class GrammarHubScreen extends StatelessWidget {
  const GrammarHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Grammar Activities'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<GrammarExerciseModel>>(
        stream: GrammarFirestoreService().streamExercises(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _GrammarHubMessage(
              message: 'Could not load grammar activities.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final exercises = snapshot.data!;
          if (exercises.isEmpty) {
            return const _GrammarHubMessage(
              message: 'No grammar activities are available yet.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: exercises.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _GrammarActivityCard(
              exercise: exercises[index],
            ),
          );
        },
      ),
    );
  }
}

class _GrammarActivityCard extends StatelessWidget {
  final GrammarExerciseModel exercise;

  const _GrammarActivityCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: const Icon(Icons.quiz_outlined, color: AppColors.primary),
        ),
        title: Text(
          exercise.promptText,
          style: const TextStyle(
              fontWeight: FontWeight.w800, color: AppColors.textDark),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${exercise.category} • ${exercise.difficulty}',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: AppColors.textMuted),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GrammarPracticeScreen(
              exerciseId: exercise.id,
              mode: 'lesson',
            ),
          ),
        ),
      ),
    );
  }
}

class _GrammarHubMessage extends StatelessWidget {
  final String message;

  const _GrammarHubMessage({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _showCompletedLessons(
      BuildContext context, String userId) async {
    final firestore = FirestoreService();
    final completedLessons = await firestore.getUserCompletedLessons(userId);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Completed lessons'),
        content: SizedBox(
          width: double.maxFinite,
          child: completedLessons.isEmpty
              ? const Text('No lessons finished yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: completedLessons.length,
                  itemBuilder: (context, index) {
                    final lesson = completedLessons[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      tileColor: Colors.white,
                      leading: const Icon(Icons.check_circle,
                          color: AppColors.success),
                      title: Text(lesson.title),
                    );
                  },
                ),
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

  Future<void> _showLearnedSigns(BuildContext context, String userId) async {
    final firestore = FirestoreService();
    final signs = await firestore.getUserLearnedSigns(userId);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Signs you learned'),
        content: SizedBox(
          width: double.maxFinite,
          child: signs.isEmpty
              ? const Text('No signs learned yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: signs.length,
                  itemBuilder: (context, index) {
                    final sign = signs[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      tileColor: Colors.white,
                      leading:
                          const Icon(Icons.gesture, color: AppColors.primary),
                      title: Text(sign.word),
                    );
                  },
                ),
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

  Future<void> _showStreakInfo(BuildContext context, String userId) async {
    final firestore = FirestoreService();
    final data = (await firestore.streamUserProfile(userId).first).data() ??
        <String, dynamic>{};
    final streak = (data['streak'] as num?)?.toInt() ?? 0;
    final lastActivity = data['lastActivityDate'] as String?;

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Streak information'),
        content: Text(
          'Current streak: $streak day(s)\nLast activity: ${lastActivity ?? 'Not yet recorded'}',
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

  Future<void> _showBadges(BuildContext context, String userId) async {
    final firestore = FirestoreService();
    final data = (await firestore.streamUserProfile(userId).first).data() ??
        <String, dynamic>{};
    final badges = List<String>.from(data['badges'] ?? []);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Badges earned'),
        content: SizedBox(
          width: double.maxFinite,
          child: badges.isEmpty
              ? const Text('No badges unlocked yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: badges.length,
                  itemBuilder: (context, index) {
                    final badge = badges[index];
                    final details = FirestoreService.getBadgeDetails()[badge];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      tileColor: Colors.white,
                      leading: const Icon(Icons.workspace_premium,
                          color: Color(0xFF8E5DEB)),
                      title: Text(details?['title'] ?? badge),
                      subtitle: details != null
                          ? Text(details['description'] ?? '')
                          : null,
                    );
                  },
                ),
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().streamUserProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Could not load dashboard statistics.')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final points = (data['points'] as num?)?.toInt() ?? 0;
        final level = (data['level'] as num?)?.toInt() ??
            FirestoreService.calculateLevelFromPoints(points);
        final nextLevelThreshold = level * 500;
        final pointsLeft = (nextLevelThreshold - points).clamp(0, 999999);
        final progressValue =
            nextLevelThreshold == 0 ? 0.0 : (points % 500) / 500;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Learning Journey',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5D9B6B),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Level $level',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'FSL Learner',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '$points pts',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.emoji_people,
                              color: Colors.white, size: 30),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  InkWell(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Level progress'),
                        content: Text(
                          'You have $points points.\n\nTo reach Level ${level + 1}, you need $pointsLeft more points.\nCurrent target: $nextLevelThreshold total points.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 0.8,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                'Level $level',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$nextLevelThreshold pts → Level ${level + 1}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progressValue,
                              minHeight: 10,
                              backgroundColor: const Color(0xFFE4ECF4),
                              color: const Color(0xFFE0A13D),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$pointsLeft pts to next level',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      StatsCard(
                        label: 'Lessons Done',
                        value:
                            '${(data['lessonsCompleted'] as num?)?.toInt() ?? 0}',
                        icon: Icons.menu_book,
                        color: AppColors.primary,
                        onTap: () => _showCompletedLessons(context, user.uid),
                      ),
                      StatsCard(
                        label: 'Signs Learned',
                        value:
                            '${(data['signsLearned'] as num?)?.toInt() ?? 0}',
                        icon: Icons.gesture,
                        color: const Color(0xFFE0A13D),
                        onTap: () => _showLearnedSigns(context, user.uid),
                      ),
                      StatsCard(
                        label: 'Streak',
                        value: '${(data['streak'] as num?)?.toInt() ?? 0}🔥',
                        icon: Icons.local_fire_department,
                        color: const Color(0xFF57A96A),
                        onTap: () => _showStreakInfo(context, user.uid),
                      ),
                      StatsCard(
                        label: 'Badges',
                        value: '${(data['badges'] as List?)?.length ?? 0}',
                        icon: Icons.workspace_premium,
                        color: const Color(0xFF8E5DEB),
                        onTap: () => _showBadges(context, user.uid),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class StatsCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StatsCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ProfileScreen has been moved to lib/screens/profile_screen.dart
// This file now only contains the navigation shell and dashboard/live practice screens.
