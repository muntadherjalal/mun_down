import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/network_info.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/repositories/downloader_repository.dart';

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

  DownloaderBloc({
    required DownloaderRepository repository,
    required NetworkInfo networkInfo,
  })  : _repository = repository,
        _networkInfo = networkInfo,
        super(const DownloaderInitialState()) {
    on<StartDownloadEvent>(_onStartDownload);
    on<ResetDownloaderEvent>(_onReset);
    on<NetworkDroppedEvent>(_onNetworkDropped);

    _networkSubscription = _networkInfo.onConnectivityChanged.listen((results) {
      if (!results.any((r) => r != ConnectivityResult.none)) {
        add(const NetworkDroppedEvent());
      }
    });
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
    final hasConnection = await _networkInfo.isConnected;
    if (!hasConnection) {
      emit(const DownloaderFailedState(message: 'No internet connection'));
      return;
    }

    _cancelToken = CancelToken();

    // `emit.forEach` automatically subscribes, forwards items, and
    // cancels the subscription if the BLoC is closed mid-download.
    await emit.forEach<DownloadEntity>(
      _repository.startDownload(
        event.url,
        title: event.title,
        cancelToken: _cancelToken,
      ),
      onData: (entity) => _mapEntityToState(entity),
      onError: (error, _) =>
          DownloaderFailedState(message: error.toString()),
    );
  }

  void _onReset(
    ResetDownloaderEvent event,
    Emitter<DownloaderState> emit,
  ) {
    _cancelToken?.cancel();
    _cancelToken = null;
    emit(const DownloaderInitialState());
  }

  void _onNetworkDropped(
    NetworkDroppedEvent event,
    Emitter<DownloaderState> emit,
  ) {
    if (state is DownloaderProgressState || state is DownloaderFetchingState) {
      emit(const DownloaderFailedState(
          message: 'Internet connection lost. Download paused.'));
    }
  }

  // ────────────────────────────────────────────────────────────
  //  Mapping helpers
  // ────────────────────────────────────────────────────────────

  DownloaderState _mapEntityToState(DownloadEntity entity) {
    return switch (entity.status) {
      DownloadStatus.initial   => const DownloaderInitialState(),
      DownloadStatus.fetching  => DownloaderFetchingState(entity: entity),
      DownloadStatus.downloading => DownloaderProgressState(entity: entity),
      DownloadStatus.completed => DownloaderCompletedState(entity: entity),
      DownloadStatus.failed    => const DownloaderFailedState(message: 'Download failed'),
    };
  }
}
