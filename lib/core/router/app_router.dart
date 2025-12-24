import 'package:flutter/material.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/characters/domain/entities/character_entity.dart';
import '../../features/characters/presentation/screens/character_selection_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../shared/screens/profile_screen.dart';

/// App route names
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String characters = '/characters';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String settings = '/settings';
}

/// App Router - handles navigation
class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return _buildRoute(const LoginScreen(), settings);

      case AppRoutes.register:
        return _buildRoute(const RegisterScreen(), settings);

      case AppRoutes.forgotPassword:
        return _buildRoute(const ForgotPasswordScreen(), settings);

      case AppRoutes.characters:
        return _buildRoute(const CharacterSelectionScreen(), settings);

      case AppRoutes.chat:
        final character = settings.arguments as CharacterEntity?;
        return _buildRoute(ChatScreen(character: character), settings);

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
