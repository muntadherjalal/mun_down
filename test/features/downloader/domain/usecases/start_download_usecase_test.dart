import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:mun_down/features/downloader/domain/entities/download_entity.dart';
import 'package:mun_down/features/downloader/domain/entities/download_metadata.dart';
import 'package:mun_down/features/downloader/domain/repositories/downloader_repository.dart';
import 'package:mun_down/features/downloader/domain/usecases/start_download_use_case.dart';

class MockDownloaderRepository extends Mock implements DownloaderRepository {}

void main() {
  late StartDownloadUseCase usecase;
  late MockDownloaderRepository mockRepository;

  setUp(() {
    mockRepository = MockDownloaderRepository();
    usecase = StartDownloadUseCase(mockRepository);
  });

  final testUrl = 'https://example.com/video.mp4';
  final testMetadata = DownloadMetadata(
    fileMetadata: FileMetadata(
      title: 'Test Video',
      author: 'Test Author',
      sourceUrl: testUrl,
      downloadedAt: DateTime(2026, 5, 29),
      fileSizeBytes: 1024,
      format: 'mp4',
      quality: '720p',
    ),
  );

  // Helper to create a test DownloadEntity
  DownloadEntity _createTestEntity() {
    return DownloadEntity(
      id: 'test-id',
      originalUrl: testUrl,
      title: 'Test Video',
      progress: 0.5,
      savePath: '/tmp/test.mp4',
      status: DownloadStatus.downloading,
    );
  }

  group('StartDownloadUseCase', () {
    test('should forward the call to repository', () async {
      // Arrange
      final testEntity = DownloadEntity(
        id: 'test-id',
        originalUrl: testUrl,
        title: 'Test Video',
        progress: 0.5,
        savePath: '/tmp/test.mp4',
        status: DownloadStatus.downloading,
      );
      when(() => mockRepository.startDownload(
            testUrl,
            metadata: testMetadata,
            existingSavePath: any(named: 'existingSavePath'),
          )).thenAnswer((_) => Stream.value(testEntity));

      // Act
      final stream = usecase(StartDownloadParams(
        url: testUrl,
        metadata: testMetadata,
        existingSavePath: '/some/path',
      ));

      // Assert
      expect(stream, isNotNull);
      verify(() => mockRepository.startDownload(
            testUrl,
            metadata: testMetadata,
            existingSavePath: '/some/path',
          )).called(1);

      // Consume the stream to avoid warnings
      await stream.drain();
    });

    test('should forward the call with null metadata', () async {
      // Arrange
      final testEntity = DownloadEntity(
        id: 'test-id',
        originalUrl: testUrl,
        title: 'Test Video',
        progress: 0.5,
        savePath: '/tmp/test.mp4',
        status: DownloadStatus.downloading,
      );
      when(() => mockRepository.startDownload(
            testUrl,
            metadata: any(named: 'metadata'),
            existingSavePath: any(named: 'existingSavePath'),
          )).thenAnswer((_) => Stream.value(testEntity));

      // Act
      final stream = usecase(StartDownloadParams(
        url: testUrl,
        metadata: null,
        existingSavePath: null,
      ));

      // Assert
      expect(stream, isNotNull);
      verify(() => mockRepository.startDownload(
            testUrl,
            metadata: null,
            existingSavePath: null,
          )).called(1);

      // Consume the stream to avoid warnings
      await stream.drain();
    });
  });
}

