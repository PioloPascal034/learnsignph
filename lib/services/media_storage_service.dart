class MediaStorageService {
  const MediaStorageService();

  static String buildStoragePath(String signId, String mediaType, String fileName) {
    return 'signs/$mediaType/$signId/$fileName';
  }

  static String buildContentStoragePath(
    String collection,
    String contentId,
    String mediaType,
    String fileName,
  ) {
    return '$collection/$mediaType/$contentId/$fileName';
  }

  static String contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.m4v')) {
      if (lower.endsWith('.mp4')) return 'video/mp4';
      if (lower.endsWith('.mov')) return 'video/quicktime';
      return 'video/x-m4v';
    }

    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';

    return 'application/octet-stream';
  }

  static String fileExtensionFrom(String fileName) {
    final idx = fileName.lastIndexOf('.');
    if (idx == -1 || idx == fileName.length - 1) return '';
    return fileName.substring(idx + 1).toLowerCase();
  }

  static bool isVideo(String fileName) {
    final ext = fileExtensionFrom(fileName);
    return ext == 'mp4' || ext == 'mov' || ext == 'm4v';
  }

  static bool isGif(String fileName) {
    return fileExtensionFrom(fileName) == 'gif';
  }

  static String safeFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.isEmpty ? 'sign_media' : cleaned;
  }
}
