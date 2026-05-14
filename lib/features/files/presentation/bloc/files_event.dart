import 'package:equatable/equatable.dart';

abstract class FilesEvent extends Equatable {
  const FilesEvent();

  @override
  List<Object> get props => [];
}

class LoadLockedFilesEvent extends FilesEvent {}

class ToggleFileLockEvent extends FilesEvent {
  final String filePath;

  const ToggleFileLockEvent(this.filePath);

  @override
  List<Object> get props => [filePath];
}
