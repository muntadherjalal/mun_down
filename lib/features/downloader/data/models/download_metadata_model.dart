import '../../domain/entities/download_metadata.dart';

class DownloadMetadataModel extends DownloadMetadata {
  const DownloadMetadataModel({
    required FileMetadata fileMetadata,
    YouTubeMetadata? youtubeMetadata,
  }) : super(
          fileMetadata: fileMetadata,
          youtubeMetadata: youtubeMetadata,
        );

  factory DownloadMetadataModel.fromJson(Map<String, dynamic> json) =>
      DownloadMetadataModel(
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

  Map<String, dynamic> toJson() => {
        'title': fileMetadata.title,
        'thumbnailUrl': fileMetadata.thumbnailUrl,
        'author': fileMetadata.author,
        'duration': fileMetadata.duration?.inSeconds,
        'sourceUrl': fileMetadata.sourceUrl,
        'downloadedAt': fileMetadata.downloadedAt.toIso8601String(),
        'fileSizeBytes': fileMetadata.fileSizeBytes,
        'format': fileMetadata.format,
        'quality': fileMetadata.quality,
        'videoId': youtubeMetadata?.videoId,
        'itag': youtubeMetadata?.itag,
        'audioItag': youtubeMetadata?.audioItag,
        'audioFormat': youtubeMetadata?.audioFormat,
      };

  factory DownloadMetadataModel.fromEntity(DownloadMetadata entity) {
    return DownloadMetadataModel(
      fileMetadata: entity.fileMetadata,
      youtubeMetadata: entity.youtubeMetadata,
    );
  }
}
