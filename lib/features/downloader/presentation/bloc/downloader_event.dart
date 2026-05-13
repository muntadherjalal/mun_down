part of 'downloader_bloc.dart';

/// Base class for all events consumed by [DownloaderBloc].
sealed class DownloaderEvent extends Equatable {
  const DownloaderEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the user submits a URL to begin downloading.
final class StartDownloadEvent extends DownloaderEvent {
  /// The URL to download from.
  final String url;

  const StartDownloadEvent({required this.url});

  @override
  List<Object?> get props => [url];
}

/// Fired to reset the BLoC back to its initial state
/// (e.g. after a completed or failed download).
final class ResetDownloaderEvent extends DownloaderEvent {
  const ResetDownloaderEvent();
}
