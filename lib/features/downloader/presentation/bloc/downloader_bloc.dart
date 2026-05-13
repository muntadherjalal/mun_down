import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  DownloaderBloc({required DownloaderRepository repository})
      : _repository = repository,
        super(const DownloaderInitialState()) {
    on<StartDownloadEvent>(_onStartDownload);
    on<ResetDownloaderEvent>(_onReset);
  }

  // ────────────────────────────────────────────────────────────
  //  Event handlers
  // ────────────────────────────────────────────────────────────

  Future<void> _onStartDownload(
    StartDownloadEvent event,
    Emitter<DownloaderState> emit,
  ) async {
    // `emit.forEach` automatically subscribes, forwards items, and
    // cancels the subscription if the BLoC is closed mid-download.
    await emit.forEach<DownloadEntity>(
      _repository.startDownload(event.url),
      onData: (entity) => _mapEntityToState(entity),
      onError: (error, _) =>
          DownloaderFailedState(message: error.toString()),
    );
  }

  void _onReset(
    ResetDownloaderEvent event,
    Emitter<DownloaderState> emit,
  ) {
    emit(const DownloaderInitialState());
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
