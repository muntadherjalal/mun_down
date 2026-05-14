import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/download_history_item.dart';

abstract class DownloadsHistoryRepository {
  Future<Either<Failure, List<DownloadHistoryItem>>> getHistory();
  Future<Either<Failure, void>> addHistoryItem(DownloadHistoryItem item);
  Future<Either<Failure, void>> clearHistory();
}
