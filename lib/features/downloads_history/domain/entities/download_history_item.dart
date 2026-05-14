import 'package:equatable/equatable.dart';
import '../../../downloader/domain/entities/download_entity.dart';

class DownloadHistoryItem extends Equatable {
  final String id;
  final DownloadMetadata metadata;
  final String filePath;
  final DateTime downloadDate;

  const DownloadHistoryItem({
    required this.id,
    required this.metadata,
    required this.filePath,
    required this.downloadDate,
  });

  @override
  List<Object?> get props => [id, metadata, filePath, downloadDate];
}
