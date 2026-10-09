import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';

class ProfileState {
  final String userName;
  final String customUsername;
  final String? avatarPath;
  final int daysWithOrbita;
  final bool isDarkMode;
  final bool isAuthenticated;
  final bool isCheckingAuth;

  const ProfileState({
    this.userName = 'Пользователь',
    this.customUsername = 'orbita_user',
    this.avatarPath,
    this.daysWithOrbita = 1,
    this.isDarkMode = false,
    this.isAuthenticated = false,
    this.isCheckingAuth = true,
  });

  ProfileState copyWith({
    String? userName,
    String? customUsername,
    String? avatarPath,
    int? daysWithOrbita,
    bool? isDarkMode,
    bool? isAuthenticated,
    bool? isCheckingAuth,
  }) {
    return ProfileState(
      userName: userName ?? this.userName,
      customUsername: customUsername ?? this.customUsername,
      avatarPath: avatarPath ?? this.avatarPath,
      daysWithOrbita: daysWithOrbita ?? this.daysWithOrbita,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isCheckingAuth: isCheckingAuth ?? this.isCheckingAuth,
    );
  }
}

class ProfileNotifier extends Notifier<ProfileState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  ProfileState build() {
    init();
    return const ProfileState();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;

    final session = _supabase.auth.currentSession;
    final isGuest = prefs.getBool('is_guest_mode') ?? false;
    final isAuth = session != null || isGuest;

    final name = prefs.getString('user_full_name') ?? 'Пользователь';
    final customName = prefs.getString('user_custom_username') ?? 'orbita_user';
    final avatar = prefs.getString('user_avatar_path');

    // Расчет дней с Орбитой
    int? regTimestamp = prefs.getInt('registration_timestamp');
    final currentUser = _supabase.auth.currentUser;
    if (currentUser?.createdAt != null) {
      final parsed = DateTime.tryParse(currentUser!.createdAt);
      if (parsed != null) {
        regTimestamp = parsed.millisecondsSinceEpoch;
        prefs.setInt('registration_timestamp', regTimestamp);
      }
    }

    final now = DateTime.now();
    final cleanNow = DateTime(now.year, now.month, now.day);
    int days = 1;

    if (regTimestamp == null) {
      prefs.setInt('registration_timestamp', now.millisecondsSinceEpoch);
    } else {
      final regDate = DateTime.fromMillisecondsSinceEpoch(regTimestamp);
      final cleanReg = DateTime(regDate.year, regDate.month, regDate.day);
      final diff = cleanNow.difference(cleanReg).inDays;
      days = (diff >= 0 ? diff : 0) + 1;
    }

    state = ProfileState(
      userName: name,
      customUsername: customName,
      avatarPath: avatar,
      daysWithOrbita: days,
      isDarkMode: isDark,
      isAuthenticated: isAuth,
      isCheckingAuth: false,
    );

    if (session != null) {
      SyncService.instance.syncAll();
    }
  }

  Future<void> toggleTheme() async {
    final newMode = !state.isDarkMode;
    state = state.copyWith(isDarkMode: newMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', newMode);
  }

  Future<void> updateProfile({
    required String newName,
    required String newUsername,
    String? newAvatarPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_full_name', newName);
    await prefs.setString('user_custom_username', newUsername);
    if (newAvatarPath != null) {
      await prefs.setString('user_avatar_path', newAvatarPath);
    }

    state = state.copyWith(
      userName: newName,
      customUsername: newUsername,
      avatarPath: newAvatarPath ?? state.avatarPath,
    );
  }

  void markAuthenticated() {
    state = state.copyWith(isAuthenticated: true);
    SyncService.instance.syncAll();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _supabase.auth.signOut();
    await prefs.setBool('is_guest_mode', false);

    try {
      await DatabaseService.instance.clearAllData();
    } catch (_) {}

    state = state.copyWith(isAuthenticated: false);
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(
  ProfileNotifier.new,
);
