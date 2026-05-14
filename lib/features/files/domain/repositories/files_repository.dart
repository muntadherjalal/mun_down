import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

abstract class FilesRepository {
  Future<Either<Failure, Set<String>>> getLockedFiles();
  Future<Either<Failure, void>> toggleFileLock(String filePath);
}
