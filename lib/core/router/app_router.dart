import 'package:flutter/material.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/characters/domain/entities/character_entity.dart';
import '../../features/chat/presentation/screens/chat_history_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/creation/presentation/screens/character_creator_screen.dart';
import '../../features/discover/presentation/screens/discover_screen.dart';
import '../../features/onboarding/presentation/screens/initial_match_screen.dart';
import '../../shared/screens/main_dashboard.dart';
import '../../shared/screens/profile_screen.dart';

/// App route names
class AppRoutes {
  AppRoutes._();

  static const String main = '/main';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String discover = '/discover';
  static const String chats = '/chats';
  static const String chat = '/chat';
  static const String create = '/create';
  static const String profile = '/profile';
}

/// App Router - handles navigation
class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.main:
        return _buildRoute(const MainDashboard(), settings);

      case AppRoutes.onboarding:
        return _buildRoute(const InitialMatchScreen(), settings);

      case AppRoutes.login:
        return _buildRoute(const LoginScreen(), settings);

      case AppRoutes.register:
        return _buildRoute(const RegisterScreen(), settings);

      case AppRoutes.forgotPassword:
        return _buildRoute(const ForgotPasswordScreen(), settings);

      case AppRoutes.discover:
        return _buildRoute(const DiscoverScreen(), settings);

      case AppRoutes.chats:
        return _buildRoute(const ChatHistoryScreen(), settings);

      case AppRoutes.chat:
        // Support both Map (with conversationId) and direct CharacterEntity arguments
        CharacterEntity? character;
        String? conversationId;
        
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          character = args['character'] as CharacterEntity?;
          conversationId = args['conversationId'] as String?;
        } else if (settings.arguments is CharacterEntity) {
          character = settings.arguments as CharacterEntity?;
        }
        
        return _buildRoute(ChatScreen(character: character, conversationId: conversationId), settings);

      case AppRoutes.create:
        return _buildRoute(const CharacterCreatorScreen(), settings);

      case AppRoutes.profile:
        return _buildRoute(const ProfileScreen(), settings);

      default:
        return _buildRoute(
          Scaffold(
            body: Center(
              child: Text('Route not found: ${settings.name}'),
            ),
          ),
          settings,
        );
    }
  }

  static MaterialPageRoute _buildRoute(Widget page, RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => page,
      settings: settings,
    );
  }
}
