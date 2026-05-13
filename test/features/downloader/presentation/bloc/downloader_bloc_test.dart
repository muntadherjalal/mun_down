import 'package:bloc_test/bloc_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mun_down/core/network/network_info.dart';
import 'package:mun_down/features/downloader/domain/entities/download_entity.dart';
import 'package:mun_down/features/downloader/domain/repositories/downloader_repository.dart';
import 'package:mun_down/features/downloader/presentation/bloc/downloader_bloc.dart';

// ── Mocks ──────────────────────────────────────────────────────

class MockDownloaderRepository extends Mock implements DownloaderRepository {}
class MockNetworkInfo extends Mock implements NetworkInfo {}

// ── Helpers ────────────────────────────────────────────────────

DownloadEntity _entity({
  DownloadStatus status = DownloadStatus.downloading,
  double progress = 0,
}) =>
    DownloadEntity(
      id: 'test-id',
      originalUrl: 'https://example.com/video.mp4',
      title: 'video.mp4',
      progress: progress,
      savePath: '/tmp/video.mp4',
      status: status,
    );

void main() {
  late MockDownloaderRepository repository;
  late MockNetworkInfo networkInfo;

  setUp(() {
    repository  = MockDownloaderRepository();
    networkInfo = MockNetworkInfo();

    // Default: connected, no connectivity changes
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    when(() => networkInfo.onConnectivityChanged)
        .thenAnswer((_) => const Stream.empty());
  });

  // ── Factory ────────────────────────────────────────────────

  DownloaderBloc build() => DownloaderBloc(
        repository: repository,
        networkInfo: networkInfo,
      );

  group('DownloaderBloc', () {
    // ── Initial state ────────────────────────────────────────

    test('initial state is DownloaderInitialState', () {
      expect(build().state, const DownloaderInitialState());
    });

    // ── StartDownloadEvent — no connection ───────────────────

    blocTest<DownloaderBloc, DownloaderState>(
      'emits DownloaderFailedState when there is no internet',
      setUp: () =>
          when(() => networkInfo.isConnected).thenAnswer((_) async => false),
      build: build,
      act: (bloc) => bloc.add(
          const StartDownloadEvent(url: 'https://example.com/video.mp4')),
      expect: () => [
        const DownloaderFailedState(message: 'No internet connection'),
      ],
    );

    // ── StartDownloadEvent — happy path ──────────────────────

    blocTest<DownloaderBloc, DownloaderState>(
      'emits fetching → progress → completed on successful download',
      setUp: () {
        when(() => repository.startDownload(
              any(),
              title: any(named: 'title'),
              cancelToken: any(named: 'cancelToken'),
            )).thenAnswer((_) => Stream.fromIterable([
              _entity(status: DownloadStatus.fetching),
              _entity(status: DownloadStatus.downloading, progress: 0.5),
              _entity(status: DownloadStatus.completed, progress: 1.0),
            ]));
      },
      build: build,
      act: (bloc) => bloc.add(
          const StartDownloadEvent(url: 'https://example.com/video.mp4')),
      expect: () => [
        isA<DownloaderFetchingState>(),
        isA<DownloaderProgressState>(),
        isA<DownloaderCompletedState>(),
      ],
    );

    // ── StartDownloadEvent — forwards title ──────────────────

    blocTest<DownloaderBloc, DownloaderState>(
      'forwards the title parameter to the repository',
      setUp: () {
        when(() => repository.startDownload(
              any(),
              title: any(named: 'title'),
              cancelToken: any(named: 'cancelToken'),
            )).thenAnswer((_) => Stream.fromIterable([
              _entity(status: DownloadStatus.completed, progress: 1.0),
            ]));
      },
      build: build,
      act: (bloc) => bloc.add(const StartDownloadEvent(
        url: 'https://youtu.be/xyz',
        title: 'My Awesome Video',
      )),
      verify: (_) {
        verify(() => repository.startDownload(
              'https://youtu.be/xyz',
              title: 'My Awesome Video',
              cancelToken: any(named: 'cancelToken'),
            )).called(1);
      },
    );

    // ── CancelDownloadEvent ──────────────────────────────────

    blocTest<DownloaderBloc, DownloaderState>(
      'emits DownloaderCancelledState on CancelDownloadEvent',
      build: build,
      act: (bloc) => bloc.add(const CancelDownloadEvent()),
      expect: () => [const DownloaderCancelledState()],
    );

    // ── ResetDownloaderEvent ─────────────────────────────────

    blocTest<DownloaderBloc, DownloaderState>(
      'emits DownloaderInitialState on ResetDownloaderEvent',
      build: build,
      act: (bloc) => bloc.add(const ResetDownloaderEvent()),
      expect: () => [const DownloaderInitialState()],
    );

    // ── NetworkDroppedEvent ──────────────────────────────────

    blocTest<DownloaderBloc, DownloaderState>(
      'emits DownloaderFailedState when network drops mid-download',
      setUp: () {
        // Simulate a download that never completes
        when(() => repository.startDownload(
              any(),
              title: any(named: 'title'),
              cancelToken: any(named: 'cancelToken'),
            )).thenAnswer((_) => Stream.fromIterable([
              _entity(status: DownloadStatus.downloading, progress: 0.3),
            ]));
      },
      build: build,
      act: (bloc) async {
        bloc.add(
            const StartDownloadEvent(url: 'https://example.com/video.mp4'));
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const NetworkDroppedEvent());
      },
      expect: () => [
        isA<DownloaderProgressState>(),
        isA<DownloaderFailedState>(),
      ],
    );
  });
}
