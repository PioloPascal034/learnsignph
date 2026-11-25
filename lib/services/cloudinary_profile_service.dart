import 'dart:convert';

import 'package:http/http.dart' as http;

class CloudinaryProfileService {
  static const String _cloudName = 'jjplj4ct';
  static const String _uploadPreset = 'learnsignph-user-profiles';
  static const String _profileFolder = 'learnsignph-user-profiles';

  static bool get isConfigured =>
      _cloudName != 'your_cloud_name' && _uploadPreset != 'your_upload_preset';

  static Future<String> uploadProfileImage(String localPath, String userId) async {
    if (!isConfigured) {
      throw StateError(
        'Set Cloudinary cloud name and upload preset in lib/services/cloudinary_profile_service.dart before using profile uploads.',
      );
    }

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = _uploadPreset;
    request.fields['folder'] = _profileFolder;
    request.fields['public_id'] = 'user_$userId';
    request.files.add(await http.MultipartFile.fromPath('file', localPath));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cloudinary profile upload failed: $body');
    }

    final payload = jsonDecode(body) as Map<String, dynamic>;
    return (payload['secure_url'] as String?) ??
        (payload['url'] as String?) ??
        '';
  }
}
