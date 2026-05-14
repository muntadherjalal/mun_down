import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/download_history_item.dart';
import '../../domain/repositories/downloads_history_repository.dart';
import '../datasources/downloads_history_local_data_source.dart';
import '../models/download_history_item_model.dart';

class DownloadsHistoryRepositoryImpl implements DownloadsHistoryRepository {
  final DownloadsHistoryLocalDataSource localDataSource;

  DownloadsHistoryRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<DownloadHistoryItem>>> getHistory() async {
    try {
      final localHistory = await localDataSource.getHistory();
      return Right(localHistory);
    } on CacheException {
      return const Left(CacheFailure(message: 'Failed to access SharedPreferences'));
    }
  }

  @override
  Future<Either<Failure, void>> addHistoryItem(DownloadHistoryItem item) async {
    try {
      final model = DownloadHistoryItemModel.fromEntity(item);
      await localDataSource.addHistoryItem(model);
      return const Right(null);
    } on CacheException {
      return const Left(CacheFailure(message: 'Failed to access SharedPreferences'));
    }
  }

  @override
  Future<Either<Failure, void>> clearHistory() async {
    try {
      await localDataSource.clearHistory();
      return const Right(null);
    } on CacheException {
      return const Left(CacheFailure(message: 'Failed to access SharedPreferences'));
    }
  }
}
