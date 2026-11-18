import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/vault_service.dart';

class VaultState {
  final bool hasPin;
  final bool isUnlocked;
  final String? activePin;
  final List<Map<String, dynamic>> documents;
  final String? errorMessage;
  final bool canCheckBiometrics;

  VaultState({
    required this.hasPin,
    required this.isUnlocked,
    this.activePin,
    required this.documents,
    this.errorMessage,
    this.canCheckBiometrics = false,
  });

  VaultState copyWith({
    bool? hasPin,
    bool? isUnlocked,
    String? activePin,
    List<Map<String, dynamic>>? documents,
    String? errorMessage,
    bool? canCheckBiometrics,
  }) {
    return VaultState(
      hasPin: hasPin ?? this.hasPin,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      activePin: activePin ?? this.activePin,
      documents: documents ?? this.documents,
      errorMessage: errorMessage,
      canCheckBiometrics: canCheckBiometrics ?? this.canCheckBiometrics,
    );
  }
}

class VaultNotifier extends Notifier<VaultState> {
  final _service = VaultService.instance;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  VaultState build() {
    _initStatus();
    return VaultState(hasPin: false, isUnlocked: false, documents: []);
  }

  Future<void> _initStatus() async {
    final hasPin = await _service.hasPin();
    bool canBio = false;
    try {
      final canAuth = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      canBio = canAuth || isDeviceSupported;
    } catch (_) {}

    state = state.copyWith(hasPin: hasPin, canCheckBiometrics: canBio);
  }

  Future<void> setupPin(String pin) async {
    await _service.setPin(pin);
    state = state.copyWith(
      hasPin: true,
      isUnlocked: true,
      activePin: pin,
      documents: [],
    );
  }

  /// Безопасная смена PIN: расшифровывает существующие записи старым PIN
  /// и перешифровывает их новым PIN
  Future<bool> changePin(String oldPin, String newPin) async {
    final isOldValid = await _service.verifyPin(oldPin);
    if (!isOldValid) {
      state = state.copyWith(errorMessage: 'Текущий PIN указан неверно');
      return false;
    }

    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.query('vault_documents');

      // Перешифровываем все документы новым PIN-кодом в одной транзакции,
      // чтобы при сбое не остался частично перешифрованный сейф
      await db.transaction((txn) async {
        for (final row in rows) {
          final id = row['id'] as String;
          final encTitle = row['encrypted_title'] as String;
          final encPayload = row['encrypted_payload'] as String;
          final iv = row['iv'] as String;

          final title = _service.decryptString(encTitle, iv, oldPin);
          String payload = '';
          if (encPayload.contains(':::')) {
            final parts = encPayload.split(':::');
            payload = _service.decryptString(parts[0], parts[1], oldPin);
          } else {
            payload = _service.decryptString(encPayload, iv, oldPin);
          }

          final newEncTitle = _service.encryptString(title, newPin);
          final newEncPayload = _service.encryptString(payload, newPin);
          final combinedPayload =
              '${newEncPayload['cipherText']!}:::${newEncPayload['iv']!}';

          await txn.update(
            'vault_documents',
            {
              'encrypted_title': newEncTitle['cipherText']!,
              'encrypted_payload': combinedPayload,
              'iv': newEncTitle['iv']!,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      });

      await _service.setPin(newPin);
      state = state.copyWith(activePin: newPin, errorMessage: null);
      await loadDocuments();
      return true;
    } catch (e) {
      debugPrint('Ошибка при смене PIN сейфа: $e');
      state = state.copyWith(errorMessage: 'Ошибка перешифрования данных');
      return false;
    }
  }

  Future<bool> unlock(String pin) async {
    final isValid = await _service.verifyPin(pin);
    if (isValid) {
      state = state.copyWith(
        isUnlocked: true,
        activePin: pin,
        errorMessage: null,
      );
      await loadDocuments();
      return true;
    } else {
      state = state.copyWith(errorMessage: 'Неверный PIN-код');
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Подтвердите личность для входа в Сейф',
      );

      if (authenticated) {
        final realPin = await _service.getSavedPinForBiometrics();
        if (realPin != null) {
          state = state.copyWith(
            isUnlocked: true,
            activePin: realPin,
            errorMessage: null,
          );
          await loadDocuments();
          return true;
        } else {
          state = state.copyWith(
            errorMessage: 'Для первого входа введите PIN вручную',
          );
        }
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Ошибка биометрии: $e');
    }
    return false;
  }

  void lock() {
    state = VaultState(
      hasPin: state.hasPin,
      isUnlocked: false,
      activePin: null,
      documents: [],
      canCheckBiometrics: state.canCheckBiometrics,
    );
  }

  Future<void> loadDocuments() async {
    if (!state.isUnlocked || state.activePin == null) return;

    final db = await DatabaseService.instance.database;
    final rows = await db.query('vault_documents', orderBy: 'updated_at DESC');
    final appDir = await getApplicationDocumentsDirectory();

    final decryptedDocs = <Map<String, dynamic>>[];
    for (final row in rows) {
      final encTitle = row['encrypted_title'] as String;
      final encPayload = row['encrypted_payload'] as String;
      final iv = row['iv'] as String;
      final category = row['category'] as String? ?? 'text';

      String title;
      String payload = '';
      try {
        title = _service.decryptString(encTitle, iv, state.activePin!);
        if (encPayload.contains(':::')) {
          final parts = encPayload.split(':::');
          payload =
              _service.decryptString(parts[0], parts[1], state.activePin!);
        } else {
          payload = _service.decryptString(encPayload, iv, state.activePin!);
        }
      } on VaultCryptoException catch (e) {
        debugPrint('Пропущена повреждённая запись сейфа: $e');
        continue;
      }

      if (category == 'image' || category == 'document') {
        if (!payload.startsWith('/')) {
          payload = '${appDir.path}/$payload';
        } else {
          final fileName = payload.split('/').last;
          final refreshedFile = File('${appDir.path}/$fileName');
          if (refreshedFile.existsSync()) {
            payload = refreshedFile.path;
          }
        }
      }

      decryptedDocs.add({
        'id': row['id'],
        'title': title,
        'category': category,
        'payload': payload,
        'updated_at': row['updated_at'],
      });
    }

    state = state.copyWith(documents: decryptedDocs);
  }

  Future<void> addDocument({
    required String title,
    required String category,
    required String payload,
  }) async {
    if (!state.isUnlocked || state.activePin == null) return;

    final db = await DatabaseService.instance.database;
    final id = 'vault_${DateTime.now().millisecondsSinceEpoch}';
    final nowIso = DateTime.now().toIso8601String();

    String sanitizedPayload = payload;
    if (category == 'image' || category == 'document') {
      final appDir = await getApplicationDocumentsDirectory();
      if (payload.startsWith(appDir.path)) {
        sanitizedPayload = payload.substring(appDir.path.length + 1);
      }
    }

    final encTitleRes = _service.encryptString(title, state.activePin!);
    final encPayloadRes = _service.encryptString(
      sanitizedPayload,
      state.activePin!,
    );

    final combinedPayload =
        '${encPayloadRes['cipherText']!}:::${encPayloadRes['iv']!}';

    final row = {
      'id': id,
      'encrypted_title': encTitleRes['cipherText']!,
      'category': category,
      'encrypted_payload': combinedPayload,
      'iv': encTitleRes['iv']!,
      'is_synced': 0,
      'updated_at': nowIso,
    };

    await db.insert(
      'vault_documents',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await loadDocuments();
    SyncService.instance.syncAll();
  }

  Future<void> deleteDocument(String id) async {
    final db = await DatabaseService.instance.database;

    final target = state.documents
        .where((d) => d['id'].toString() == id)
        .firstOrNull;
    if (target != null &&
        (target['category'] == 'image' || target['category'] == 'document')) {
      try {
        final f = File(target['payload'] as String);
        if (f.existsSync()) {
          await f.delete();
        }
      } catch (_) {}
    }

    await db.delete('vault_documents', where: 'id = ?', whereArgs: [id]);
    await db.insert('delete_queue', {
      'table_name': 'vault_documents',
      'record_id': id,
      'created_at': DateTime.now().toIso8601String(),
    });

    await loadDocuments();
    SyncService.instance.syncAll();
  }

  /// Полная очистка сейфа: удаляет все файлы с диска и очищает БД
  Future<void> wipeVault() async {
    final db = await DatabaseService.instance.database;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(appDir.path);
      if (await dir.exists()) {
        for (final item in dir.listSync()) {
          if (item is File &&
              (item.path.contains('vault_img_') ||
                  item.path.contains('vault_doc_'))) {
            try {
              await item.delete();
            } catch (_) {}
          }
        }
      }

      await db.delete('vault_documents');
    } catch (e) {
      debugPrint('Ошибка при очистке сейфа: $e');
    }

    lock();
    SyncService.instance.syncAll();
  }
}

final vaultProvider = NotifierProvider<VaultNotifier, VaultState>(
  VaultNotifier.new,
);
