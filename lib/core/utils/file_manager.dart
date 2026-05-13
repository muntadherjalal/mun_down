import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Metadata for a single downloaded file.
class DownloadedFileInfo {
  /// Absolute path to the file.
  final String path;

  /// File name including extension.
  final String name;

  /// Lowercase extension without dot (e.g. "mp4", "mp3").
  final String extension;

  /// Size in bytes.
  final int sizeBytes;

  /// Last-modified timestamp (used as "download date").
  final DateTime modified;

  const DownloadedFileInfo({
    required this.path,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.modified,
  });

  // ── File-type helpers ──────────────────────────────────────

  bool get isVideo =>
      const ['mp4', 'mkv', 'webm', 'avi', 'mov', 'flv', 'm4v']
          .contains(extension);

  bool get isAudio =>
      const ['mp3', 'aac', 'ogg', 'wav', 'flac', 'wma', 'm4a', 'opus']
          .contains(extension);

  // ── Formatted size ─────────────────────────────────────────

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Formatted date ─────────────────────────────────────────

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(modified);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${modified.day}/${modified.month}/${modified.year}';
  }
}

/// Utility that scans the MunDown downloads directory.
class FileManager {
  FileManager._();

  /// Default download directory inside app documents.
  static const _folderName = 'MunDown';

  /// Returns the absolute path to the downloads directory.
  static Future<String> get downloadsPath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_folderName';
  }

  /// Scans the downloads directory and returns [DownloadedFileInfo]
  /// objects sorted by modification date (newest first).
  static Future<List<DownloadedFileInfo>> scanFiles() async {
    final path = await downloadsPath;
    final dir = Directory(path);

    if (!dir.existsSync()) return [];

    final entities = dir
        .listSync()
        .whereType<File>()
        .toList();

    final files = <DownloadedFileInfo>[];

    for (final file in entities) {
      final stat = file.statSync();
      final name = file.path.split(Platform.pathSeparator).last;
      final dot = name.lastIndexOf('.');
      final ext = dot != -1 ? name.substring(dot + 1).toLowerCase() : '';

      files.add(DownloadedFileInfo(
        path: file.path,
        name: name,
        extension: ext,
        sizeBytes: stat.size,
        modified: stat.modified,
      ));
    }

    // Newest first.
    files.sort((a, b) => b.modified.compareTo(a.modified));

    return files;
  }

  /// Deletes the file at [path]. Returns `true` on success.
  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
