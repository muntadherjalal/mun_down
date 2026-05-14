import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/download_history_item.dart';
import '../repositories/downloads_history_repository.dart';

class GetDownloadsHistoryUseCase {
  final DownloadsHistoryRepository repository;

  GetDownloadsHistoryUseCase(this.repository);

  Future<Either<Failure, List<DownloadHistoryItem>>> call() async {
    return await repository.getHistory();
  }
}
