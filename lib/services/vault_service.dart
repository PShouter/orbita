import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VaultService {
  static final VaultService instance = VaultService._init();
  VaultService._init();

  static const String _secPinHash = 'vault_sec_pin_hash';
  static const String _secPinSalt = 'vault_sec_pin_salt';
  static const String _secBiometricKey = 'vault_bio_master_pin_secure';

  // Legacy ключи из SharedPreferences для обратной совместимости
  static const String _prefLegacyPinHash = 'vault_pin_hash';
  static const String _prefLegacySalt = 'vault_pin_salt';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Генерация случайной криптографической соли
  String _generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Encode(bytes);
  }

  /// Стандартный PBKDF2-HMAC-SHA256 для вывода устойчивого 256-битного ключа
  Uint8List _pbkdf2DeriveKey(
    String pin,
    String salt, {
    int iterations = 10000,
    int keyLength = 32,
  }) {
    final saltBytes = utf8.encode(salt);
    final pinBytes = utf8.encode(pin);

    final hmac = Hmac(sha256, pinBytes);
    final derivedKey = Uint8List(keyLength);

    int blockIndex = 1;
    int keyOffset = 0;

    while (keyOffset < keyLength) {
      final blockIndexBytes = Uint8List(4);
      ByteData.view(blockIndexBytes.buffer)
          .setUint32(0, blockIndex, Endian.big);

      List<int> u = hmac.convert([...saltBytes, ...blockIndexBytes]).bytes;
      final t = List<int>.from(u);

      for (int i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (int k = 0; k < t.length; k++) {
          t[k] ^= u[k];
        }
      }

      final copyLength = min(keyLength - keyOffset, t.length);
      derivedKey.setRange(
        keyOffset,
        keyOffset + copyLength,
        t.take(copyLength),
      );
      keyOffset += copyLength;
      blockIndex++;
    }

    return derivedKey;
  }

  /// Проверка наличия PIN (с фоновой миграцией из SharedPreferences)
  Future<bool> hasPin() async {
    final hasSecure = await _secureStorage.containsKey(key: _secPinHash);
    if (hasSecure) return true;

    // Проверяем наличие в старом SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_prefLegacyPinHash)) {
      final legacyHash = prefs.getString(_prefLegacyPinHash);
      final legacySalt = prefs.getString(_prefLegacySalt);
      if (legacyHash != null && legacySalt != null) {
        // Мигрируем в SecureStorage
        await _secureStorage.write(key: _secPinHash, value: legacyHash);
        await _secureStorage.write(key: _secPinSalt, value: legacySalt);
        await prefs.remove(_prefLegacyPinHash);
        await prefs.remove(_prefLegacySalt);
        return true;
      }
    }
    return false;
  }

  /// Установка нового мастер-PIN
  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final key = _pbkdf2DeriveKey(pin, salt);
    final hash = sha256.convert(key).toString();

    // Сохраняем соль, хэш и мастер-PIN строго в защищенном хранилище
    await _secureStorage.write(key: _secPinSalt, value: salt);
    await _secureStorage.write(key: _secPinHash, value: hash);
    await _secureStorage.write(key: _secBiometricKey, value: pin);

    // Очищаем legacy-записи в SharedPreferences при их наличии
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefLegacyPinHash);
    await prefs.remove(_prefLegacySalt);
    await prefs.remove('vault_bio_master_pin');
  }

  /// Получение сохраненного PIN для биометрии
  Future<String?> getSavedPinForBiometrics() async {
    return await _secureStorage.read(key: _secBiometricKey);
  }

  /// Проверка введенного PIN
  Future<bool> verifyPin(String pin) async {
    String? salt = await _secureStorage.read(key: _secPinSalt);
    String? savedHash = await _secureStorage.read(key: _secPinHash);

    // Если в SecureStorage пусто, проверяем legacy SharedPreferences
    if (salt == null || savedHash == null) {
      final prefs = await SharedPreferences.getInstance();
      salt = prefs.getString(_prefLegacySalt);
      savedHash = prefs.getString(_prefLegacyPinHash);
    }

    if (salt == null || savedHash == null) return false;

    // 1. Проверяем по PBKDF2
    final key = _pbkdf2DeriveKey(pin, salt);
    final inputHash = sha256.convert(key).toString();

    if (inputHash == savedHash) {
      // Сохраняем в SecureStorage актуальное состояние
      await _secureStorage.write(key: _secPinHash, value: savedHash);
      await _secureStorage.write(key: _secPinSalt, value: salt);
      await _secureStorage.write(key: _secBiometricKey, value: pin);
      return true;
    }

    // 2. Fallback для обратной совместимости со старым SHA-256 хэшем
    final legacyKey = sha256
        .convert(utf8.encode('$pin:$salt:orbita_vault_v1'))
        .bytes;
    final legacyHash = sha256.convert(legacyKey).toString();

    if (legacyHash == savedHash) {
      // Автоматически обновляем хэш до PBKDF2 в SecureStorage
      await setPin(pin);
      return true;
    }

    return false;
  }

  /// Полный сброс параметров сейфа
  Future<void> resetVault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefLegacyPinHash);
    await prefs.remove(_prefLegacySalt);
    await prefs.remove('vault_bio_master_pin');

    await _secureStorage.delete(key: _secPinHash);
    await _secureStorage.delete(key: _secPinSalt);
    await _secureStorage.delete(key: _secBiometricKey);
  }

/// Шифрование текста алгоритмом AES-GCM (12-байтный nonce) с
/// пер-документной случайной солью для производного ключа.
/// Возвращает {cipherText, iv}, где iv = "ivBase64:::saltBase64".
Map<String, String> encryptString(String plainText, String pin) {
  final salt = _generateSalt();
  final keyBytes = _pbkdf2DeriveKey(pin, salt);
  final key = enc.Key(keyBytes);
  final iv = enc.IV.fromSecureRandom(12);

  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
  final encrypted = encrypter.encrypt(plainText, iv: iv);

  return {'cipherText': encrypted.base64, 'iv': '${iv.base64}:::$salt'};
}

/// Разбирает значение iv (возможно "iv:::salt"), возвращает соль для
/// производного ключа. Для старых записей (без соли) — статичная соль.
String _extractSalt(String ivBase64) {
  if (ivBase64.contains(':::')) {
    final parts = ivBase64.split(':::');
    if (parts.length >= 2 && parts[1].isNotEmpty) return parts[1];
  }
  return 'orbita_vault_static_salt_v2';
}

/// Расшифровка текста с поддержкой обратной совместимости.
/// ivBase64 может содержать "iv:::salt" (новые записи) или только iv (старые).
String decryptString(String cipherBase64, String ivBase64, String pin) {
  // Извлекаем соль: пер-документная (если в iv) либо статичная (legacy).
  final salt = _extractSalt(ivBase64);
  final rawIv = ivBase64.contains(':::')
      ? ivBase64.split(':::').first
      : ivBase64;

  // 1. Попытка расшифровать методом AES-GCM
  try {
    final keyBytes = _pbkdf2DeriveKey(pin, salt);
    final key = enc.Key(keyBytes);
    final iv = enc.IV.fromBase64(rawIv);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    return encrypter.decrypt64(cipherBase64, iv: iv);
  } on FormatException {
    rethrow;
  } catch (_) {}

  // 2. Fallback: расшифровка старых данных в AES-CBC
  try {
    final legacyKeyBytes = sha256
        .convert(utf8.encode('$pin:orbita_vault_salt_v1'))
        .bytes;
    final legacyKey = enc.Key(Uint8List.fromList(legacyKeyBytes));
    final iv = enc.IV.fromBase64(rawIv);

    final encrypter = enc.Encrypter(
      enc.AES(legacyKey, mode: enc.AESMode.cbc),
    );
    return encrypter.decrypt64(cipherBase64, iv: iv);
  } catch (_) {
    throw VaultCryptoException(
      'Не удалось расшифровать данные сейфа. Вероятно, PIN указан неверно или данные повреждены.',
    );
  }
}
}

class VaultCryptoException implements Exception {
  const VaultCryptoException(this.message);
  final String message;

  @override
  String toString() => message;
}