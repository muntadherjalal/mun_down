import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/downloads_history_repository.dart';

class ClearDownloadsHistoryUseCase {
  final DownloadsHistoryRepository repository;

  ClearDownloadsHistoryUseCase(this.repository);

  Future<Either<Failure, void>> call() async {
    return await repository.clearHistory();
  }
}
