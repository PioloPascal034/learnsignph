import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../utils/theme.dart';
import 'profile/account_settings_screen.dart';
import 'profile/sign_gif_manager_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _firestoreService = FirestoreService();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    try {
      // Re-authenticate with current password
      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: _currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // Update to new password
      await user.updatePassword(_newPasswordController.text);

      if (mounted) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password updated successfully!'),
              backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.message}'),
              backgroundColor: Colors.red),
        );
      }
    }
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
      stream: _firestoreService.streamUserProfile(user.uid),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final displayName = (data['displayName'] as String?) ??
            user.displayName ??
            user.email?.split('@').first ??
            'Learner';
        final email = user.email ?? 'No email';
        final canManageSigns =
            email.toLowerCase() == 'marcronielbisac@gmail.com';
        final points = (data['points'] as num?)?.toInt() ?? 0;
        final level = (data['level'] as num?)?.toInt() ??
            FirestoreService.calculateLevelFromPoints(points);
        final ageValue = (data['age'] as num?)?.toInt();
        final firestorePhotoUrl = (data['photoUrl'] as String?)?.trim();
        final authPhotoUrl = (user.photoURL ?? '').trim();
        final photoUrl = (firestorePhotoUrl?.isNotEmpty ?? false)
            ? firestorePhotoUrl
            : (authPhotoUrl.isNotEmpty ? authPhotoUrl : null);
        final initials = displayName.trim().isNotEmpty
            ? displayName
                .trim()
                .split(RegExp(r'\s+'))
                .take(2)
                .map((part) => part[0].toUpperCase())
                .join()
            : 'L';

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Profile'),
            centerTitle: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: Column(
                children: [
                  // Profile Header
                  Row(
                    children: [
                      photoUrl != null && photoUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                photoUrl,
                                width: 62,
                                height: 62,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 62,
                                    height: 62,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Center(
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
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
                          'Lvl $level',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Personal information summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ABOUT YOU',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _InfoRow(label: 'Name', value: displayName),
                        const Divider(height: 18),
                        _InfoRow(
                            label: 'Age',
                            value: ageValue != null ? '$ageValue' : 'Not set'),
                        const Divider(height: 18),
                        _InfoRow(
                            label: 'Bio',
                            value:
                                (data['bio'] as String?)?.trim().isNotEmpty ==
                                        true
                                    ? data['bio'] as String
                                    : 'No bio yet'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Account Settings
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ACCOUNT',
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (canManageSigns) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.gif_box_outlined,
                                  color: AppColors.primary),
                              title: const Text('Manage Signs & Lessons'),
                              subtitle: const Text(
                                  'Add signs, lessons, images, GIFs, and videos'),
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const SignGifManagerScreen()),
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.settings_outlined,
                                color: AppColors.primary),
                            title: const Text('Account Settings'),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AccountSettingsScreen()),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.lock_outline,
                                color: AppColors.primary),
                            title: const Text('Change Password'),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _showChangePasswordDialog(context),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading:
                                const Icon(Icons.logout, color: Colors.red),
                            title: const Text('Log Out',
                                style: TextStyle(color: Colors.red)),
                            trailing: const Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.red),
                            onTap: () => _showLogoutDialog(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _updatePassword();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
