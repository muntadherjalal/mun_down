import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/download_history_item.dart';
import '../repositories/downloads_history_repository.dart';

class AddDownloadHistoryUseCase {
  final DownloadsHistoryRepository repository;

  AddDownloadHistoryUseCase(this.repository);

  Future<Either<Failure, void>> call(DownloadHistoryItem item) async {
    return await repository.addHistoryItem(item);
  }
}
