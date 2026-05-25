import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/file_manager.dart';
import '../../../../core/utils/youtube_extractor.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/entities/download_metadata.dart';
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

/// Concrete implementation backed by [Dio] for generic URLs and the
/// `youtube_explode_dart` library for YouTube streams.
///
/// - For YouTube downloads (metadata.videoId + metadata.itag are set), the
///   download is routed through [YouTubeExtractor.downloadStream], which
///   uses the library's own HTTP client. This avoids 403 errors caused by
///   client-mismatched UAs and signed-URL expiration.
/// - For non-YouTube URLs, falls back to [Dio] with retry+backoff.
/// - When [DownloadMetadata.needsMux] is true, downloads video-only and
///   audio-only streams separately, then merges them with ffmpeg.
class DownloaderRemoteDataSourceImpl implements DownloaderRemoteDataSource {
  final Dio dio;
  final YouTubeExtractor extractor;

  DownloaderRemoteDataSourceImpl({
    required this.dio,
    required this.extractor,
  });

  /// Headers sent with non-YouTube generic media downloads. Mimicking a
  /// desktop browser request avoids basic anti-bot checks for arbitrary
  /// streaming URLs.
  static const Map<String, String> _genericHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static const int _maxRetries = 3;

  @override
  Stream<DownloadModel> downloadFile(
    String url, {
    dynamic metadata,
    dynamic cancelToken,
    String? existingSavePath,
  }) {
    final controller = StreamController<DownloadModel>();

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
        if (await Permission.manageExternalStorage.isGranted ||
            await Permission.storage.isGranted) {
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

      final baseModel = DownloadModel(
        id: id,
        originalUrl: url,
        title: existingSavePath != null ? savePath.split('/').last : fileName,
        progress: 0,
        savePath: savePath,
        status: DownloadStatus.downloading,
        thumbnailUrl: thumbnailUrl,
      );

      controller.add(baseModel);

      // ── Phase 2: Downloading ──────────────────────────────
      final isYouTube = metadata is DownloadMetadata &&
          (metadata.videoId?.isNotEmpty ?? false) &&
          metadata.itag != null;

      if (isYouTube) {
        await _downloadYouTube(
          metadata: metadata,
          savePath: savePath,
          baseModel: baseModel,
          controller: controller,
          cancelToken: cancelToken as CancelToken?,
          allowResume: existingSavePath != null,
        );
      } else if (metadata is DownloadMetadata &&
          metadata.needsMux &&
          (metadata.audioUrl?.isNotEmpty ?? false)) {
        await _downloadAndMux(
          videoUrl: url,
          audioUrl: metadata.audioUrl!,
          savePath: savePath,
          baseModel: baseModel,
          controller: controller,
          cancelToken: cancelToken as CancelToken?,
        );
      } else {
        await _downloadWithRetry(
          url: url,
          savePath: savePath,
          baseModel: baseModel,
          controller: controller,
          cancelToken: cancelToken as CancelToken?,
          allowResume: existingSavePath != null,
        );
      }

      // ── Phase 3: Completed ────────────────────────────────
      if (metadata is DownloadMetadata) {
        try {
          final file = File('$savePath.json');
          await file.writeAsString(
            jsonEncode(DownloadMetadataModel.fromEntity(metadata).toJson()),
          );
        } catch (_) {}
      }

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
        controller.add(
          DownloadModel(
            id: id,
            originalUrl: url,
            title: '',
            progress: 0,
            savePath: '',
            status: DownloadStatus.paused,
          ),
        );
      } else {
        final status = e.response?.statusCode;
        final detail =
            e.response?.statusMessage ?? e.message ?? 'Network error';
        controller.addError(
          ServerException(
            message: status != null ? 'HTTP $status — $detail' : detail,
            statusCode: status,
          ),
        );
      }
    } catch (e) {
      controller.addError(ServerException(message: e.toString()));
    } finally {
      await controller.close();
    }
  }

  /// Performs a single-file download with up to [_maxRetries] attempts and
  /// exponential backoff. Supports HTTP Range resume when [allowResume] is true.
  Future<void> _downloadWithRetry({
    required String url,
    required String savePath,
    required DownloadModel baseModel,
    required StreamController<DownloadModel> controller,
    required CancelToken? cancelToken,
    required bool allowResume,
  }) async {
    DioException? lastError;
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        int startBytes = 0;
        if (allowResume) {
          final f = File(savePath);
          if (f.existsSync()) startBytes = await f.length();
        }

        final headers = Map<String, String>.from(_genericHeaders);
        if (startBytes > 0) headers['Range'] = 'bytes=$startBytes-';
        await dio.download(
          url,
          savePath,
          options: Options(
            headers: headers,
            // googlevideo can be slow to start; allow up to 60s receive
            receiveTimeout: const Duration(seconds: 60),
            responseType: ResponseType.bytes,
          ),
          cancelToken: cancelToken,
          deleteOnError: false,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final realTotal = startBytes > 0 && total != -1
                  ? total + startBytes
                  : total;
              final realReceived = received + startBytes;
              controller.add(
                baseModel.copyWith(
                  progress: (realReceived / realTotal).clamp(0.0, 1.0),
                  receivedBytes: realReceived,
                  totalBytes: realTotal,
                ),
              );
            } else {
              controller.add(
                baseModel.copyWith(
                  receivedBytes: received + startBytes,
                  totalBytes: 0,
                ),
              );
            }
          },
        );
        return; // success
      } on DioException catch (e) {
        // Never retry user-initiated cancellations.
        if (e.type == DioExceptionType.cancel) rethrow;
        lastError = e;
        if (attempt < _maxRetries) {
          // Exponential backoff: 1s, 2s, 4s
          final delaySeconds = 1 << (attempt - 1);
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      }
    }
    throw lastError!;
  }

  /// Downloads a YouTube stream (or video-only + audio-only pair) through
  /// `youtube_explode_dart`. The library re-fetches the manifest, signs the
  /// request with the right client UA, and handles 403 retries internally —
  /// none of which Dio can do reliably for googlevideo URLs.
  Future<void> _downloadYouTube({
    required DownloadMetadata metadata,
    required String savePath,
    required DownloadModel baseModel,
    required StreamController<DownloadModel> controller,
    required CancelToken? cancelToken,
    required bool allowResume,
  }) async {
    final videoId = metadata.videoId!;
    final itag = metadata.itag!;

    if (metadata.needsMux && metadata.audioItag != null) {
      // ── Two-leg download (video-only + audio-only) + ffmpeg mux ────
      final tmpDir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final videoTmp = '${tmpDir.path}/mun_video_$stamp.tmp';
      final audioTmp = '${tmpDir.path}/mun_audio_$stamp.tmp';

      int videoReceived = 0, videoTotal = 0;
      int audioReceived = 0, audioTotal = 0;

      void emitCombined() {
        final total = videoTotal + audioTotal;
        final received = videoReceived + audioReceived;
        final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
        controller.add(
          baseModel.copyWith(
            status: DownloadStatus.downloading,
            progress: progress,
            receivedBytes: received,
            totalBytes: total,
          ),
        );
      }

      try {
        await extractor.downloadStream(
          videoId: videoId,
          itag: itag,
          savePath: videoTmp,
          cancelToken: cancelToken,
          onProgress: (rcv, tot) {
            videoReceived = rcv;
            videoTotal = tot;
            emitCombined();
          },
        ).timeout(
          const Duration(minutes: 2),
          onTimeout: () => throw TimeoutException('YouTube video download timed out after 2 minutes'),
        );

        await extractor.downloadStream(
          videoId: videoId,
          itag: metadata.audioItag!,
          savePath: audioTmp,
          cancelToken: cancelToken,
          onProgress: (rcv, tot) {
            audioReceived = rcv;
            audioTotal = tot;
            emitCombined();
          },
        ).timeout(
          const Duration(minutes: 2),
          onTimeout: () => throw TimeoutException('YouTube audio download timed out after 2 minutes'),
        );

        // Indicate muxing phase to the UI.
        controller.add(
          baseModel.copyWith(
            status: DownloadStatus.downloading,
            progress: 0.98,
            receivedBytes: videoReceived + audioReceived,
            totalBytes: videoTotal + audioTotal,
          ),
        );

        final cmd =
            '-y -i "$videoTmp" -i "$audioTmp" -c:v copy -c:a aac -movflags +faststart "$savePath"';
        final session = await FFmpegKit.execute(cmd);
        final returnCode = await session.getReturnCode();
        if (!ReturnCode.isSuccess(returnCode)) {
          final logs = await session.getAllLogsAsString();
          throw ServerException(
            message:
                'Failed to merge video and audio: ${(logs ?? '').split('\n').last}',
          );
        }
      } finally {
        for (final p in [videoTmp, audioTmp]) {
          try {
            final f = File(p);
            if (f.existsSync()) await f.delete();
          } catch (_) {}
        }
      }
    } else {
      // ── Single-stream download (muxed video / audio-only) ──────────
      // Skip-bytes resume: existing partial file is preserved; library
      // re-fetches from byte 0 and discards already-saved bytes.
      var startOffset = 0;
      if (allowResume) {
        final f = File(savePath);
        if (f.existsSync()) startOffset = await f.length();
      } else {
        // Fresh download — wipe any leftover partial file so writeOnlyAppend
        // doesn't accidentally append to an unrelated previous attempt.
        final f = File(savePath);
        if (f.existsSync()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }

      await extractor.downloadStream(
        videoId: videoId,
        itag: itag,
        savePath: savePath,
        startOffset: startOffset,
        cancelToken: cancelToken,
        onProgress: (rcv, tot) {
          if (tot > 0) {
            controller.add(
              baseModel.copyWith(
                progress: (rcv / tot).clamp(0.0, 1.0),
                receivedBytes: rcv,
                totalBytes: tot,
              ),
            );
          } else {
            controller.add(
              baseModel.copyWith(
                receivedBytes: rcv,
                totalBytes: 0,
              ),
            );
          }
        },
      );
    }
  }

  /// Downloads video-only + audio-only streams and merges them with ffmpeg.
  Future<void> _downloadAndMux({
    required String videoUrl,
    required String audioUrl,
    required String savePath,
    required DownloadModel baseModel,
    required StreamController<DownloadModel> controller,
    required CancelToken? cancelToken,
  }) async {
    final tmpDir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final videoTmp = '${tmpDir.path}/mun_video_$stamp.tmp';
    final audioTmp = '${tmpDir.path}/mun_audio_$stamp.tmp';

    int videoReceived = 0, videoTotal = 0;
    int audioReceived = 0, audioTotal = 0;

    void emitCombined({DownloadStatus status = DownloadStatus.downloading}) {
      final total = videoTotal + audioTotal;
      final received = videoReceived + audioReceived;
      final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
      controller.add(
        baseModel.copyWith(
          status: status,
          progress: progress,
          receivedBytes: received,
          totalBytes: total,
        ),
      );
    }

    try {
      // Download video & audio sequentially so we don't saturate bandwidth and
      // get more accurate progress reporting.
      await _downloadWithRetryRaw(
        url: videoUrl,
        savePath: videoTmp,
        cancelToken: cancelToken,
        onProgress: (rcv, tot) {
          videoReceived = rcv;
          videoTotal = tot;
          emitCombined();
        },
      );

      await _downloadWithRetryRaw(
        url: audioUrl,
        savePath: audioTmp,
        cancelToken: cancelToken,
        onProgress: (rcv, tot) {
          audioReceived = rcv;
          audioTotal = tot;
          emitCombined();
        },
      );

      // Muxing phase — emit a "fetching"-style update so the UI shows activity.
      controller.add(
        baseModel.copyWith(
          status: DownloadStatus.downloading,
          progress: 0.98,
          receivedBytes: videoReceived + audioReceived,
          totalBytes: videoTotal + audioTotal,
        ),
      );

      final cmd =
          '-y -i "$videoTmp" -i "$audioTmp" -c:v copy -c:a aac -movflags +faststart "$savePath"';
      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getAllLogsAsString();
        throw ServerException(
          message:
              'Failed to merge video and audio: ${(logs ?? '').split('\n').last}',
        );
      }
    } finally {
      // Clean up temp files regardless of success/failure.
      for (final p in [videoTmp, audioTmp]) {
        try {
          final f = File(p);
          if (f.existsSync()) await f.delete();
        } catch (_) {}
      }
    }
  }

  /// Lower-level retry helper used by the mux pipeline. Does not emit
  /// [DownloadModel]s itself — caller aggregates progress via [onProgress].
  Future<void> _downloadWithRetryRaw({
    required String url,
    required String savePath,
    required CancelToken? cancelToken,
    required void Function(int received, int total) onProgress,
  }) async {
    DioException? lastError;
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        await dio.download(
          url,
          savePath,
          options: Options(
            headers: _genericHeaders,
            receiveTimeout: const Duration(seconds: 60),
            responseType: ResponseType.bytes,
          ),
          cancelToken: cancelToken,
          deleteOnError: true,
          onReceiveProgress: (rcv, tot) => onProgress(rcv, tot < 0 ? 0 : tot),
        );
        return;
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) rethrow;
        lastError = e;
        if (attempt < _maxRetries) {
          final delaySeconds = 1 << (attempt - 1);
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      }
    }
    throw lastError!;
  }

  /// Sanitizes a string for use as a file name.
  String _sanitizeFileName(String name) {
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
      return 'mp3';
    }
    if (lower.contains('mp4')) return 'mp4';
    if (lower.contains('webm')) return 'webm';
    if (lower.contains('3gpp')) return '3gp';
    return 'mp4';
  }

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

      final contentType = response.headers.value('content-type');
      if (hintTitle != null && contentType != null) {
        final ext = _contentTypeToExtension(contentType);
        if (ext != null) {
          return '${_sanitizeFileName(hintTitle)}.$ext';
        }
      }
    } catch (_) {}

    final uri = Uri.parse(url);
    final lastSegment = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'download';

    if (lastSegment.contains('.') && !lastSegment.endsWith('.bin')) {
      return lastSegment;
    }

    if (hintTitle != null) {
      return '${_sanitizeFileName(hintTitle)}.mp4';
    }

    return lastSegment.contains('.') ? lastSegment : '$lastSegment.mp4';
  }

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

  Future<String> _buildSavePath(String fileName) async {
    final downloadsDirPath = await FileManager.downloadsPath;
    final downloadsDir = Directory(downloadsDirPath);

    var file = File('${downloadsDir.path}/$fileName');
    var counter = 1;

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
