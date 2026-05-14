import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_locked_files_usecase.dart';
import '../../domain/usecases/toggle_file_lock_usecase.dart';
import 'files_event.dart';
import 'files_state.dart';

class FilesBloc extends Bloc<FilesEvent, FilesState> {
  final GetLockedFilesUseCase getLockedFiles;
  final ToggleFileLockUseCase toggleFileLock;

  FilesBloc({
    required this.getLockedFiles,
    required this.toggleFileLock,
  }) : super(FilesInitial()) {
    on<LoadLockedFilesEvent>(_onLoadLockedFiles);
    on<ToggleFileLockEvent>(_onToggleFileLock);
  }

  Future<void> _onLoadLockedFiles(
    LoadLockedFilesEvent event,
    Emitter<FilesState> emit,
  ) async {
    emit(FilesLoading());
    final result = await getLockedFiles();
    result.fold(
      (failure) => emit(FilesError(failure.message)),
      (lockedFiles) => emit(FilesLoaded(lockedFiles)),
    );
  }

  Future<void> _onToggleFileLock(
    ToggleFileLockEvent event,
    Emitter<FilesState> emit,
  ) async {
    // Optimistic UI update if we are already loaded
    Set<String> currentFiles = {};
    if (state is FilesLoaded) {
      currentFiles = Set.from((state as FilesLoaded).lockedFiles);
      if (currentFiles.contains(event.filePath)) {
        currentFiles.remove(event.filePath);
      } else {
        currentFiles.add(event.filePath);
      }
      emit(FilesLoaded(currentFiles));
    } else {
      emit(FilesLoading());
    }

    final result = await toggleFileLock(event.filePath);
    result.fold(
      (failure) => emit(FilesError(failure.message)),
      (_) async {
        // If we didn't do optimistic update, we fetch again
        if (state is! FilesLoaded) {
          final fetchResult = await getLockedFiles();
          fetchResult.fold(
            (failure) => emit(FilesError(failure.message)),
            (lockedFiles) => emit(FilesLoaded(lockedFiles)),
          );
        }
      },
    );
  }
}
