import 'package:equatable/equatable.dart';

sealed class FilesState extends Equatable {
  const FilesState();
  
  @override
  List<Object> get props => [];
}

class FilesInitial extends FilesState {}

class FilesLoading extends FilesState {}

class FilesLoaded extends FilesState {
  final Set<String> lockedFiles;

  const FilesLoaded(this.lockedFiles);

  @override
  List<Object> get props => [lockedFiles];
}

class FilesError extends FilesState {
  final String message;

  const FilesError(this.message);

  @override
  List<Object> get props => [message];
}
