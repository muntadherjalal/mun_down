import 'package:equatable/equatable.dart';

/// Base failure class for the application.
///
/// All domain-level failures should extend this class
/// so they can be compared with [Equatable].
abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

/// Returned when a server/API call fails.
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.statusCode});
}

/// Returned when local storage (Isar / cache) operations fail.
class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

/// Returned when the device has no internet connection.
class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection'});
}

/// Returned when input validation fails.
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message});
}

/// Returned when there is not enough storage space.
class StorageFailure extends Failure {
  const StorageFailure({required super.message});
}

/// Returned when the app lacks necessary permissions.
class PermissionFailure extends Failure {
  const PermissionFailure({required super.message});
}

/// Returned when a request times out.
class TimeoutFailure extends Failure {
  const TimeoutFailure({required super.message});
}

/// Returned when the file format is unsupported or corrupted.
class FormatFailure extends Failure {
  const FormatFailure({required super.message});
}
