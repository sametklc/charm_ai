/// App-wide constants
class AppConstants {
  AppConstants._();

  /// App Information
  static const String appName = 'Charm AI';
  static const String appVersion = '1.0.0';

  /// Chat Configuration
  static const int maxChatHistoryLength = 50;
  static const int maxMessageLength = 4000;

  /// Media Generation Configuration
  static const int maxImageWidth = 1024;
  static const int maxImageHeight = 1024;
  static const List<String> supportedImageFormats = ['png', 'jpg', 'webp'];

  /// Firebase Collections
  static const String usersCollection = 'users';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';
  static const String mediaCollection = 'generated_media';
}

