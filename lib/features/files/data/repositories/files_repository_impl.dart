import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/repositories/files_repository.dart';
import '../datasources/files_local_data_source.dart';

class FilesRepositoryImpl implements FilesRepository {
  final FilesLocalDataSource localDataSource;

  FilesRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, Set<String>>> getLockedFiles() async {
    try {
      final lockedFiles = await localDataSource.getLockedFiles();
      return Right(lockedFiles);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleFileLock(String filePath) async {
    try {
      await localDataSource.toggleFileLock(filePath);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }
}
