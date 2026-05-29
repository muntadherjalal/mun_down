import 'package:equatable/equatable.dart';

/// Metadata for YouTube-specific download information.
class YouTubeMetadata extends Equatable {
  final String? videoId;
  final int? itag;
  final int? audioItag;
  final String? audioFormat;

  const YouTubeMetadata({
    this.videoId,
    this.itag,
    this.audioItag,
    this.audioFormat,
  });

  @override
  List<Object?> get props => [videoId, itag, audioItag, audioFormat];

  /// Returns true if this YouTube metadata indicates muxing is required.
  bool get needsMux => videoId != null && itag != null && audioItag != null;
}

/// Metadata for general file information.
class FileMetadata extends Equatable {
  final String title;
  final String? thumbnailUrl;
  final String? author;
  final Duration? duration;
  final String sourceUrl;
  final DateTime downloadedAt;
  final int fileSizeBytes;
  final String format;
  final String quality;

  const FileMetadata({
    required this.title,
    this.thumbnailUrl,
    required this.author,
    this.duration,
    required this.sourceUrl,
    required this.downloadedAt,
    required this.fileSizeBytes,
    required this.format,
    required this.quality,
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
  ];
}

/// Combined metadata for a download, containing both file and YouTube information.
class DownloadMetadata extends Equatable {
  final FileMetadata fileMetadata;
  final YouTubeMetadata? youtubeMetadata;

  const DownloadMetadata({
    required this.fileMetadata,
    this.youtubeMetadata,
  });

  // Delegate file metadata properties for backward compatibility
  String get title => fileMetadata.title;
  String? get thumbnailUrl => fileMetadata.thumbnailUrl;
  String? get author => fileMetadata.author;
  Duration? get duration => fileMetadata.duration;
  String get sourceUrl => fileMetadata.sourceUrl;
  DateTime get downloadedAt => fileMetadata.downloadedAt;
  int get fileSizeBytes => fileMetadata.fileSizeBytes;
  String get format => fileMetadata.format;
  String get quality => fileMetadata.quality;

  // YouTube-specific properties
  bool get needsMux => youtubeMetadata?.needsMux ?? false;
  String? get videoId => youtubeMetadata?.videoId;
  int? get itag => youtubeMetadata?.itag;
  String? get audioUrl => null; // Will be set during download process
  String? get audioFormat => youtubeMetadata?.audioFormat;
  int? get audioItag => youtubeMetadata?.audioItag;

  @override
  List<Object?> get props => [
    fileMetadata,
    youtubeMetadata,
  ];

  /// Creates a copy of this DownloadMetadata with the given fields replaced.
  DownloadMetadata copyWith({
    FileMetadata? fileMetadata,
    YouTubeMetadata? youtubeMetadata,
  }) {
    return DownloadMetadata(
      fileMetadata: fileMetadata ?? this.fileMetadata,
      youtubeMetadata: youtubeMetadata ?? this.youtubeMetadata,
    );
  }

  /// Creates a DownloadMetadata from a JSON map.
  factory DownloadMetadata.fromJson(Map<String, dynamic> json) {
    return DownloadMetadata(
      fileMetadata: FileMetadata(
        title: json['title'],
        thumbnailUrl: json['thumbnailUrl'],
        author: json['author'],
        duration: json['duration'] != null
            ? Duration(seconds: json['duration'])
            : null,
        sourceUrl: json['sourceUrl'],
        downloadedAt: DateTime.parse(json['downloadedAt']),
        fileSizeBytes: json['fileSizeBytes'],
        format: json['format'],
        quality: json['quality'],
      ),
      youtubeMetadata: YouTubeMetadata(
        videoId: json['videoId'] as String?,
        itag: json['itag'] as int?,
        audioItag: json['audioItag'] as int?,
        audioFormat: json['audioFormat'] as String?,
      ),
    );
  }

  /// Factory method to create DownloadMetadata from the old format for migration.
  factory DownloadMetadata.fromLegacy({
    required String title,
    String? thumbnailUrl,
    required String author,
    Duration? duration,
    required String sourceUrl,
    required DateTime downloadedAt,
    required int fileSizeBytes,
    required String format,
    required String quality,
    bool needsMux = false,
    String? audioUrl,
    String? audioFormat,
    String? videoId,
    int? itag,
    int? audioItag,
  }) {
    return DownloadMetadata(
      fileMetadata: FileMetadata(
        title: title,
        thumbnailUrl: thumbnailUrl,
        author: author,
        duration: duration,
        sourceUrl: sourceUrl,
        downloadedAt: downloadedAt,
        fileSizeBytes: fileSizeBytes,
        format: format,
        quality: quality,
      ),
      youtubeMetadata: YouTubeMetadata(
        videoId: videoId,
        itag: itag,
        audioItag: audioItag,
        audioFormat: audioFormat,
      ),
    );
  }
}