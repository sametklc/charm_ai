import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/settings_provider.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/onboarding/presentation/screens/initial_match_screen.dart';
import 'shared/screens/main_dashboard.dart';

/// Provider to check if user has completed onboarding
/// Checks both SharedPreferences and Firestore (if user has conversations, onboarding is done)
final hasCompletedOnboardingProvider = FutureProvider<bool>((ref) async {
  print('🔵 OnboardingProvider: Checking onboarding status');
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    print('🔵 OnboardingProvider: User is null, onboarding not completed');
    return false;
  }

  print('🔵 OnboardingProvider: User found: ${user.uid}');

  // First check SharedPreferences
  print('🔵 OnboardingProvider: Checking SharedPreferences for hasCompletedOnboarding');
  final prefs = await SharedPreferences.getInstance();
  final prefsValue = prefs.getBool('hasCompletedOnboarding');
  
  if (prefsValue == true) {
    print('✅ OnboardingProvider: SharedPreferences says onboarding is completed');
    return true;
  }

  // If not in prefs, check Firestore - if user has any conversations, onboarding is done
  print('🔵 OnboardingProvider: SharedPreferences not found, checking Firestore conversations...');
  try {
    final firestore = ref.watch(firestoreProvider);
    
    // Add timeout to prevent hanging (3 seconds max - reduced from 5)
    final conversationsSnapshot = await firestore
        .collection('conversations')
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get()
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            print('⚠️ OnboardingProvider: Firestore query timed out after 3 seconds');
            throw TimeoutException('Firestore query timeout', const Duration(seconds: 3));
          },
        );

    final hasConversations = conversationsSnapshot.docs.isNotEmpty;
    print('✅ OnboardingProvider: Firestore check complete. hasConversations: $hasConversations');
    
    // If user has conversations, mark onboarding as completed in prefs
    if (hasConversations && prefsValue != true) {
      print('🔵 OnboardingProvider: Updating SharedPreferences to true');
      await prefs.setBool('hasCompletedOnboarding', true);
    }
    
    return hasConversations;
  } on TimeoutException catch (e) {
    // Timeout - assume existing user to prevent infinite loading
    print('⚠️ OnboardingProvider: Timeout - assuming existing user, skipping onboarding');
    return true;
  } catch (e) {
    // If Firestore check fails, check if user might be existing
    // For existing users, if prefs is null/false but they're logged in, assume they completed onboarding
    print('❌ OnboardingProvider: Error checking onboarding status: $e');
    
    // If prefs explicitly says false, show onboarding
    if (prefsValue == false) {
      print('🔵 OnboardingProvider: Prefs says false, showing onboarding');
      return false;
    }
    
    // Otherwise, assume existing user (they're logged in, so they probably completed onboarding before)
    // This prevents infinite loading for existing users
    print('⚠️ OnboardingProvider: Assuming existing user, skipping onboarding');
    return true;
  }
});

/// Set onboarding as completed
Future<void> setOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('hasCompletedOnboarding', true);
}

class CharmApp extends ConsumerWidget {
  const CharmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp(
      title: 'Charm AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const AuthWrapper(),
    );
  }
}

/// Wrapper that handles auth state and navigation
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        print('🔵 AuthWrapper: Data state. User: ${user?.uid ?? "NULL"}');
        if (user != null) {
          // Check if user has completed onboarding (swipe-first flow)
          print('🔵 AuthWrapper: Navigating to OnboardingChecker');
          return const OnboardingChecker();
        }
        print('🔵 AuthWrapper: Navigating to LoginScreen');
        return const LoginScreen();
      },
      loading: () {
        print('🔵 AuthWrapper: Loading state');
        return const _SplashScreen();
      },
      error: (error, stack) {
        print('❌ AuthWrapper: Error state: $error');
        return const LoginScreen();
      },
    );
  }
}

/// Check onboarding status and navigate accordingly
class OnboardingChecker extends ConsumerWidget {
  const OnboardingChecker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingState = ref.watch(hasCompletedOnboardingProvider);

    return onboardingState.when(
      data: (hasCompleted) {
        print('🔵 OnboardingChecker: Data state. hasCompleted: $hasCompleted');
        if (hasCompleted) {
          // User has completed onboarding, go to MainDashboard
          print('🔵 OnboardingChecker: Navigating to MainDashboard');
          return const MainDashboard();
        }
        // New user, show InitialMatchScreen (Swipe-First)
        print('🔵 OnboardingChecker: Navigating to InitialMatchScreen');
        return const InitialMatchScreen();
      },
      loading: () {
        print('🔵 OnboardingChecker: Loading state');
        return const _SplashScreen();
      },
      error: (error, stack) {
        // On error, try to show login instead of a broken dashboard
        print('❌ OnboardingChecker: Error state: $error');
        print('⚠️ OnboardingChecker: Navigating to LoginScreen due to check failure');
        return const LoginScreen();
      },
    );
  }
}

/// Splash Screen shown during initial auth check
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with heart
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite,
                color: Colors.white,
                size: 50,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Charm AI',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find your perfect companion',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 40),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
