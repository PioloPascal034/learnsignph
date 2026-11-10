import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';

class StreakDetailScreen extends StatefulWidget {
  const StreakDetailScreen({super.key});

  @override
  State<StreakDetailScreen> createState() => _StreakDetailScreenState();
}

class _StreakDetailScreenState extends State<StreakDetailScreen> {
  final _firestoreService = FirestoreService();

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
        title: const Text('Streak Information'),
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
          final streak = (data['streak'] ?? 0) as int;
          final lastActivityStr = data['lastActivityDate'] as String?;
          final lessonsCompleted = (data['lessonsCompleted'] ?? 0) as int;

          DateTime? lastActivity;
          if (lastActivityStr != null) {
            lastActivity = DateTime.tryParse(lastActivityStr);
          }

          final now = DateTime.now();
          bool isStreakActive = false;

          if (lastActivity != null) {
            final daysDiff = now.difference(lastActivity).inDays;
            if (daysDiff == 0 || daysDiff == 1) {
              isStreakActive = true;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Big streak display
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '🔥',
                              style: TextStyle(fontSize: 56),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$streak',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Day Streak',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Status card
                Card(
                  elevation: 0,
                  color: isStreakActive
                      ? const Color(0xFFF0F9FF)
                      : const Color(0xFFFFF5F5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isStreakActive
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          isStreakActive ? Icons.check_circle : Icons.info,
                          color: isStreakActive ? AppColors.primary : Colors.red,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isStreakActive ? 'Streak Active! 🎉' : 'Streak Broken',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isStreakActive
                                      ? AppColors.primary
                                      : Colors.red,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isStreakActive
                                    ? 'Keep it up! Complete a lesson today'
                                    : 'Start a new streak by completing a lesson',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Info sections
                Text(
                  'How Streaks Work',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildInfoTile(
                  '📅 Daily Activity',
                  'Complete at least one lesson per day to maintain your streak',
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  '⏰ Daily Reset',
                  'Your daily activity resets at midnight (00:00) in your timezone',
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  '🔄 Streak Break',
                  'Miss a day and your streak resets to 0',
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  '🏆 Milestones',
                  'Reach 7 days for "Week Warrior" badge\nReach 30 days for "Month Master" badge',
                ),
                const SizedBox(height: 32),

                // Stats
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildStatRow('Current Streak', '$streak days'),
                      const SizedBox(height: 12),
                      _buildStatRow(
                        'Last Activity',
                        lastActivity != null
                            ? _formatDate(lastActivity)
                            : 'Never',
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow(
                        'Lessons Completed',
                        '$lessonsCompleted lessons',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTile(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    return '${date.month}/${date.day}/${date.year}';
  }
}
