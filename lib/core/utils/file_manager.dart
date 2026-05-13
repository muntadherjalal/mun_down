import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../features/downloader/domain/entities/download_entity.dart';

/// Information combining the file and its metadata.
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

  /// Associated metadata from the JSON sidecar, if any.
  final DownloadMetadata? metadata;

  const DownloadedFileInfo({
    required this.path,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.modified,
    this.metadata,
  });

  // ── File-type helpers ──────────────────────────────────────

  bool get isVideo => const [
    'mp4',
    'mkv',
    'webm',
    'avi',
    'mov',
    'flv',
    'm4v',
  ].contains(extension);

  bool get isAudio => const [
    'mp3',
    'aac',
    'ogg',
    'wav',
    'flac',
    'wma',
    'm4a',
    'opus',
  ].contains(extension);

  // ── Display helpers ────────────────────────────────────────

  String get displayTitle {
    if (metadata != null && metadata!.title.isNotEmpty) {
      return metadata!.title;
    }
    return name;
  }

  String get displayAuthor => metadata?.author ?? 'Unknown Author';

  String? get displayDuration {
    final d = metadata?.duration;
    if (d == null) return null;
    final min = d.inMinutes;
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

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
    final path = '${dir.path}/$_folderName';
    final directory = Directory(path);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return path;
  }

  /// Scans the downloads directory and returns [DownloadedFileInfo]
  /// objects sorted by modification date (newest first).
  static Future<List<DownloadedFileInfo>> scanFiles() async {
    final path = await downloadsPath;
    final dir = Directory(path);

    if (!dir.existsSync()) return [];

    final entities = dir.listSync().whereType<File>().toList();

    final files = <DownloadedFileInfo>[];

    for (final file in entities) {
      final name = file.path.split(Platform.pathSeparator).last;

      if (name.endsWith('.json')) continue;

      final stat = file.statSync();
      final dot = name.lastIndexOf('.');
      final ext = dot != -1 ? name.substring(dot + 1).toLowerCase() : '';

      DownloadMetadata? metadata;
      final jsonFile = File('${file.path}.json');
      if (jsonFile.existsSync()) {
        try {
          final content = jsonFile.readAsStringSync();
          final jsonMap = jsonDecode(content) as Map<String, dynamic>;
          metadata = DownloadMetadata.fromJson(jsonMap);
        } catch (_) {}
      }

      files.add(
        DownloadedFileInfo(
          path: file.path,
          name: name,
          extension: ext,
          sizeBytes: stat.size,
          modified: stat.modified,
          metadata: metadata,
        ),
      );
    }

    files.sort((a, b) => b.modified.compareTo(a.modified));

    return files;
  }

  /// Saves metadata to a sidecar JSON file next to the main file.
  static Future<void> saveMetadata(
    String filePath,
    DownloadMetadata metadata,
  ) async {
    try {
      final file = File('$filePath.json');
      await file.writeAsString(jsonEncode(metadata.toJson()));
    } catch (_) {}
  }

  /// Deletes the file at [path] and its metadata sidecar if present.
  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        final jsonFile = File('$path.json');
        if (await jsonFile.exists()) {
          await jsonFile.delete();
        }
        return true;
      }
    } catch (_) {}
    return false;
  }
}
