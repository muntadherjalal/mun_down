import '../entities/download_entity.dart';

/// Contract that the data layer must fulfil for downloading operations.
///
/// The returned [Stream] emits [DownloadEntity] snapshots as the download
/// progresses, allowing the presentation layer to react to every phase
/// (fetching → downloading → completed / failed).
abstract class DownloaderRepository {
  /// Begins downloading the resource at [url].
  ///
  /// The stream emits an entity for every meaningful state change
  /// (metadata resolved, progress tick, completion, or failure).
  /// Consumers should listen until the stream closes.
  Stream<DownloadEntity> startDownload(String url);
}
