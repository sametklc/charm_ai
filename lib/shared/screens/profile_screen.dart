import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/settings_provider.dart';
import '../../features/chat/presentation/providers/chat_controller.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';

/// Profile screen with user info and settings
class ProfileScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  
  const ProfileScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  
  void _showEditProfileDialog() {
    final user = ref.read(currentUserProvider);
    final nameController = TextEditingController(text: user?.displayName ?? '');
    XFile? selectedImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.surfaceDark
                : AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Avatar section
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.primary,
                        backgroundImage: selectedImage != null
                            ? FileImage(File(selectedImage!.path))
                            : (user?.photoUrl != null
                                ? NetworkImage(user!.photoUrl!)
                                : null),
                        child: selectedImage == null && user?.photoUrl == null
                            ? Text(
                                user?.initials ?? '?',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final image = await picker.pickImage(source: ImageSource.gallery);

                            if (image != null) {
                              setState(() {
                                selectedImage = image;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Name field
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'Enter your name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final newName = nameController.text.trim();
                      if (newName.isNotEmpty || selectedImage != null) {
                        final success = await ref.read(authControllerProvider.notifier).updateProfile(
                          displayName: newName.isNotEmpty ? newName : null,
                          photoFile: selectedImage,
                        );
                        if (success && mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile updated successfully')),
                          );
                        } else if (!success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to update profile'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _showNotificationsSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final settings = ref.watch(notificationSettingsProvider);
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // All notifications toggle
                  SwitchListTile(
                    title: const Text('Enable Notifications'),
                    subtitle: const Text('Receive all app notifications'),
                    value: settings.enabled,
                    onChanged: (value) {
                      ref.read(notificationSettingsProvider.notifier).setEnabled(value);
                    },
                    activeColor: AppColors.primary,
                  ),
                  const Divider(),
                  
                  // Chat notifications
                  SwitchListTile(
                    title: const Text('Chat Messages'),
                    subtitle: const Text('New message notifications'),
                    value: settings.chatNotifications && settings.enabled,
                    onChanged: settings.enabled 
                        ? (value) {
                            ref.read(notificationSettingsProvider.notifier).setChatNotifications(value);
                          }
                        : null,
                    activeColor: AppColors.primary,
                  ),
                  
                  // Match notifications
                  SwitchListTile(
                    title: const Text('New Matches'),
                    subtitle: const Text('When you match with someone'),
                    value: settings.matchNotifications && settings.enabled,
                    onChanged: settings.enabled 
                        ? (value) {
                            ref.read(notificationSettingsProvider.notifier).setMatchNotifications(value);
                          }
                        : null,
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAppearanceSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final themeMode = ref.watch(themeModeProvider);
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    'Appearance',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Theme options
                  _buildThemeOption(
                    context,
                    ref,
                    icon: Icons.phone_android,
                    title: 'System Default',
                    subtitle: 'Follow device settings',
                    mode: ThemeMode.system,
                    currentMode: themeMode,
                  ),
                  _buildThemeOption(
                    context,
                    ref,
                    icon: Icons.light_mode,
                    title: 'Light Mode',
                    subtitle: 'Always use light theme',
                    mode: ThemeMode.light,
                    currentMode: themeMode,
                  ),
                  _buildThemeOption(
                    context,
                    ref,
                    icon: Icons.dark_mode,
                    title: 'Dark Mode',
                    subtitle: 'Always use dark theme',
                    mode: ThemeMode.dark,
                    currentMode: themeMode,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeMode mode,
    required ThemeMode currentMode,
  }) {
    final isSelected = mode == currentMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
        Navigator.pop(context);
      },
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected 
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : null,
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        automaticallyImplyLeading: !widget.isEmbedded,
        leading: widget.isEmbedded ? null : IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary,
              backgroundImage: user?.photoUrl != null 
                  ? NetworkImage(user!.photoUrl!) 
                  : null,
              child: user?.photoUrl == null
                  ? Text(
                      user?.initials ?? '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 20),

            // Name
            Text(
              user?.displayNameOrEmail ?? 'User',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Email
            Text(
              user?.email ?? '',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 40),

            // Settings Section
            _buildSection(
              context,
              isDark,
              title: 'Settings',
              children: [
                _buildSettingsTile(
                  context,
                  icon: Icons.person_outline,
                  title: 'Edit Profile',
                  onTap: _showEditProfileDialog,
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: _showNotificationsSettings,
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: _getThemeModeText(themeMode),
                  onTap: _showAppearanceSettings,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // About Section
            _buildSection(
              context,
              isDark,
              title: 'About',
              children: [
                _buildSettingsTile(
                  context,
                  icon: Icons.info_outline,
                  title: 'About Charm AI',
                  onTap: () => _showAboutDialog(context),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () => _showComingSoon(context, 'Terms of Service'),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () => _showComingSoon(context, 'Privacy Policy'),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  print('🔵 ProfileScreen: Sign out initiated');
                  // 1. Clear chat state
                  ref.read(chatControllerProvider.notifier).resetConversation();
                  
                  // 2. Sign out from Firebase
                  final success = await ref.read(authControllerProvider.notifier).signOut();
                  
                  if (success && context.mounted) {
                    print('✅ ProfileScreen: Sign out complete - navigating to login');
                    // Navigate to root - AuthWrapper will show LoginScreen
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  } else {
                    print('❌ ProfileScreen: Sign out failed');
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // App Version
            Text(
              'Charm AI v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Charm AI',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
      ),
      children: [
        const Text(
          'Charm AI is an AI-powered companion app that lets you chat with unique AI characters and generate custom media.',
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature - Coming soon!')),
    );
  }

  Widget _buildSection(
    BuildContext context,
    bool isDark, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                fontSize: 13,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
      ),
    );
  }
}
