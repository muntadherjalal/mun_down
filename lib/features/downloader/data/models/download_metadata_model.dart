import '../../domain/entities/download_entity.dart';

class DownloadMetadataModel extends DownloadMetadata {
  const DownloadMetadataModel({
    required super.title,
    super.thumbnailUrl,
    required super.author,
    super.duration,
    required super.sourceUrl,
    required super.downloadedAt,
    required super.fileSizeBytes,
    required super.format,
    required super.quality,
  });

  factory DownloadMetadataModel.fromJson(Map<String, dynamic> json) =>
      DownloadMetadataModel(
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
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'author': author,
        'duration': duration?.inSeconds,
        'sourceUrl': sourceUrl,
        'downloadedAt': downloadedAt.toIso8601String(),
        'fileSizeBytes': fileSizeBytes,
        'format': format,
        'quality': quality,
      };

  factory DownloadMetadataModel.fromEntity(DownloadMetadata entity) {
    return DownloadMetadataModel(
      title: entity.title,
      thumbnailUrl: entity.thumbnailUrl,
      author: entity.author,
      duration: entity.duration,
      sourceUrl: entity.sourceUrl,
      downloadedAt: entity.downloadedAt,
      fileSizeBytes: entity.fileSizeBytes,
      format: entity.format,
      quality: entity.quality,
    );
  }
}
