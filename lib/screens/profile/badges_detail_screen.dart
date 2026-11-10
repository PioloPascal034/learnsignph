import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';

class BadgesDetailScreen extends StatefulWidget {
  const BadgesDetailScreen({super.key});

  @override
  State<BadgesDetailScreen> createState() => _BadgesDetailScreenState();
}

class _BadgesDetailScreenState extends State<BadgesDetailScreen> {
  final _firestoreService = FirestoreService();
  static const _allBadges = [
    'rising_star',
    'scholar',
    'week_warrior',
    'month_master',
    'lesson_learner',
    'achievement_hunter',
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badges & Achievements'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.streamUserProfile(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final earnedBadges = List<String>.from(data['badges'] ?? []);
          final points = (data['points'] ?? 0) as int;
          final streak = (data['streak'] ?? 0) as int;
          final lessonsCompleted = (data['lessonsCompleted'] ?? 0) as int;

          final badgeDetails = FirestoreService.getBadgeDetails();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Earned count
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${earnedBadges.length}/${_allBadges.length}',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Badges Earned',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Earned badges section
                if (earnedBadges.isNotEmpty) ...[
                  Text(
                    'Achievements Unlocked',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: earnedBadges.length,
                    itemBuilder: (context, index) {
                      final badgeId = earnedBadges[index];
                      final badge = badgeDetails[badgeId];
                      return _buildBadgeCard(badge?['title'] ?? badgeId, badge?['description'] ?? '', true);
                    },
                  ),
                  const SizedBox(height: 32),
                ],

                // Locked badges section
                Text(
                  'Locked Badges',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _allBadges.length - earnedBadges.length,
                  itemBuilder: (context, index) {
                    final badgeId = _allBadges.firstWhere(
                      (id) => !earnedBadges.contains(id),
                      orElse: () => '',
                    );
                    if (badgeId.isEmpty) return const SizedBox();
                    
                    final badge = badgeDetails[badgeId];
                    final progress = _getBadgeProgress(badgeId, points, streak, lessonsCompleted);

                    return _buildLockedBadgeCard(
                      badge?['title'] ?? badgeId,
                      badge?['description'] ?? '',
                      progress,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadgeCard(String title, String description, bool isEarned) {
    return Card(
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title.split(' ').first,
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(height: 8),
              Text(
                title.split(' ').skip(1).join(' '),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedBadgeCard(String title, String description, String progress) {
    return Card(
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.lock,
                  size: 40,
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title.split(' ').first,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              progress,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getBadgeProgress(String badgeId, int points, int streak, int lessons) {
    switch (badgeId) {
      case 'rising_star':
        return '$points / 500 pts';
      case 'scholar':
        return '$points / 1000 pts';
      case 'week_warrior':
        return '$streak / 7 days';
      case 'month_master':
        return '$streak / 30 days';
      case 'lesson_learner':
        return '$lessons / 5 lessons';
      case 'achievement_hunter':
        return '$lessons / 10 lessons';
      default:
        return 'In progress';
    }
  }
}
