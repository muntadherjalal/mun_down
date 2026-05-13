import '../../domain/entities/download_entity.dart';

/// Data-layer model that extends the domain [DownloadEntity].
///
/// Provides [copyWith] for immutable updates during the download lifecycle
/// and can be extended with serialization helpers (toJson / fromJson) when
/// persistence is needed.
class DownloadModel extends DownloadEntity {
  const DownloadModel({
    required super.id,
    required super.originalUrl,
    required super.title,
    required super.progress,
    required super.savePath,
    required super.status,
  });

  /// Creates a modified copy of this model.
  DownloadModel copyWith({
    String? id,
    String? originalUrl,
    String? title,
    double? progress,
    String? savePath,
    DownloadStatus? status,
  }) {
    return DownloadModel(
      id: id ?? this.id,
      originalUrl: originalUrl ?? this.originalUrl,
      title: title ?? this.title,
      progress: progress ?? this.progress,
      savePath: savePath ?? this.savePath,
      status: status ?? this.status,
    );
  }
}
