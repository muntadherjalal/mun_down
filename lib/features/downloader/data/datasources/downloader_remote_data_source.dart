import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/file_manager.dart';
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
    DownloadMetadata? metadata,
    CancelToken? cancelToken,
    String? existingSavePath,
  });
}

/// Concrete implementation backed by [Dio] for generic URLs and the
/// Cobalt API for universal media downloading.
///
/// - For all URLs (YouTube, TikTok, Instagram, etc.), the download is routed
///   through the Cobalt API which returns a direct download URL.
/// - The direct URL is then downloaded using [Dio] with retry+backoff.
/// - When [DownloadMetadata.needsMux] is true (legacy), this is now handled
///   by the Cobalt API itself (which returns muxed streams), so no ffmpeg
///   merging is needed.
class DownloaderRemoteDataSourceImpl implements DownloaderRemoteDataSource {
  final Dio dio;

  DownloaderRemoteDataSourceImpl({
    required this.dio,
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
  static const String _cobaltApiUrl = 'https://api.cobalt.tools/api/json';

  @override
  Stream<DownloadModel> downloadFile(
    String url, {
    DownloadMetadata? metadata,
    CancelToken? cancelToken,
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
    DownloadMetadata? metadata,
    CancelToken? cancelToken,
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
      } else {
        // metadata is null
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

      // ── Phase 2: Get direct download URL from Cobalt API ────────
      final directUrl = await _fetchDirectDownloadUrlFromCobalt(
        url: url,
        metadata: metadata,
        cancelToken: cancelToken,
      );

      // ── Phase 3: Downloading from direct URL ──────────────────
      await _downloadWithRetry(
        url: directUrl,
        savePath: savePath,
        baseModel: baseModel,
        controller: controller,
        cancelToken: cancelToken,
        allowResume: existingSavePath != null,
      );

      // ── Phase 4: Completed ────────────────────────────────
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

  /// Calls the Cobalt API to get a direct download URL for the given [url].
  ///
  /// Handles Cobalt API response statuses:
  /// - If status is "error": throws a [ServerException] with the message from the "text" field.
  /// - If status is "redirect" or "tunnel": extracts the direct link from the "url" field.
  /// - If status is "picker": extracts the direct link from the first item in the "picker" array.
  /// - If status is "rate-limit": throws a [ServerException] indicating rate-limiting.
  /// - If status is "stream": extracts the direct link from the "url" field (handled same as redirect).
  Future<String> _fetchDirectDownloadUrlFromCobalt({
    required String url,
    required DownloadMetadata? metadata,
    required CancelToken? cancelToken,
  }) async {
    // Determine download parameters from metadata
    final bool isAudioOnly = metadata is DownloadMetadata &&
        metadata.quality.toLowerCase().contains('kbps');

    String? vQuality;
    if (!isAudioOnly && metadata is DownloadMetadata) {
      // Extract numeric resolution from quality string (e.g., "1080p" -> "1080")
      final match = RegExp(r'(\d+)').firstMatch(metadata.quality);
      if (match != null) {
        vQuality = match.group(1);
      } else {
        vQuality = '1080'; // fallback to 1080p if not specified
      }
    }

    // Build the Cobalt API request body
    final requestBody = _buildCobaltRequestBody(
      url: url,
      isAudioOnly: isAudioOnly,
      vQuality: vQuality,
      aFormat: isAudioOnly ? metadata.format : null,
    );

    // Create a Dio instance specifically for Cobalt API calls with required headers
    final cobaltDio = Dio(BaseOptions(
      baseUrl: _cobaltApiUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'MunDownApp/1.5.0 (Android/iOS)',
      },
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ));

    try {
      final response = await cobaltDio.post(
        '',
        data: jsonEncode(requestBody),
        cancelToken: cancelToken,
      );

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Cobalt API returned status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final responseData = response.data as Map<String, dynamic>;
      final status = responseData['status'] as String?;

      switch (status) {
        case 'error':
          final errorMessage = responseData['text'] as String? ??
              'Unknown error from Cobalt API';
          throw ServerException(message: errorMessage);
        case 'redirect':
        case 'tunnel':
        case 'stream':
          final directUrl = responseData['url'] as String?;
          if (directUrl == null || directUrl.isEmpty) {
            throw ServerException(message: 'Cobalt API returned empty URL');
          }
          return directUrl;
        case 'picker':
          final picker = responseData['picker'] as List<dynamic>?;
          if (picker == null || picker.isEmpty) {
            throw ServerException(message: 'Cobalt API picker array is empty');
          }
          final first = picker.first as Map<String, dynamic>?;
          final directUrl = first?['url'] as String?;
          if (directUrl == null || directUrl.isEmpty) {
            throw ServerException(message: 'Cobalt API picker item has no URL');
          }
          return directUrl;
        case 'rate-limit':
          throw ServerException(
              message: 'Cobalt API rate limit exceeded. Please try again later.');
        default:
          throw ServerException(
              message: 'Cobalt API returned unknown status: $status');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      final status = e.response?.statusCode;
      final detail = e.response?.statusMessage ?? e.message;
      final String errorDetail = detail ?? 'Network error';
      // Handle specific error codes that Cobalt might return via Cloudflare or rate limiting
      if (status == 403 || status == 429) {
        throw ServerException(
          message: 'Cobalt API access blocked or rate limited. Please try again later.',
          statusCode: status,
        );
      }
      throw ServerException(
        message: status != null ? 'HTTP $status — $errorDetail' : errorDetail,
        statusCode: status,
      );
    } finally {
      cobaltDio.close();
    }
  }

  /// Builds the request body for the Cobalt API according to its specification.
  Map<String, dynamic> _buildCobaltRequestBody({
    required String url,
    required bool isAudioOnly,
    String? vQuality,
    String? aFormat,
  }) {
    final body = <String, dynamic>{
      'url': url,
      'downloadMode': 'auto', // Let Cobalt decide based on flags
      'isAudioOnly': isAudioOnly,
      if (vQuality != null && !isAudioOnly) 'vQuality': vQuality,
      if (aFormat != null && isAudioOnly) 'aFormat': aFormat,
    };
    // Remove null values by creating a new map
    return Map<String, dynamic>.fromEntries(
      body.entries.where((entry) => entry.value != null),
    );
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