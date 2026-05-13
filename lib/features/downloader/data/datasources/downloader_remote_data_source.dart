import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/file_manager.dart';
import '../../domain/entities/download_entity.dart';
import '../models/download_model.dart';

/// Contract for the remote data source responsible for downloading files.
abstract class DownloaderRemoteDataSource {
  /// Downloads the file at [url] and emits [DownloadModel] snapshots
  /// reflecting the current progress and status.
  Stream<DownloadModel> downloadFile(String url, {dynamic metadata, dynamic cancelToken});
}

/// Concrete implementation backed by [Dio].
///
/// Uses [Dio.download] for chunked transfer and bridges the
/// `onReceiveProgress` callback into a [Stream] via a [StreamController].
class DownloaderRemoteDataSourceImpl implements DownloaderRemoteDataSource {
  final Dio dio;

  DownloaderRemoteDataSourceImpl({required this.dio});

  @override
  Stream<DownloadModel> downloadFile(String url, {dynamic metadata, dynamic cancelToken}) {
    final controller = StreamController<DownloadModel>();

    // Fire-and-forget — the stream carries the result.
    _performDownload(url, controller, metadata: metadata, cancelToken: cancelToken);

    return controller.stream;
  }

  // ────────────────────────────────────────────────────────────
  //  Internal download pipeline
  // ────────────────────────────────────────────────────────────

  Future<void> _performDownload(
    String url,
    StreamController<DownloadModel> controller, {
    dynamic metadata,
    dynamic cancelToken,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      // ── Phase 1: Fetching metadata ────────────────────────
      controller.add(DownloadModel(
        id: id,
        originalUrl: url,
        title: '',
        progress: 0,
        savePath: '',
        status: DownloadStatus.fetching,
      ));

      // Build file name from metadata or resolve from URL.
      final String fileName;
      String? thumbnailUrl;

      if (metadata is DownloadMetadata) {
        // Use metadata title + format for correct extension
        final sanitizedTitle = _sanitizeFileName(metadata.title);
        final ext = _mapFormatToExtension(metadata.format, isAudio: metadata.format == 'm4a' || metadata.format == 'webm' && metadata.quality.contains('kbps'));
        fileName = '$sanitizedTitle.$ext';
        thumbnailUrl = metadata.thumbnailUrl;
      } else if (metadata != null && (metadata as dynamic).title != null) {
        fileName = await _resolveFileName(url, hintTitle: (metadata as dynamic).title as String?);
      } else {
        fileName = await _resolveFileName(url);
      }

      final savePath = await _buildSavePath(fileName);

      // ── Phase 2: Downloading ──────────────────────────────
      final baseModel = DownloadModel(
        id: id,
        originalUrl: url,
        title: fileName,
        progress: 0,
        savePath: savePath,
        status: DownloadStatus.downloading,
        thumbnailUrl: thumbnailUrl,
      );

      controller.add(baseModel);

      await dio.download(
        url,
        savePath,
        cancelToken: cancelToken as CancelToken?,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            controller.add(baseModel.copyWith(
              progress: progress,
              receivedBytes: received,
              totalBytes: total,
            ));
          } else {
            // Unknown total size — report received bytes only
            controller.add(baseModel.copyWith(
              receivedBytes: received,
              totalBytes: 0,
            ));
          }
        },
      );

      // ── Phase 3: Completed ────────────────────────────────
      // Save metadata sidecar
      if (metadata is DownloadMetadata) {
        try {
          final file = File('$savePath.json');
          await file.writeAsString(jsonEncode(metadata.toJson()));
        } catch (_) {}
      }

      // Get final file size
      int finalSize = 0;
      try {
        final savedFile = File(savePath);
        if (savedFile.existsSync()) {
          finalSize = await savedFile.length();
        }
      } catch (_) {}

      controller.add(baseModel.copyWith(
        progress: 1.0,
        status: DownloadStatus.completed,
        totalBytes: finalSize,
        receivedBytes: finalSize,
      ));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // User-initiated cancel — don't treat as error
        controller.add(DownloadModel(
          id: id,
          originalUrl: url,
          title: '',
          progress: 0,
          savePath: '',
          status: DownloadStatus.failed,
        ));
      } else {
        controller.addError(
          ServerException(
            message: e.message ?? 'Download failed',
            statusCode: e.response?.statusCode,
          ),
        );
      }
    } catch (e) {
      controller.addError(
        ServerException(message: e.toString()),
      );
    } finally {
      await controller.close();
    }
  }

  /// Sanitizes a string for use as a file name.
  String _sanitizeFileName(String name) {
    // Remove characters that are invalid in file names
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Maps a container format string to a proper file extension.
  String _mapFormatToExtension(String format, {bool isAudio = false}) {
    final lower = format.toLowerCase();
    if (isAudio) {
      if (lower.contains('mp4') || lower.contains('m4a')) return 'm4a';
      if (lower.contains('webm') || lower.contains('opus')) return 'opus';
      if (lower.contains('ogg')) return 'ogg';
      return 'm4a'; // safe default for audio
    }
    if (lower.contains('mp4')) return 'mp4';
    if (lower.contains('webm')) return 'webm';
    if (lower.contains('3gpp')) return '3gp';
    return 'mp4'; // safe default for video
  }

  /// Attempts a HEAD request to extract the file name from the
  /// `content-disposition` header. Falls back to the URL's last path segment.
  Future<String> _resolveFileName(String url, {String? hintTitle}) async {
    try {
      final response = await dio.head(url);
      final disposition = response.headers.value('content-disposition');
      if (disposition != null) {
        final match = RegExp(r'filename[*]?=["\s]*([^";]+)').firstMatch(disposition);
        if (match != null) {
          return Uri.decodeComponent(match.group(1)!.trim());
        }
      }

      // Try to infer extension from content-type
      final contentType = response.headers.value('content-type');
      if (hintTitle != null && contentType != null) {
        final ext = _contentTypeToExtension(contentType);
        if (ext != null) {
          return '${_sanitizeFileName(hintTitle)}.$ext';
        }
      }
    } catch (_) {
      // HEAD not supported or failed — fall through.
    }

    // Derive from URL path.
    final uri = Uri.parse(url);
    final lastSegment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'download';

    // If the segment has an extension, use it; otherwise try to use hint title
    if (lastSegment.contains('.') && !lastSegment.endsWith('.bin')) {
      return lastSegment;
    }

    if (hintTitle != null) {
      return '${_sanitizeFileName(hintTitle)}.mp4';
    }

    return lastSegment.contains('.') ? lastSegment : '$lastSegment.mp4';
  }

  /// Maps a content-type header to a file extension.
  String? _contentTypeToExtension(String contentType) {
    final lower = contentType.toLowerCase();
    if (lower.contains('video/mp4')) return 'mp4';
    if (lower.contains('video/webm')) return 'webm';
    if (lower.contains('audio/mp4') || lower.contains('audio/m4a')) return 'm4a';
    if (lower.contains('audio/mpeg')) return 'mp3';
    if (lower.contains('audio/webm')) return 'webm';
    if (lower.contains('audio/ogg')) return 'ogg';
    return null;
  }

  /// Returns the absolute save path inside the app's documents directory,
  /// appending a numeric suffix to avoid overwriting existing files.
  Future<String> _buildSavePath(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${dir.path}/MunDown');

    if (!downloadsDir.existsSync()) {
      await downloadsDir.create(recursive: true);
    }

    var file = File('${downloadsDir.path}/$fileName');
    var counter = 1;

    // Avoid collisions: file.mp4 → file (1).mp4 → file (2).mp4 …
    while (file.existsSync()) {
      final dot = fileName.lastIndexOf('.');
      final name = dot != -1 ? fileName.substring(0, dot) : fileName;
      final ext = dot != -1 ? fileName.substring(dot) : '';
      file = File('${downloadsDir.path}/$name ($counter)$ext');
      counter++;
    }

    return file.path;
  }
}
