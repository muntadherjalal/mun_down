part of 'downloads_history_bloc.dart';

abstract class DownloadsHistoryEvent extends Equatable {
  const DownloadsHistoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadHistoryEvent extends DownloadsHistoryEvent {}

class AddToHistoryEvent extends DownloadsHistoryEvent {
  final DownloadHistoryItem item;

  const AddToHistoryEvent(this.item);

  @override
  List<Object?> get props => [item];
}

class ClearHistoryEvent extends DownloadsHistoryEvent {}
