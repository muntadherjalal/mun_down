part of 'downloads_history_bloc.dart';

abstract class DownloadsHistoryState extends Equatable {
  const DownloadsHistoryState();
  
  @override
  List<Object?> get props => [];
}

class HistoryInitial extends DownloadsHistoryState {}

class HistoryLoading extends DownloadsHistoryState {}

class HistoryLoaded extends DownloadsHistoryState {
  final List<DownloadHistoryItem> history;

  const HistoryLoaded(this.history);

  @override
  List<Object?> get props => [history];
}

class HistoryError extends DownloadsHistoryState {
  final String message;

  const HistoryError(this.message);

  @override
  List<Object?> get props => [message];
}
