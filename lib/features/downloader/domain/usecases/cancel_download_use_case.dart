import '../repositories/downloader_repository.dart';

/// Use case for cancelling a download.
class CancelDownloadUseCase {
  final DownloaderRepository _repository;

  CancelDownloadUseCase(this._repository);

  /// Executes the use case.
  Future<void> call(String url) => _repository.cancelDownload(url);
}