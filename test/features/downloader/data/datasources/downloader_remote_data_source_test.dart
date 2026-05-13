import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';

import 'package:mun_down/features/downloader/data/datasources/downloader_remote_data_source.dart';
import 'package:mun_down/features/downloader/domain/entities/download_entity.dart';
import 'package:mun_down/features/downloader/data/models/download_model.dart';

class MockDio extends Mock implements Dio {}
class MockHeaders extends Mock implements Headers {}

void main() {
  late MockDio mockDio;
  late DownloaderRemoteDataSourceImpl dataSource;

  setUp(() {
    mockDio = MockDio();
    dataSource = DownloaderRemoteDataSourceImpl(dio: mockDio);
  });

  group('DownloaderRemoteDataSourceImpl', () {
    const testUrl = 'https://example.com/video.mp4';

    // ── File name resolution ─────────────────────────────────

    group('downloadFile', () {
      test('emits fetching → downloading → completed on success', () async {
        // Mock HEAD request (no content-disposition)
        when(() => mockDio.head(testUrl)).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: testUrl),
            headers: Headers.fromMap({}),
          ),
        );

        // Mock actual download
        when(() => mockDio.download(
              testUrl,
              any(),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((invocation) async {
          // Simulate progress callback
          final onProgress = invocation.namedArguments[
              const Symbol('onReceiveProgress')] as ProgressCallback?;
          onProgress?.call(500, 1000);
          onProgress?.call(1000, 1000);
          return Response(requestOptions: RequestOptions(path: testUrl));
        });

        final statuses = <DownloadStatus>[];

        await for (final model in dataSource.downloadFile(testUrl)) {
          statuses.add(model.status);
        }

        expect(statuses, [
          DownloadStatus.fetching,
          DownloadStatus.downloading,
          DownloadStatus.downloading, // 50%
          DownloadStatus.downloading, // 100%
          DownloadStatus.completed,
        ]);
      });

      test('uses preResolvedTitle and skips HEAD request when title provided',
          () async {
        when(() => mockDio.download(
              testUrl,
              any(),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async =>
            Response(requestOptions: RequestOptions(path: testUrl)));

        final models = <DownloadModel>[];
        await for (final m
            in dataSource.downloadFile(testUrl, title: 'My Video')) {
          models.add(m as DownloadModel);
        }

        // HEAD should never be called
        verifyNever(() => mockDio.head(any()));

        // The title should appear in downloading/completed models
        final withTitle =
            models.where((m) => m.title == 'My Video').toList();
        expect(withTitle, isNotEmpty);
      });

      test('emits error event on DioException', () async {
        when(() => mockDio.head(testUrl)).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: testUrl),
            message: 'Connection refused',
          ),
        );

        when(() => mockDio.download(
              testUrl,
              any(),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: testUrl),
            type: DioExceptionType.connectionError,
            message: 'Connection refused',
          ),
        );

        final stream = dataSource.downloadFile(testUrl);
        expect(
          () async => stream.toList(),
          throwsA(isA<DioException>()),
        );
      });
    });
  });
}
