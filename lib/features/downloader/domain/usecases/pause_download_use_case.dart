import '../repositories/downloader_repository.dart';

/// Use case for pausing a download.
class PauseDownloadUseCase {
  final DownloaderRepository _repository;

  PauseDownloadUseCase(this._repository);

  /// Executes the use case.
  Future<void> call(String url) => _repository.pauseDownload(url);
}