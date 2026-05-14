import '../../../downloader/data/models/download_metadata_model.dart';
import '../../domain/entities/download_history_item.dart';

class DownloadHistoryItemModel extends DownloadHistoryItem {
  const DownloadHistoryItemModel({
    required super.id,
    required super.metadata,
    required super.filePath,
    required super.downloadDate,
  });

  factory DownloadHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return DownloadHistoryItemModel(
      id: json['id'],
      metadata: DownloadMetadataModel.fromJson(json['metadata']),
      filePath: json['filePath'],
      downloadDate: DateTime.parse(json['downloadDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'metadata': DownloadMetadataModel.fromEntity(metadata).toJson(),
      'filePath': filePath,
      'downloadDate': downloadDate.toIso8601String(),
    };
  }

  factory DownloadHistoryItemModel.fromEntity(DownloadHistoryItem entity) {
    return DownloadHistoryItemModel(
      id: entity.id,
      metadata: entity.metadata,
      filePath: entity.filePath,
      downloadDate: entity.downloadDate,
    );
  }
}
