import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/files_repository.dart';

class ToggleFileLockUseCase {
  final FilesRepository repository;

  ToggleFileLockUseCase(this.repository);

  Future<Either<Failure, void>> call(String filePath) async {
    return await repository.toggleFileLock(filePath);
  }
}
