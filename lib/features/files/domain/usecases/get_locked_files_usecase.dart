import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/files_repository.dart';

class GetLockedFilesUseCase {
  final FilesRepository repository;

  GetLockedFilesUseCase(this.repository);

  Future<Either<Failure, Set<String>>> call() async {
    return await repository.getLockedFiles();
  }
}
