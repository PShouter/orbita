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

  static const String _prefPinHash = 'vault_pin_hash';
  static const String _prefSalt = 'vault_pin_salt';
  static const String _secBiometricKey = 'vault_bio_master_pin_secure';

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

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_prefPinHash);
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = _generateSalt();
    final key = _pbkdf2DeriveKey(pin, salt);
    final hash = sha256.convert(key).toString();

    await prefs.setString(_prefSalt, salt);
    await prefs.setString(_prefPinHash, hash);

    // Сохраняем PIN для биометрии строго в защищенном аппаратном хранилище
    await _secureStorage.write(key: _secBiometricKey, value: pin);

    // Удаляем старый небезопасный ключ из SharedPreferences, если он был
    await prefs.remove('vault_bio_master_pin');
  }

  Future<String?> getSavedPinForBiometrics() async {
    return await _secureStorage.read(key: _secBiometricKey);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = prefs.getString(_prefSalt);
    final savedHash = prefs.getString(_prefPinHash);

    if (salt == null || savedHash == null) return false;

    // 1. Проверяем по новому PBKDF2
    final key = _pbkdf2DeriveKey(pin, salt);
    final inputHash = sha256.convert(key).toString();

    if (inputHash == savedHash) {
      await _secureStorage.write(key: _secBiometricKey, value: pin);
      return true;
    }

    // 2. Fallback для обратной совместимости со старым SHA-256 хэшем
    final legacyKey = sha256
        .convert(utf8.encode('$pin:$salt:orbita_vault_v1'))
        .bytes;
    final legacyHash = sha256.convert(legacyKey).toString();

    if (legacyHash == savedHash) {
      // Автоматически мигрируем хэш на PBKDF2
      await setPin(pin);
      return true;
    }

    return false;
  }

  Future<void> resetVault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefPinHash);
    await prefs.remove(_prefSalt);
    await prefs.remove('vault_bio_master_pin');
    await _secureStorage.delete(key: _secBiometricKey);
  }

  /// Шифрование текста алгоритмом AES-GCM (12-байтный nonce)
  Map<String, String> encryptString(String plainText, String pin) {
    final keyBytes = _pbkdf2DeriveKey(pin, 'orbita_vault_static_salt_v2');
    final key = enc.Key(keyBytes);
    // Для GCM стандартный размер IV/nonce — 12 байт (96 бит)
    final iv = enc.IV.fromSecureRandom(12);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    return {'cipherText': encrypted.base64, 'iv': iv.base64};
  }

  /// Расшифровка текста с поддержкой обратной совместимости с legacy CBC
  String decryptString(String cipherBase64, String ivBase64, String pin) {
    // 1. Попытка расшифровать новым методом AES-GCM
    try {
      final keyBytes = _pbkdf2DeriveKey(pin, 'orbita_vault_static_salt_v2');
      final key = enc.Key(keyBytes);
      final iv = enc.IV.fromBase64(ivBase64);

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      return encrypter.decrypt64(cipherBase64, iv: iv);
    } catch (_) {}

    // 2. Fallback: расшифровка старых данных в AES-CBC
    try {
      final legacyKeyBytes = sha256
          .convert(utf8.encode('$pin:orbita_vault_salt_v1'))
          .bytes;
      final legacyKey = enc.Key(Uint8List.fromList(legacyKeyBytes));
      final iv = enc.IV.fromBase64(ivBase64);

      final encrypter = enc.Encrypter(
        enc.AES(legacyKey, mode: enc.AESMode.cbc),
      );
      return encrypter.decrypt64(cipherBase64, iv: iv);
    } catch (_) {
      return '[Ошибка расшифровки]';
    }
  }
}
