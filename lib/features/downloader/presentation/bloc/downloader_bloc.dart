import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/network_info.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/entities/download_metadata.dart';
import '../../domain/repositories/downloader_repository.dart';
import 'dart:io';

part 'downloader_event.dart';
part 'downloader_state.dart';

/// Orchestrates a single download session.
///
/// Listens to the [DownloaderRepository] stream and maps every
/// [DownloadEntity] snapshot to the appropriate presentation state.
class DownloaderBloc extends Bloc<DownloaderEvent, DownloaderState> {
  final DownloaderRepository _repository;
  final NetworkInfo _networkInfo;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  CancelToken? _cancelToken;

  /// Stores the last known entity snapshot for pause/resume.
  DownloadEntity? _lastEntity;

  /// Stores the last download URL and metadata for resume.
  String? _lastUrl;
  DownloadMetadata? _lastMetadata;

  /// Stores the path to the partially downloaded file.
  String? _lastSavePath;

  /// Stores the last failure for failed state mapping.
  Failure? _lastFailure;

  DownloaderBloc({
    required DownloaderRepository repository,
    required NetworkInfo networkInfo,
  }) : _repository = repository,
       _networkInfo = networkInfo,
       super(const DownloaderInitialState()) {
    on<StartDownloadEvent>(_onStartDownload);
    on<ResetDownloaderEvent>(_onReset);
    on<NetworkDroppedEvent>(_onNetworkDropped);
    on<PauseDownloadEvent>(_onPause);
    on<ResumeDownloadEvent>(_onResume);
    on<InitializeFromSavedDownloadsEvent>(_onInitializeFromSavedDownloads);

    _networkSubscription = _networkInfo.onConnectivityChanged.listen((results) {
      if (!results.any((r) => r != ConnectivityResult.none)) {
        add(const NetworkDroppedEvent());
      }
    });

    // Initialize from saved downloads when the BLoC is created
    add(const InitializeFromSavedDownloadsEvent());
  }

  @override
  Future<void> close() {
    _networkSubscription?.cancel();
    _cancelToken?.cancel();
    return super.close();
  }

  // ────────────────────────────────────────────────────────────
  //  Event handlers
  // ────────────────────────────────────────────────────────────

  Future<void> _onStartDownload(
    StartDownloadEvent event,
    Emitter<DownloaderState> emit,
  ) async {
    // Reset last failure on new download attempt
    _lastFailure = null;

    final hasConnection = await _networkInfo.isConnected;
    if (!hasConnection) {
      emit(DownloaderFailedState(failure: NetworkFailure()));
      return;
    }

    _cancelToken = CancelToken();
    _lastUrl = event.url;
    _lastMetadata = event.metadata;

    // Clear last path if it's a completely new download,
    // keep it if event.existingSavePath is passed (Resume).
    _lastSavePath = event.existingSavePath;

    // `emit.forEach` automatically subscribes, forwards items, and
    // cancels the subscription if the BLoC is closed mid-download.
    await emit.forEach<DownloadEntity>(
      _repository.startDownload(
        event.url,
        metadata: event.metadata,
        cancelToken: _cancelToken,
        existingSavePath: _lastSavePath, // Pass the path to engine
      ),
      onData: (entity) {
        _lastEntity = entity;
        _lastSavePath = entity.savePath.isNotEmpty
            ? entity.savePath
            : _lastSavePath;

        final mappedState = _mapEntityToState(entity);

        // Silent completion: notify Library to refresh without navigation.
        if (mappedState is DownloaderCompletedState) {
          _lastSavePath = null; // Clear path on success
          _lastFailure = null; // Clear failure on success
        }

        return mappedState;
      },
      onError: (error, _) {
        // Map exceptions to appropriate Failure types and store for failed state
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
        _lastFailure = failure;
        return DownloaderFailedState(failure: failure);
      },
    );
  }

  void _onInitializeFromSavedDownloads(
    InitializeFromSavedDownloadsEvent event,
    Emitter<DownloaderState> emit,
  ) async {
    // Initialize from saved downloads
    final savedDownloads = await _repository.getSavedDownloads();
    if (savedDownloads.isNotEmpty) {
      // For now, we'll just show the first saved download as an example
      // In a real implementation, we might want to show all saved downloads
      // or restore the most recent one
      final firstDownload = savedDownloads.first;

      // Create a FileMetadata object for the download
      final fileMetadata = FileMetadata(
        title: firstDownload.title,
        thumbnailUrl: firstDownload.thumbnailUrl,
        author: 'Unknown',
        duration: null,
        sourceUrl: firstDownload.originalUrl,
        downloadedAt: DateTime.now(),
        fileSizeBytes: firstDownload.totalBytes,
        format: 'mp4', // default format
        quality: 'unknown',
      );

      // We need to get the metadata to properly initialize
      // For simplicity in this example, we'll create a basic metadata object
      // A more complete implementation would store/load the metadata as well
      final metadata = DownloadMetadata(
        fileMetadata: fileMetadata,
        youtubeMetadata: null, // Not a YouTube download by default
      );

      // Set the last known state for resume functionality
      _lastEntity = firstDownload;
      _lastUrl = firstDownload.originalUrl;
      _lastMetadata = metadata;
      _lastSavePath = firstDownload.savePath;

      // Emit the appropriate state based on the download status
      emit(_mapEntityToState(firstDownload));
    }
    // If no saved downloads, remain in initial state
  }

  void _onReset(ResetDownloaderEvent event, Emitter<DownloaderState> emit) {
    _cancelToken?.cancel();
    _cancelToken = null;
    _lastEntity = null;
    _lastUrl = null;
    _lastMetadata = null;
    _lastSavePath = null;
    _lastFailure = null;
    emit(const DownloaderInitialState());
  }

  void _onNetworkDropped(
    NetworkDroppedEvent event,
    Emitter<DownloaderState> emit,
  ) {
    if (state is DownloaderProgressState || state is DownloaderFetchingState) {
      // Pause instead of failing so the file is kept
      _cancelToken?.cancel();
      _cancelToken = null;
      if (_lastEntity != null) {
        emit(DownloaderPausedState(entity: _lastEntity!));
      } else {
        emit(DownloaderFailedState(failure: NetworkFailure()));
      }
    }
  }

  void _onPause(PauseDownloadEvent event, Emitter<DownloaderState> emit) {
    if (state is DownloaderProgressState) {
      _cancelToken?.cancel();
      _cancelToken = null;
      final entity = _lastEntity;
      if (entity != null) {
        emit(DownloaderPausedState(entity: entity));
      }
    }
  }

  Future<void> _onResume(
    ResumeDownloadEvent event,
    Emitter<DownloaderState> emit,
  ) async {
    // REAL RESUME: Start download passing the existing file path.
    if (_lastUrl != null && _lastSavePath != null) {
      add(
        StartDownloadEvent(
          url: _lastUrl!,
          metadata: _lastMetadata,
          existingSavePath: _lastSavePath,
        ),
      );
    } else if (_lastUrl != null) {
      // Fallback if path is somehow lost
      add(StartDownloadEvent(url: _lastUrl!, metadata: _lastMetadata));
    }
  }

  // ────────────────────────────────────────────────────────────
  //  Mapping helpers
  // ────────────────────────────────────────────────────────────

  DownloaderState _mapEntityToState(DownloadEntity entity) {
    return switch (entity.status) {
      DownloadStatus.initial => const DownloaderInitialState(),
      DownloadStatus.fetching => DownloaderFetchingState(entity: entity),
      DownloadStatus.downloading => DownloaderProgressState(entity: entity),
      DownloadStatus.paused => DownloaderPausedState(entity: entity),
      DownloadStatus.completed => DownloaderCompletedState(entity: entity),
      DownloadStatus.failed => DownloaderFailedState(
        failure: _lastFailure ?? ServerFailure(message: 'Download failed'),
      ),
    };
  }
}
