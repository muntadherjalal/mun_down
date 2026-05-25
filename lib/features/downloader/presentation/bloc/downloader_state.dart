part of 'downloader_bloc.dart';

/// Base class for all states emitted by [DownloaderBloc].
sealed class DownloaderState extends Equatable {
  const DownloaderState();

  @override
  List<Object?> get props => [];
}

/// No download is in progress.
final class DownloaderInitialState extends DownloaderState {
  const DownloaderInitialState();
}

/// Resolving the URL / fetching remote file metadata.
final class DownloaderFetchingState extends DownloaderState {
  final DownloadEntity entity;

  const DownloaderFetchingState({required this.entity});

  @override
  List<Object?> get props => [entity];
}

/// Actively downloading — carries the latest progress snapshot.
///
/// Rebuilds are driven by [entity.progress] which changes on every
/// `onReceiveProgress` tick from Dio.
final class DownloaderProgressState extends DownloaderState {
  final DownloadEntity entity;

  const DownloaderProgressState({required this.entity});

  @override
  List<Object?> get props => [entity.progress, entity.id, entity.receivedBytes];
}

/// Download is paused by the user.
final class DownloaderPausedState extends DownloaderState {
  final DownloadEntity entity;

  const DownloaderPausedState({required this.entity});

  @override
  List<Object?> get props => [entity];
}

/// Download finished successfully.
final class DownloaderCompletedState extends DownloaderState {
  final DownloadEntity entity;

  const DownloaderCompletedState({required this.entity});

  @override
  List<Object?> get props => [entity];
}

/// Download failed.
final class DownloaderFailedState extends DownloaderState {
  final Failure failure;

  const DownloaderFailedState({required this.failure});

  @override
  List<Object?> get props => [failure];
}
