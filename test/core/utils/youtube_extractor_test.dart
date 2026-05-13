import 'package:flutter_test/flutter_test.dart';

import 'package:mun_down/core/utils/youtube_extractor.dart';

void main() {
  group('YouTubeExtractor.isYouTubeUrl', () {
    test('returns true for standard youtube.com URLs', () {
      expect(
          YouTubeExtractor.isYouTubeUrl(
              'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
          isTrue);
    });

    test('returns true for youtu.be short URLs', () {
      expect(
          YouTubeExtractor.isYouTubeUrl('https://youtu.be/dQw4w9WgXcQ'),
          isTrue);
    });

    test('returns true for youtube-nocookie.com', () {
      expect(
          YouTubeExtractor.isYouTubeUrl(
              'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ'),
          isTrue);
    });

    test('returns false for non-YouTube URLs', () {
      expect(
          YouTubeExtractor.isYouTubeUrl('https://vimeo.com/123456'), isFalse);
      expect(
          YouTubeExtractor.isYouTubeUrl('https://example.com/video.mp4'),
          isFalse);
    });

    test('returns false for invalid/empty URLs', () {
      expect(YouTubeExtractor.isYouTubeUrl(''), isFalse);
      expect(YouTubeExtractor.isYouTubeUrl('not a url'), isFalse);
    });
  });

  group('URL validation helper', () {
    // Mirrors the _isValidUrl logic used in DownloadsPage
    bool isValidUrl(String text) {
      final uri = Uri.tryParse(text.trim());
      return uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    }

    test('accepts valid http URL', () {
      expect(isValidUrl('http://example.com/file.mp4'), isTrue);
    });

    test('accepts valid https URL', () {
      expect(isValidUrl('https://example.com/file.mp4'), isTrue);
    });

    test('rejects plain text', () {
      expect(isValidUrl('just some text'), isFalse);
    });

    test('rejects ftp URLs', () {
      expect(isValidUrl('ftp://example.com/file.mp4'), isFalse);
    });

    test('rejects empty string', () {
      expect(isValidUrl(''), isFalse);
    });

    test('rejects URL with no host', () {
      expect(isValidUrl('https://'), isFalse);
    });
  });
}
