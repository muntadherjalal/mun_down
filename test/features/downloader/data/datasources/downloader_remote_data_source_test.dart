import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:mun_down/core/errors/exceptions.dart';
import 'package:mun_down/features/downloader/data/datasources/downloader_remote_data_source.dart';
import 'package:mun_down/features/downloader/data/models/download_model.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late DownloaderRemoteDataSourceImpl dataSource;

  setUp(() {
    mockDio = MockDio();
    dataSource = DownloaderRemoteDataSourceImpl(dio: mockDio);
  });

  group('DownloaderRemoteDataSourceImpl', () {
    group('downloadFile', () {
      test('sets correct Cobalt API headers', () async {
        // Arrange
        Options? capturedOptions;

        when(() => mockDio.post(
          any(), // path
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: captureAny(),
          cancelToken: any(named: 'cancelToken'),
          onSendProgress: any(named: 'onSendProgress'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        )).thenAnswer((invocation) async {
          capturedOptions = invocation.positionalArguments[3] as Options?;
          return Future.value(
            Response<Map<String, dynamic>>(
              data: {'status': 'redirect', 'url': 'http://direct-link.com'},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ),
          );
        });

        when(() => mockDio.download(
          any(), // urlPath
          any(), // savePath
          onReceiveProgress: any(named: 'onReceiveProgress'),
          cancelToken: any(named: 'cancelToken'),
          deleteOnError: any(named: 'deleteOnError'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Future.value(
          Response<void>(
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ),
        ));

        // Act
        final stream = dataSource.downloadFile('http://example.com/video');
        await stream.drain();

        // Assert
        verify(() => mockDio.post(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: captureAny(),
          cancelToken: any(named: 'cancelToken'),
          onSendProgress: any(named: 'onSendProgress'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        )).called(1);

        expect(capturedOptions, isNotNull);
        final headers = capturedOptions!.headers;
        expect(headers['Accept'], 'application/json');
        expect(headers['Content-Type'], 'application/json');
        expect(headers['User-Agent'], 'MunDownApp/1.5.0 (Android/iOS)');
      });

      test('returns direct URL for redirect status', () async {
        // Arrange
        when(() => mockDio.post(
          any(),
          data: any(named: 'data'),
        )).thenAnswer((_) async => Future.value(
          Response<Map<String, dynamic>>(
            data: {'status': 'redirect', 'url': 'http://direct-link.com'},
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ),
        ));

        String? downloadedUrl;
        when(() => mockDio.download(
          captureAny(), // urlPath
          any(), // savePath
          onReceiveProgress: any(),
          cancelToken: any(),
          deleteOnError: any(),
          options: any(),
        )).thenAnswer((invocation) async {
          downloadedUrl = invocation.positionalArguments[0] as String?;
          return Future.value(
            Response<void>(
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ),
          );
        });

        // Act
        final stream = dataSource.downloadFile('http://example.com/video');
        final events = <DownloadModel>[];
        stream.listen((event) => events.add(event));
        await stream.drain();

        // Assert
        expect(downloadedUrl, 'http://direct-link.com');
      });

      test('throws ServerException for Cobalt error status', () async {
        // Arrange
        when(() => mockDio.post(
          any(),
          data: any(named: 'data'),
        )).thenAnswer((_) async => Future.value(
          Response<Map<String, dynamic>>(
            data: {'status': 'error', 'text': 'Some error'},
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ),
        ));

        // Act
        final stream = dataSource.downloadFile('http://example.com/video');
        final events = <Object>[];
        stream.listen((event) => events.add(event),
            onError: (error, stackTrace) => events.add(error));
        await stream.drain();

        // Assert
        expect(events.last, isA<ServerException>());
        expect((events.last as ServerException).message, 'Some error');
      });

      test('throws ServerException for HTTP 429 rate limit', () async {
        // Arrange
        when(() => mockDio.post(
          any(),
          data: any(named: 'data'),
        )).thenAnswer((_) async => Future.value(
          Response<Map<String, dynamic>>(
            data: {'status': 'rate-limit'},
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ),
        ));

        // Act
        final stream = dataSource.downloadFile('http://example.com/video');
        final events = <Object>[];
        stream.listen((event) => events.add(event),
            onError: (error, stackTrace) => events.add(error));
        await stream.drain();

        // Assert
        expect(events.last, isA<ServerException>());
        expect((events.last as ServerException).message,
            contains('Cobalt API rate limit exceeded'));
      });
    });
  });
}