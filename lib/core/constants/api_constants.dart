/// API Constants - Configure your backend URLs here
class ApiConstants {
  ApiConstants._();

  /// Base URL for the backend server (Render)
  /// Update this with your actual Render deployment URL
  static const String baseUrl = 'https://your-render-app.onrender.com';

  /// Development base URL (for local testing)
  static const String devBaseUrl = 'http://localhost:8000';

  /// API Endpoints
  static const String healthCheck = '/health';
  
  // Chat endpoints
  static const String chat = '/api/chat';
  static const String chatStream = '/api/chat/stream';
  
  // Media generation endpoints
  static const String generateImage = '/api/generate/image';
  static const String generateImageAsync = '/api/generate/image/async';
  static const String generationStatus = '/api/generate/status';
  static const String availableModels = '/api/generate/models';

  /// Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 120); // Longer for image gen
  static const Duration imageGenerationTimeout = Duration(minutes: 5);
}
