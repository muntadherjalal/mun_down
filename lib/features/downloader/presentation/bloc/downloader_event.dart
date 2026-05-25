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

  /// Extracted metadata from the UI
  final DownloadMetadata? metadata;

  /// The path of the partially downloaded file (used for Resume)
  final String? existingSavePath;

  const StartDownloadEvent({
    required this.url,
    this.metadata,
    this.existingSavePath,
  });

  @override
  List<Object?> get props => [url, metadata, existingSavePath];
}

/// Fired to reset the BLoC back to its initial state
/// (e.g. after a completed or failed download).
final class ResetDownloaderEvent extends DownloaderEvent {
  const ResetDownloaderEvent();
}

/// Fired when network connectivity is lost.
final class NetworkDroppedEvent extends DownloaderEvent {
  const NetworkDroppedEvent();
}

/// Fired when the user taps the Pause button on an active download.
final class PauseDownloadEvent extends DownloaderEvent {
  const PauseDownloadEvent();
}

/// Fired when the user taps Resume on a paused download.
final class ResumeDownloadEvent extends DownloaderEvent {
  const ResumeDownloadEvent();
}

/// Fired to initialize the BLoC from saved downloads.
final class InitializeFromSavedDownloadsEvent extends DownloaderEvent {
  const InitializeFromSavedDownloadsEvent();
}
