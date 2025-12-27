import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/creation/presentation/providers/random_character_provider.dart';
import '../../features/creation/presentation/screens/create_character_screen.dart';
import '../../features/discover/presentation/screens/discover_screen.dart';
import '../../features/match/presentation/screens/swipe_screen.dart';
import 'profile_screen.dart';

/// Provider for bottom navigation index
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

/// Main wrapper with bottom navigation bar - Tinder-style layout
class MainWrapper extends ConsumerStatefulWidget {
  const MainWrapper({super.key});

  @override
  ConsumerState<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends ConsumerState<MainWrapper> {
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = const [
      SwipeScreen(),
      DiscoverScreen(),
      CreateCharacterScreen(),
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
    final currentIndex = ref.watch(bottomNavIndexProvider);
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
            icon: const Icon(Icons.casino_rounded),
            tooltip: 'Generate Random Character',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              foregroundColor: AppColors.primary,
            ),
          ),

          // Profile button
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.style_rounded,
                  label: 'Match',
                  isSelected: currentIndex == 0,
                  onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 0,
                ),
                _NavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Discover',
                  isSelected: currentIndex == 1,
                  onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 1,
                ),
                _NavItem(
                  icon: Icons.add_circle_rounded,
                  label: 'Create',
                  isSelected: currentIndex == 2,
                  onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 2,
                  isCreate: true,
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
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isCreate;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isCreate = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isCreate ? AppColors.secondary : AppColors.primary).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? (isCreate ? AppColors.secondary : AppColors.primary)
                  : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiary),
              size: isCreate ? 28 : 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isCreate ? AppColors.secondary : AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
