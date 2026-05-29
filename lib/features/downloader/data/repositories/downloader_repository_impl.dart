import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/entities/download_metadata.dart';
import '../../domain/repositories/downloader_repository.dart';
import '../datasources/downloader_remote_data_source.dart';
import '../datasources/downloader_local_data_source.dart';
import '../models/download_model.dart';
import '../models/persistent_download.dart';

/// Concrete implementation of [DownloaderRepository].
///
/// Delegates to the [DownloaderRemoteDataSource] and maps data-layer
/// exceptions into domain-friendly [DownloadEntity] snapshots with
/// [DownloadStatus.failed].
class DownloaderRepositoryImpl implements DownloaderRepository {
  final DownloaderRemoteDataSource remoteDataSource;
  final DownloaderLocalDataSource localDataSource;

  /// Map to keep track of active download tokens by URL for cancellation.
  final Map<String, CancelToken> _activeTokens = {};

  DownloaderRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Stream<DownloadEntity> startDownload(
    String url, {
    DownloadMetadata? metadata,
    String? existingSavePath,
  }) async* {
    // Create a cancel token for this download and track it
    final cancelToken = CancelToken();
    _activeTokens[url] = cancelToken;

    try {
      yield* remoteDataSource
          .downloadFile(
            url,
            metadata: metadata,
            cancelToken: cancelToken,
            existingSavePath: existingSavePath,
          )
          .transform(
            StreamTransformer<DownloadModel, DownloadEntity>.fromHandlers(
              handleData: (model, sink) {
                sink.add(model);
              },
              handleError: (error, stackTrace, sink) {
                // Map data-layer exceptions to appropriate Failures
                Failure failure;
                if (error is ServerException) {
                  failure = ServerFailure(message: error.message, statusCode: error.statusCode);
                } else if (error is SocketException) {
                  failure = NetworkFailure(message: 'No internet connection');
                } else if (error is FormatException) {
                  failure = ValidationFailure(message: 'Invalid data format');
                } else {
                  failure = ServerFailure(message: error.toString());
                }

                // Forward the Failure so BLoC can handle it properly
                sink.addError(failure, stackTrace);
              },
            ),
          );
    } finally {
      // Clean up the token when the stream ends (completed, canceled, or error)
      _activeTokens.remove(url);
    }
  }

  @override
  Future<void> pauseDownload(String url) async {
    final token = _activeTokens[url];
    if (token != null && !token.isCancelled) {
      token.cancel();
    }
  }

  @override
  Future<void> cancelDownload(String url) async {
    final token = _activeTokens[url];
    if (token != null && !token.isCancelled) {
      token.cancel();
    }
    // Ensure the token is removed from the map
    _activeTokens.remove(url);
  }

  @override
  Future<void> saveDownloadState(String id, DownloadEntity entity, DownloadMetadata metadata) async {
    final persistentDownload = PersistentDownload.fromEntityAndMetadata(entity, metadata);
    await localDataSource.saveDownloadState(persistentDownload);
  }

  @override
  Future<List<DownloadEntity>> getSavedDownloads() async {
    final persistentDownloads = await localDataSource.getSavedDownloads();
    return persistentDownloads
        .map((persistentDownload) => persistentDownload.toEntity())
        .toList();
  }

  @override
  Future<void> deleteDownloadState(String id) async {
    await localDataSource.deleteDownloadState(id);
  }

  @override
  Future<void> clearAllDownloads() async {
    await localDataSource.clearAllDownloads();
    // Also cancel any active downloads
    for (final token in _activeTokens.values) {
      if (!token.isCancelled) {
        token.cancel();
      }
    }
    _activeTokens.clear();
  }
}