import 'package:flutter_test/flutter_test.dart';
import 'package:learnsignph/services/media_storage_service.dart';

void main() {
  group('media storage helper', () {
    test('builds a stable sign media path', () {
      expect(
        MediaStorageService.buildStoragePath('sign_hello', 'videos', 'hello.mp4'),
        'signs/videos/sign_hello/hello.mp4',
      );
      expect(
        MediaStorageService.buildStoragePath('sign_help', 'gifs', 'help.gif'),
        'signs/gifs/sign_help/help.gif',
      );
    });

    test('detects content type by file extension', () {
      expect(MediaStorageService.contentTypeFor('hello.mp4'), 'video/mp4');
      expect(MediaStorageService.contentTypeFor('help.gif'), 'image/gif');
      expect(MediaStorageService.contentTypeFor('demo.mov'), 'video/quicktime');
    });
  });
}
