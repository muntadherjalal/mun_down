import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/download_entity.dart';
import '../models/download_model.dart';

/// Contract for the remote data source responsible for downloading files.
abstract class DownloaderRemoteDataSource {
  /// Downloads the file at [url] and emits [DownloadModel] snapshots
  /// reflecting the current progress and status.
  Stream<DownloadModel> downloadFile(String url);
}

/// Concrete implementation backed by [Dio].
///
/// Uses [Dio.download] for chunked transfer and bridges the
/// `onReceiveProgress` callback into a [Stream] via a [StreamController].
class DownloaderRemoteDataSourceImpl implements DownloaderRemoteDataSource {
  final Dio dio;

  DownloaderRemoteDataSourceImpl({required this.dio});

  @override
  Stream<DownloadModel> downloadFile(String url) {
    final controller = StreamController<DownloadModel>();

    // Fire-and-forget — the stream carries the result.
    _performDownload(url, controller);

    return controller.stream;
  }

  // ────────────────────────────────────────────────────────────
  //  Internal download pipeline
  // ────────────────────────────────────────────────────────────

  Future<void> _performDownload(
    String url,
    StreamController<DownloadModel> controller,
  ) async {
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

      // Resolve file name from HEAD response or fall back to URL segment.
      final fileName = await _resolveFileName(url);
      final savePath = await _buildSavePath(fileName);

      // ── Phase 2: Downloading ──────────────────────────────
      final baseModel = DownloadModel(
        id: id,
        originalUrl: url,
        title: fileName,
        progress: 0,
        savePath: savePath,
        status: DownloadStatus.downloading,
      );

      controller.add(baseModel);

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            controller.add(baseModel.copyWith(progress: progress));
          }
        },
      );

      // ── Phase 3: Completed ────────────────────────────────
      controller.add(baseModel.copyWith(
        progress: 1.0,
        status: DownloadStatus.completed,
      ));
    } on DioException catch (e) {
      controller.addError(
        ServerException(
          message: e.message ?? 'Download failed',
          statusCode: e.response?.statusCode,
        ),
      );
    } catch (e) {
      controller.addError(
        ServerException(message: e.toString()),
      );
    } finally {
      await controller.close();
    }
  }

  /// Attempts a HEAD request to extract the file name from the
  /// `content-disposition` header. Falls back to the URL's last path segment.
  Future<String> _resolveFileName(String url) async {
    try {
      final response = await dio.head(url);
      final disposition = response.headers.value('content-disposition');
      if (disposition != null) {
        final match = RegExp(r'filename[*]?=["\s]*([^";]+)').firstMatch(disposition);
        if (match != null) {
          return Uri.decodeComponent(match.group(1)!.trim());
        }
      }
    } catch (_) {
      // HEAD not supported or failed — fall through.
    }

    // Derive from URL path.
    final uri = Uri.parse(url);
    final lastSegment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'download';
    return lastSegment.contains('.') ? lastSegment : '$lastSegment.bin';
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
