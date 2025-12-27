/// Custom Exceptions for the application

/// Thrown when there's a server-side error
class ServerException implements Exception {
  final String message;
  final int? statusCode;

  ServerException({required this.message, this.statusCode});

  @override
  String toString() => 'ServerException: $message (Status: $statusCode)';
}

/// Thrown when there's a network/connection error
class NetworkException implements Exception {
  final String message;

  NetworkException({required this.message});

  @override
  String toString() => 'NetworkException: $message';
}

/// Thrown when there's a cache error
class CacheException implements Exception {
  final String message;

  CacheException({required this.message});

  @override
  String toString() => 'CacheException: $message';
}

/// Thrown when authentication fails
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException({required this.message, this.code});

  @override
  String toString() => 'AuthException: $message (Code: $code)';
}

/// Thrown when AI generation fails
class AIGenerationException implements Exception {
  final String message;
  final String? modelName;

  AIGenerationException({required this.message, this.modelName});

  @override
  String toString() => 'AIGenerationException: $message (Model: $modelName)';
}



