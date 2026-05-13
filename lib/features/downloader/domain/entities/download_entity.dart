import 'package:equatable/equatable.dart';

/// Represents the lifecycle state of a single download.
enum DownloadStatus {
  /// No download has been initiated yet.
  initial,

  /// Resolving the URL / fetching file metadata.
  fetching,

  /// Actively downloading bytes to disk.
  downloading,

  /// Download completed successfully.
  completed,

  /// An error occurred during the download.
  failed,
}

/// Pure domain entity that tracks a single download's metadata and progress.
///
/// This class has **no dependency** on any framework or data-layer detail.
/// The data layer provides a [DownloadModel] that extends this entity.
class DownloadEntity extends Equatable {
  /// Unique identifier for this download session.
  final String id;

  /// The original URL provided by the user.
  final String originalUrl;

  /// Human-readable title extracted from the response or derived from the URL.
  final String title;

  /// Current progress as a value between 0.0 and 1.0.
  final double progress;

  /// Absolute file path where the download is being saved.
  final String savePath;

  /// Current lifecycle state.
  final DownloadStatus status;

  const DownloadEntity({
    required this.id,
    required this.originalUrl,
    required this.title,
    required this.progress,
    required this.savePath,
    required this.status,
  });

  @override
  List<Object?> get props => [
        id,
        originalUrl,
        title,
        progress,
        savePath,
        status,
      ];
}
