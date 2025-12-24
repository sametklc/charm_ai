/// Failure classes for handling errors in a functional way
/// Used with Either<Failure, Success> pattern

abstract class Failure {
  final String message;
  final int? code;

  const Failure({required this.message, this.code});

  @override
  String toString() => '$runtimeType: $message';
}

/// Server-related failures
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

/// Network/Connection failures
class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}

/// Cache failures
class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

/// AI Generation failures
class AIGenerationFailure extends Failure {
  final String? modelName;

  const AIGenerationFailure({required super.message, this.modelName});
}

/// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message});
}

