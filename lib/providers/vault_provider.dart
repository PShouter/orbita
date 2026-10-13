import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
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

    final decryptedDocs = <Map<String, dynamic>>[];
    for (final row in rows) {
      final encTitle = row['encrypted_title'] as String;
      final encPayload = row['encrypted_payload'] as String;
      final iv = row['iv'] as String;

      final title = _service.decryptString(encTitle, iv, state.activePin!);
      final payload = _service.decryptString(encPayload, iv, state.activePin!);

      decryptedDocs.add({
        'id': row['id'],
        'title': title,
        'category': row['category'],
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

    final encRes = _service.encryptString(title, state.activePin!);
    final encPayloadRes = _service.encryptString(payload, state.activePin!);

    final row = {
      'id': id,
      'encrypted_title': encRes['cipherText']!,
      'category': category,
      'encrypted_payload': encPayloadRes['cipherText']!,
      'iv': encRes['iv']!,
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
    await db.delete('vault_documents', where: 'id = ?', whereArgs: [id]);
    await db.insert('delete_queue', {
      'table_name': 'vault_documents',
      'record_id': id,
      'created_at': DateTime.now().toIso8601String(),
    });

    await loadDocuments();
    SyncService.instance.syncAll();
  }
}

final vaultProvider = NotifierProvider<VaultNotifier, VaultState>(
  VaultNotifier.new,
);
