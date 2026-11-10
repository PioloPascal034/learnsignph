import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_profile_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _firestoreService = FirestoreService();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _ageController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isUploadingProfilePhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
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
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final displayName =
              (data['displayName'] as String?) ?? user.displayName ?? '';
          final bio = (data['bio'] as String?) ?? '';
          final age = (data['age'] as num?)?.toInt();
          final firestorePhotoUrl = (data['photoUrl'] as String?)?.trim() ?? '';
          final authPhotoUrl = (user.photoURL ?? '').trim();
          final photoUrl =
              firestorePhotoUrl.isNotEmpty ? firestorePhotoUrl : authPhotoUrl;

          _nameController.text = displayName;
          _bioController.text = bio;
          if (age != null) _ageController.text = '$age';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile picture section
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          photoUrl.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    photoUrl,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.primary
                                              .withValues(alpha: 0.1),
                                        ),
                                        child: Center(
                                          child: Text(
                                            displayName.isNotEmpty
                                                ? displayName
                                                    .split(' ')
                                                    .take(2)
                                                    .map((e) =>
                                                        e[0].toUpperCase())
                                                    .join()
                                                : 'L',
                                            style: const TextStyle(
                                              fontSize: 40,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                  ),
                                  child: Center(
                                    child: Text(
                                      displayName.isNotEmpty
                                          ? displayName
                                              .split(' ')
                                              .take(2)
                                              .map((e) => e[0].toUpperCase())
                                              .join()
                                          : 'L',
                                      style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                            child: IconButton(
                              onPressed: _isUploadingProfilePhoto
                                  ? null
                                  : () => _uploadProfilePhoto(user),
                              icon: _isUploadingProfilePhoto
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.email ?? 'No email',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Profile information
                Text(
                  'Profile Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildTextFieldWithError(
                  'Display Name',
                  _nameController,
                  'Enter your name',
                  false,
                  readonly: false,
                ),
                const SizedBox(height: 16),
                _buildTextFieldWithError(
                  'Age',
                  _ageController,
                  'Enter your age',
                  false,
                  keyboardType: TextInputType.number,
                  readonly: false,
                ),
                const SizedBox(height: 16),
                _buildTextFieldWithError(
                  'Bio',
                  _bioController,
                  'Tell us about yourself',
                  false,
                  maxLines: 3,
                  readonly: false,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _updateProfile(user.uid),
                  icon: const Icon(Icons.save),
                  label: const Text('Save Profile'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),

                // Security
                Text(
                  'Security',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildTextFieldWithError(
                  'Current Password',
                  _currentPasswordController,
                  'Enter current password',
                  true,
                  readonly: false,
                ),
                const SizedBox(height: 16),
                _buildTextFieldWithError(
                  'New Password',
                  _newPasswordController,
                  'Enter new password',
                  true,
                  readonly: false,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _updatePassword(user),
                  icon: const Icon(Icons.lock),
                  label: const Text('Change Password'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),

                // Logout
                ElevatedButton.icon(
                  onPressed: () => _showLogoutDialog(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextFieldWithError(
    String label,
    TextEditingController controller,
    String hint,
    bool isPassword, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readonly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          readOnly: false,
          maxLines: maxLines,
          minLines: maxLines == 1 ? 1 : maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _uploadProfilePhoto(User user) async {
    if (_isUploadingProfilePhoto) return;
    setState(() => _isUploadingProfilePhoto = true);
    try {
      final picker = ImagePicker();
      final picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;

      final photoUrl = await CloudinaryProfileService.uploadProfileImage(
          picked.path, user.uid);
      if (photoUrl.isEmpty) {
        throw Exception('Cloudinary did not return a public URL.');
      }

      await user.updatePhotoURL(photoUrl);
      await user.reload();
      await _firestoreService.updateUserProfile(user.uid, photoUrl: photoUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo uploaded to Cloudinary successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        final message = error.code == 'already_active'
            ? 'The photo picker is already open. Close it before trying again.'
            : 'Could not open the photo picker. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload is not configured yet: ${e.message}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo upload failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingProfilePhoto = false);
    }
  }

  Future<void> _updateProfile(String userId) async {
    try {
      final age = int.tryParse(_ageController.text);

      await _firestoreService.updateUserProfile(
        userId,
        displayName: _nameController.text,
        age: age,
        bio: _bioController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updatePassword(User user) async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Re-authenticate with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
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
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              navigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
