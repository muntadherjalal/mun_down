import 'package:equatable/equatable.dart';

/// Represents the lifecycle state of a single download.
enum DownloadStatus {
  /// No download has been initiated yet.
  initial,

  /// Resolving the URL / fetching file metadata.
  fetching,

  /// Actively downloading bytes to disk.
  downloading,

  /// Download is paused by the user.
  paused,

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

  /// Whether this file is locked in the private vault.
  final bool isPrivate;

  /// Total file size in bytes (from Content-Length or stream manifest).
  final int totalBytes;

  /// Bytes received so far.
  final int receivedBytes;

  /// URL of the video/audio thumbnail for UI display.
  final String? thumbnailUrl;

  const DownloadEntity({
    required this.id,
    required this.originalUrl,
    required this.title,
    required this.progress,
    required this.savePath,
    required this.status,
    this.isPrivate = false,
    this.totalBytes = 0,
    this.receivedBytes = 0,
    this.thumbnailUrl,
  });

  @override
  List<Object?> get props => [
    id,
    originalUrl,
    title,
    progress,
    savePath,
    status,
    isPrivate,
    totalBytes,
    receivedBytes,
    thumbnailUrl,
  ];
}

class DownloadMetadata extends Equatable {
  final String title;
  final String? thumbnailUrl;
  final String? author;
  final Duration? duration;
  final String sourceUrl;
  final DateTime downloadedAt;
  final int fileSizeBytes;
  final String format;
  final String quality;

  /// When `true`, the primary [DownloaderRemoteDataSource] URL is video-only
  /// and the [audioUrl] must be downloaded separately and merged via ffmpeg.
  final bool needsMux;

  /// Audio-only URL paired with the video-only URL for muxing.
  final String? audioUrl;

  /// Audio container name (e.g. "mp4", "webm").
  final String? audioFormat;

  /// 11-character YouTube video ID. When non-null (alongside [itag]) the
  /// data source routes the download through `youtube_explode_dart` instead
  /// of Dio — this is what fixes 403 errors on signed googlevideo URLs.
  final String? videoId;

  /// itag of the chosen video/muxed/audio stream inside the YouTube
  /// manifest. Used to look up a fresh `StreamInfo` at download time.
  final int? itag;

  /// itag of the paired audio stream when [needsMux] is true.
  final int? audioItag;

  const DownloadMetadata({
    required this.title,
    this.thumbnailUrl,
    required this.author,
    this.duration,
    required this.sourceUrl,
    required this.downloadedAt,
    required this.fileSizeBytes,
    required this.format,
    required this.quality,
    this.needsMux = false,
    this.audioUrl,
    this.audioFormat,
    this.videoId,
    this.itag,
    this.audioItag,
  });

  @override
  List<Object?> get props => [
        title,
        thumbnailUrl,
        author,
        duration,
        sourceUrl,
        downloadedAt,
        fileSizeBytes,
        format,
        quality,
        needsMux,
        audioUrl,
        audioFormat,
        videoId,
        itag,
        audioItag,
      ];
}
