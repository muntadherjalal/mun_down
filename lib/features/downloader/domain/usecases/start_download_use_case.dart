import 'package:equatable/equatable.dart';

import '../entities/download_entity.dart';
import '../entities/download_metadata.dart';
import '../repositories/downloader_repository.dart';

/// Parameters for the [StartDownloadUseCase].
class StartDownloadParams extends Equatable {
  final String url;
  final DownloadMetadata? metadata;
  final String? existingSavePath;

  const StartDownloadParams({
    required this.url,
    this.metadata,
    this.existingSavePath,
  });

  @override
  List<Object?> get props => [url, metadata, existingSavePath];
}

/// Use case for starting a download.
class StartDownloadUseCase {
  final DownloaderRepository _repository;

  StartDownloadUseCase(this._repository);

  /// Executes the use case and returns a stream of [DownloadEntity] snapshots.
  Stream<DownloadEntity> call(StartDownloadParams params) =>
      _repository.startDownload(
        params.url,
        metadata: params.metadata,
        existingSavePath: params.existingSavePath,
      );
}