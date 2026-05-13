import 'dart:async';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/repositories/downloader_repository.dart';
import '../datasources/downloader_remote_data_source.dart';
import '../models/download_model.dart';

/// Concrete implementation of [DownloaderRepository].
///
/// Delegates to the [DownloaderRemoteDataSource] and maps data-layer
/// exceptions into domain-friendly [DownloadEntity] snapshots with
/// [DownloadStatus.failed].
class DownloaderRepositoryImpl implements DownloaderRepository {
  final DownloaderRemoteDataSource remoteDataSource;

  DownloaderRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<DownloadEntity> startDownload(
    String url, {
    dynamic metadata,
    dynamic cancelToken,
    String? existingSavePath,
  }) async* {
    yield* remoteDataSource
        .downloadFile(
          url,
          metadata: metadata,
          cancelToken: cancelToken,
          existingSavePath: existingSavePath, // تمرير المسار للمحرك
        )
        .transform(
          StreamTransformer<DownloadModel, DownloadEntity>.fromHandlers(
            handleData: (model, sink) {
              sink.add(model);
            },
            handleError: (error, stackTrace, sink) {
              // Map data-layer exceptions into a failed entity so the
              // presentation layer always receives a clean domain object
              // instead of a raw exception.
              final message = error is ServerException
                  ? error.message
                  : error.toString();

              sink.add(
                DownloadModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  originalUrl: url,
                  title: '',
                  progress: 0,
                  savePath: '',
                  status: DownloadStatus.failed,
                ),
              );

              // Also forward as an error so the BLoC's onError fires if needed.
              sink.addError(Exception(message), stackTrace);
            },
          ),
        );
  }
}
