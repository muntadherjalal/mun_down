import 'dart:convert';

import '../../../../features/downloader/domain/entities/download_entity.dart';
import '../../../../features/downloader/domain/entities/download_metadata.dart';
import '../models/download_metadata_model.dart';

/// A persistable representation of an active download, suitable for storage in SharedPreferences.
class PersistentDownload {
  final String id;
  final String originalUrl;
  final String title;
  final double progress;
  final String savePath;
  final DownloadStatus status;
  final bool isPrivate;
  final int totalBytes;
  final int receivedBytes;
  final String? thumbnailUrl;
  final DownloadMetadataModel metadataModel;

  const PersistentDownload({
    required this.id,
    required this.originalUrl,
    required this.title,
    required this.progress,
    required this.savePath,
    required this.status,
    required this.isPrivate,
    required this.totalBytes,
    required this.receivedBytes,
    required this.thumbnailUrl,
    required this.metadataModel,
  });

  /// Creates a [PersistentDownload] from a [DownloadEntity] and its associated [DownloadMetadata].
  factory PersistentDownload.fromEntityAndMetadata(
    DownloadEntity entity,
    DownloadMetadata metadata,
  ) {
    return PersistentDownload(
      id: entity.id,
      originalUrl: entity.originalUrl,
      title: entity.title,
      progress: entity.progress,
      savePath: entity.savePath,
      status: entity.status,
      isPrivate: entity.isPrivate,
      totalBytes: entity.totalBytes,
      receivedBytes: entity.receivedBytes,
      thumbnailUrl: entity.thumbnailUrl,
      metadataModel: DownloadMetadataModel.fromEntity(metadata),
    );
  }

  /// Converts this [PersistentDownload] back to a [DownloadEntity].
  DownloadEntity toEntity() {
    return DownloadEntity(
      id: id,
      originalUrl: originalUrl,
      title: title,
      progress: progress,
      savePath: savePath,
      status: status,
      isPrivate: isPrivate,
      totalBytes: totalBytes,
      receivedBytes: receivedBytes,
      thumbnailUrl: thumbnailUrl,
    );
  }

  /// Returns the domain [DownloadMetadata] associated with this persistent download.
  DownloadMetadata get metadata => metadataModel;

  /// Converts this [PersistentDownload] to a JSON string for storage.
  String toJson() {
    return jsonEncode({
      'id': id,
      'originalUrl': originalUrl,
      'title': title,
      'progress': progress,
      'savePath': savePath,
      'status': status.index,
      'isPrivate': isPrivate,
      'totalBytes': totalBytes,
      'receivedBytes': receivedBytes,
      'thumbnailUrl': thumbnailUrl,
      'metadataModel': metadataModel.toJson(),
    });
  }

  /// Creates a [PersistentDownload] from a JSON string.
  factory PersistentDownload.fromJson(String source) {
    final Map<String, dynamic> data = jsonDecode(source);
    return PersistentDownload(
      id: data['id'],
      originalUrl: data['originalUrl'],
      title: data['title'],
      progress: data['progress'] as double,
      savePath: data['savePath'],
      status: DownloadStatus.values[data['status'] as int],
      isPrivate: data['isPrivate'] as bool,
      totalBytes: data['totalBytes'] as int,
      receivedBytes: data['receivedBytes'] as int,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      metadataModel: DownloadMetadataModel.fromJson(data['metadataModel']),
    );
  }
}