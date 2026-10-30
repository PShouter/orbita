import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  static const String _kOnboardingCompletedKey =
      'permissions_onboarding_completed_v1';

  /// Проверка: проходил ли пользователь онбординг разрешений
  static Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kOnboardingCompletedKey) ?? false);
  }

  /// Завершить онбординг (запомнить, чтобы не показывать снова)
  static Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompletedKey, true);
  }

  /// Запрос уведомлений (Android 13+)
  static Future<bool> requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Запрос точных будильников (Android 12+)
  static Future<bool> requestExactAlarms() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.scheduleExactAlarm.request();
    return status.isGranted;
  }

  /// Запрос доступа к фото / медиатеке
  static Future<bool> requestPhotos() async {
    if (Platform.isAndroid) {
      final status = await Permission.photos.request();
      if (status.isGranted) return true;
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  /// Запрос отключения оптимизации батареи (системное диалоговое окно Android)
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final isIgnored = await Permission.ignoreBatteryOptimizations.isGranted;
      if (!isIgnored) {
        final status = await Permission.ignoreBatteryOptimizations.request();
        return status.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('Ошибка запроса оптимизации батареи: $e');
      return false;
    }
  }
}
