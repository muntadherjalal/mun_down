import '../entities/download_entity.dart';
import '../entities/download_metadata.dart';

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
  Stream<DownloadEntity> startDownload(
    String url, {
    dynamic metadata,
    dynamic cancelToken,
    String? existingSavePath,
  });

  /// Saves the current state of a download for persistence.
  Future<void> saveDownloadState(String id, DownloadEntity entity, DownloadMetadata metadata);

  /// Retrieves all saved download states.
  Future<List<DownloadEntity>> getSavedDownloads();

  /// Deletes the saved state for a download.
  Future<void> deleteDownloadState(String id);

  /// Clears all saved download states.
  Future<void> clearAllDownloads();
}
