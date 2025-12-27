import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/creation/presentation/providers/random_character_provider.dart';
import '../../features/chat/presentation/screens/chat_history_screen.dart';
import '../../features/creation/presentation/screens/character_creator_screen.dart';
import '../../features/discover/presentation/screens/discover_screen.dart';
import 'profile_screen.dart';

/// Provider for dashboard tab index
final dashboardTabIndexProvider = StateProvider<int>((ref) => 0);

/// Main Dashboard with Bottom Navigation (Discover | Chat | Create)
class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({super.key});

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = const [
      DiscoverScreen(),
      ChatHistoryScreen(),
      CharacterCreatorScreen(),
    ];
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _generateRandomCharacter(BuildContext context) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first')),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final service = ref.read(randomCharacterServiceProvider);
      final result = await service.generateRandomCharacter(userId: user.uid);

      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      result.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to generate character: ${failure.message ?? 'Unknown error'}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (character) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Character Created: ${character.name} ✨'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      );
    } catch (e) {
      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(dashboardTabIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        title: Row(
          children: [
            // Logo
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.favorite,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Charm AI',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          // Random character generator button
          IconButton(
            onPressed: () => _generateRandomCharacter(context),
            icon: const Icon(Icons.casino_rounded, size: 24),
            tooltip: 'Generate Random Character',
            color: AppColors.primary,
          ),

          // Profile button (Top-Right)
          GestureDetector(
            onTap: _openProfile,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: user?.photoUrl != null
                    ? CachedNetworkImageProvider(user!.photoUrl!)
                    : null,
                child: user?.photoUrl == null
                    ? Text(
                        user?.initials ?? '?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Discover Tab
                _NavItem(
                  icon: Icons.explore_rounded,
                  activeIcon: Icons.explore,
                  label: 'Discover',
                  isSelected: currentIndex == 0,
                  onTap: () => ref.read(dashboardTabIndexProvider.notifier).state = 0,
                ),
                // Chat Tab (Center - highlighted)
                _NavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  label: 'Chats',
                  isSelected: currentIndex == 1,
                  onTap: () => ref.read(dashboardTabIndexProvider.notifier).state = 1,
                  isCenter: true,
                ),
                // Create Tab
                _NavItem(
                  icon: Icons.add_circle_outline_rounded,
                  activeIcon: Icons.add_circle_rounded,
                  label: 'Create',
                  isSelected: currentIndex == 2,
                  onTap: () => ref.read(dashboardTabIndexProvider.notifier).state = 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom navigation item
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isCenter;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: isCenter && isSelected
                  ? const EdgeInsets.all(8)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: isCenter && isSelected
                    ? AppColors.primary
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected
                    ? (isCenter ? Colors.white : AppColors.primary)
                    : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiary),
                size: isCenter ? 28 : 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiary),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



