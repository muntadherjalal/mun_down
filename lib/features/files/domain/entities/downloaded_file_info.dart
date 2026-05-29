// Information combining the file and its metadata.
import '../../../downloader/domain/entities/download_metadata.dart';

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