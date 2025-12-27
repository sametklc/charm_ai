import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for SharedPreferences
class SettingsKeys {
  static const String themeMode = 'theme_mode';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String chatNotifications = 'chat_notifications';
  static const String matchNotifications = 'match_notifications';
}

/// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString(SettingsKeys.themeMode) ?? 'system';
    state = _themeModeFromString(themeModeString);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SettingsKeys.themeMode, _themeModeToString(mode));
  }

  ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

/// Notification settings state
class NotificationSettings {
  final bool enabled;
  final bool chatNotifications;
  final bool matchNotifications;

  const NotificationSettings({
    this.enabled = true,
    this.chatNotifications = true,
    this.matchNotifications = true,
  });

  NotificationSettings copyWith({
    bool? enabled,
    bool? chatNotifications,
    bool? matchNotifications,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      chatNotifications: chatNotifications ?? this.chatNotifications,
      matchNotifications: matchNotifications ?? this.matchNotifications,
    );
  }
}

/// Notification settings provider
final notificationSettingsProvider = StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>((ref) {
  return NotificationSettingsNotifier();
});

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(const NotificationSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettings(
      enabled: prefs.getBool(SettingsKeys.notificationsEnabled) ?? true,
      chatNotifications: prefs.getBool(SettingsKeys.chatNotifications) ?? true,
      matchNotifications: prefs.getBool(SettingsKeys.matchNotifications) ?? true,
    );
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.notificationsEnabled, value);
  }

  Future<void> setChatNotifications(bool value) async {
    state = state.copyWith(chatNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.chatNotifications, value);
  }

  Future<void> setMatchNotifications(bool value) async {
    state = state.copyWith(matchNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.matchNotifications, value);
  }
}


