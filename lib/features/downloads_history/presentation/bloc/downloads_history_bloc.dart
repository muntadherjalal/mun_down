import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/download_history_item.dart';
import '../../domain/usecases/add_download_history_item.dart';
import '../../domain/usecases/clear_downloads_history.dart';
import '../../domain/usecases/get_downloads_history.dart';

part 'downloads_history_event.dart';
part 'downloads_history_state.dart';

class DownloadsHistoryBloc extends Bloc<DownloadsHistoryEvent, DownloadsHistoryState> {
  final GetDownloadsHistoryUseCase getHistoryUseCase;
  final AddDownloadHistoryUseCase addHistoryUseCase;
  final ClearDownloadsHistoryUseCase clearHistoryUseCase;

  DownloadsHistoryBloc({
    required this.getHistoryUseCase,
    required this.addHistoryUseCase,
    required this.clearHistoryUseCase,
  }) : super(HistoryInitial()) {
    on<LoadHistoryEvent>(_onLoadHistory);
    on<AddToHistoryEvent>(_onAddToHistory);
    on<ClearHistoryEvent>(_onClearHistory);
  }

  Future<void> _onLoadHistory(
    LoadHistoryEvent event,
    Emitter<DownloadsHistoryState> emit,
  ) async {
    emit(HistoryLoading());
    final failureOrHistory = await getHistoryUseCase();
    failureOrHistory.fold(
      (failure) => emit(const HistoryError('Failed to load history')),
      (history) => emit(HistoryLoaded(history)),
    );
  }

  Future<void> _onAddToHistory(
    AddToHistoryEvent event,
    Emitter<DownloadsHistoryState> emit,
  ) async {
    final failureOrSuccess = await addHistoryUseCase(event.item);
    failureOrSuccess.fold(
      (failure) => emit(const HistoryError('Failed to add to history')),
      (_) {
        // Reload history after adding
        add(LoadHistoryEvent());
      },
    );
  }

  Future<void> _onClearHistory(
    ClearHistoryEvent event,
    Emitter<DownloadsHistoryState> emit,
  ) async {
    final failureOrSuccess = await clearHistoryUseCase();
    failureOrSuccess.fold(
      (failure) => emit(const HistoryError('Failed to clear history')),
      (_) => emit(const HistoryLoaded([])),
    );
  }
}
