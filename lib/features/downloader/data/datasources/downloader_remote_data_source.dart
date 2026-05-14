import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/file_manager.dart';
import '../../domain/entities/download_entity.dart';
import '../models/download_model.dart';
import '../models/download_metadata_model.dart';

/// Contract for the remote data source responsible for downloading files.
abstract class DownloaderRemoteDataSource {
  /// Downloads the file at [url] and emits [DownloadModel] snapshots
  /// reflecting the current progress and status.
  Stream<DownloadModel> downloadFile(
    String url, {
    dynamic metadata,
    dynamic cancelToken,
    String? existingSavePath,
  });
}

/// Concrete implementation backed by [Dio].
///
/// Uses [Dio.download] for chunked transfer and bridges the
/// `onReceiveProgress` callback into a [Stream] via a [StreamController].
class DownloaderRemoteDataSourceImpl implements DownloaderRemoteDataSource {
  final Dio dio;

  DownloaderRemoteDataSourceImpl({required this.dio});

  @override
  Stream<DownloadModel> downloadFile(
    String url, {
    dynamic metadata,
    dynamic cancelToken,
    String? existingSavePath,
  }) {
    final controller = StreamController<DownloadModel>();

    // Fire-and-forget — the stream carries the result.
    _performDownload(
      url,
      controller,
      metadata: metadata,
      cancelToken: cancelToken,
      existingSavePath: existingSavePath,
    );

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
    String? existingSavePath,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      // ── Phase 1: Fetching metadata ────────────────────────
      controller.add(
        DownloadModel(
          id: id,
          originalUrl: url,
          title: '',
          progress: 0,
          savePath: '',
          status: DownloadStatus.fetching,
        ),
      );

      // Check permissions for Android
      if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted) {
          // Granted
        } else {
          var status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
          if (!status.isGranted) {
            throw const ServerException(message: 'Storage permission denied');
          }
        }
      }

      // Build file name from metadata or resolve from URL.
      final String fileName;
      String? thumbnailUrl;

      if (metadata is DownloadMetadata) {
        // Fix: Accurately determine if it's an audio file
        final isAudio = metadata.quality.toLowerCase().contains('kbps');
        final sanitizedTitle = _sanitizeFileName(metadata.title);
        final ext = _mapFormatToExtension(metadata.format, isAudio: isAudio);
        fileName = '$sanitizedTitle.$ext';
        thumbnailUrl = metadata.thumbnailUrl;
      } else if (metadata != null && (metadata as dynamic).title != null) {
        fileName = await _resolveFileName(
          url,
          hintTitle: (metadata as dynamic).title as String?,
        );
      } else {
        fileName = await _resolveFileName(url);
      }

      // If resuming, use existing path. Otherwise, build a new one.
      final savePath = existingSavePath ?? await _buildSavePath(fileName);

      // Calculate starting bytes for Resume functionality
      int startBytes = 0;
      final tempFile = File(savePath);
      if (tempFile.existsSync() && existingSavePath != null) {
        startBytes = await tempFile.length();
      }

      // ── Phase 2: Downloading ──────────────────────────────
      final baseModel = DownloadModel(
        id: id,
        originalUrl: url,
        title: existingSavePath != null
            ? savePath.split('/').last
            : fileName, // keep original name if resuming
        progress: startBytes > 0 ? -1 : 0, // -1 means calculating if resuming
        savePath: savePath,
        status: DownloadStatus.downloading,
        thumbnailUrl: thumbnailUrl,
      );

      controller.add(baseModel);

      // Setup Headers for resuming
      final options = Options(
        headers: startBytes > 0 ? {'Range': 'bytes=$startBytes-'} : null,
      );

      await dio.download(
        url,
        savePath,
        options: options,
        cancelToken: cancelToken as CancelToken?,
        deleteOnError: false, // CRITICAL: Do not delete file if canceled/paused
        onReceiveProgress: (received, total) {
          if (total > 0) {
            // If resuming, total from Dio is remaining bytes, not absolute total.
            final realTotal = startBytes > 0 && total != -1
                ? total + startBytes
                : total;
            final realReceived = received + startBytes;
            final progress = (realReceived / realTotal).clamp(0.0, 1.0);

            controller.add(
              baseModel.copyWith(
                progress: progress,
                receivedBytes: realReceived,
                totalBytes: realTotal,
              ),
            );
          } else {
            // Unknown total size
            controller.add(
              baseModel.copyWith(
                receivedBytes: received + startBytes,
                totalBytes: 0,
              ),
            );
          }
        },
      );

      // ── Phase 3: Completed ────────────────────────────────
      // Save metadata sidecar
      if (metadata is DownloadMetadata) {
        try {
          final file = File('$savePath.json');
          await file.writeAsString(jsonEncode(DownloadMetadataModel.fromEntity(metadata).toJson()));
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

      controller.add(
        baseModel.copyWith(
          progress: 1.0,
          status: DownloadStatus.completed,
          totalBytes: finalSize,
          receivedBytes: finalSize,
        ),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // CRITICAL FIX: User-initiated cancel/pause — emit PAUSED state, NOT FAILED.
        controller.add(
          DownloadModel(
            id: id,
            originalUrl: url,
            title: '',
            progress: 0,
            savePath: '',
            status: DownloadStatus.paused, // Treat cancel token as Pause
          ),
        );
      } else {
        controller.addError(
          ServerException(
            message: e.message ?? 'Download failed',
            statusCode: e.response?.statusCode,
          ),
        );
      }
    } catch (e) {
      controller.addError(ServerException(message: e.toString()));
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
      return 'mp3'; // Fallback to mp3 instead of m4a to avoid unplayable files
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
        final match = RegExp(
          r'filename[*]?=["\s]*([^";]+)',
        ).firstMatch(disposition);
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
    final lastSegment = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'download';

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
    if (lower.contains('audio/mp4') || lower.contains('audio/m4a')) {
      return 'm4a';
    }
    if (lower.contains('audio/mpeg')) return 'mp3';
    if (lower.contains('audio/webm')) return 'webm';
    if (lower.contains('audio/ogg')) return 'ogg';
    return null;
  }

  /// Returns the absolute save path,
  /// appending a numeric suffix to avoid overwriting existing files.
  Future<String> _buildSavePath(String fileName) async {
    final downloadsDirPath = await FileManager.downloadsPath;
    final downloadsDir = Directory(downloadsDirPath);

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
