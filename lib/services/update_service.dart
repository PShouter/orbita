import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppReleaseInfo {
  final String versionName;
  final int buildNumber;
  final String apkUrl;
  final String releaseNotes;
  final bool isMandatory;

  AppReleaseInfo({
    required this.versionName,
    required this.buildNumber,
    required this.apkUrl,
    required this.releaseNotes,
    required this.isMandatory,
  });
}

class UpdateService {
  static final UpdateService instance = UpdateService._internal();
  UpdateService._internal();

  /// Проверка наличия свежего релиза в Supabase
  Future<AppReleaseInfo?> checkForUpdate() async {
    // Скачивание и установка через PackageInstaller поддерживаются только на Android
    if (!Platform.isAndroid) return null;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      final response = await Supabase.instance.client
          .from('app_releases')
          .select()
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final serverBuild = (response['build_number'] as num?)?.toInt() ?? 0;
      final serverVersion = response['version_name'] as String? ?? '';
      final apkUrl = response['apk_url'] as String? ?? '';
      final notes =
          response['release_notes'] as String? ??
          'Улучшения стабильности и исправления ошибок.';
      final isMandatory = (response['is_mandatory'] as bool?) ?? false;

      // Если номер билда на сервере больше текущего билда приложения
      if (serverBuild > currentBuild && apkUrl.isNotEmpty) {
        return AppReleaseInfo(
          versionName: serverVersion,
          buildNumber: serverBuild,
          apkUrl: apkUrl,
          releaseNotes: notes,
          isMandatory: isMandatory,
        );
      }
    } catch (e) {
      debugPrint('Ошибка проверки обновлений: $e');
    }
    return null;
  }

  /// Запуск скачивания и передачи в системный установщик
  Stream<OtaEvent> downloadAndInstall({required String apkUrl}) {
    return OtaUpdate().execute(
      apkUrl,
      destinationFilename: 'orbita_update.apk',
    );
  }
}
