import 'package:shared_preferences/shared_preferences.dart';

import '../models/persistent_download.dart';

/// Contract for the local data source responsible for persisting download state.
abstract class DownloaderLocalDataSource {
  /// Saves the [download] state to local storage.
  Future<void> saveDownloadState(PersistentDownload download);

  /// Retrieves a list of all saved download states.
  Future<List<PersistentDownload>> getSavedDownloads();

  /// Deletes the saved state for the download with the given [id].
  Future<void> deleteDownloadState(String id);

  /// Clears all saved download states.
  Future<void> clearAllDownloads();
}

/// Implementation of [DownloaderLocalDataSource] that uses SharedPreferences.
class DownloaderLocalDataSourceImpl implements DownloaderLocalDataSource {
  static const String _savedDownloadsKey = 'saved_downloads';

  final SharedPreferences _preferences;

  DownloaderLocalDataSourceImpl(this._preferences);

  @override
  Future<void> saveDownloadState(PersistentDownload download) async {
    final downloads = await getSavedDownloads();
    // Remove any existing entry for this id to avoid duplicates
    downloads.removeWhere((d) => d.id == download.id);
    downloads.add(download);
    await _saveDownloads(downloads);
  }

  @override
  Future<List<PersistentDownload>> getSavedDownloads() async {
    final jsonStrings = _preferences.getStringList(_savedDownloadsKey) ?? [];
    return jsonStrings
        .map((jsonString) => PersistentDownload.fromJson(jsonString))
        .whereType<PersistentDownload>() // Filter out any nulls from failed parsing
        .toList();
  }

  @override
  Future<void> deleteDownloadState(String id) async {
    final downloads = await getSavedDownloads();
    downloads.removeWhere((d) => d.id == id);
    await _saveDownloads(downloads);
  }

  @override
  Future<void> clearAllDownloads() async {
    await _preferences.remove(_savedDownloadsKey);
  }

  Future<void> _saveDownloads(List<PersistentDownload> downloads) async {
    final jsonStrings = downloads.map((download) => download.toJson()).toList();
    await _preferences.setStringList(_savedDownloadsKey, jsonStrings);
  }
}