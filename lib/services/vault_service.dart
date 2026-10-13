import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:shared_preferences/shared_preferences.dart';

class VaultService {
  static final VaultService instance = VaultService._init();
  VaultService._init();

  static const String _prefPinHash = 'vault_pin_hash';
  static const String _prefSalt = 'vault_pin_salt';
  static const String _prefBiometricKey = 'vault_bio_master_pin';

  String _generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Encode(bytes);
  }

  Uint8List _deriveKey(String pin, String salt) {
    final keyBytes = utf8.encode('$pin:$salt:orbita_vault_v1');
    final digest = sha256.convert(keyBytes);
    return Uint8List.fromList(digest.bytes);
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_prefPinHash);
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = _generateSalt();
    final key = _deriveKey(pin, salt);
    final hash = sha256.convert(key).toString();

    await prefs.setString(_prefSalt, salt);
    await prefs.setString(_prefPinHash, hash);
    await prefs.setString(_prefBiometricKey, pin);
  }

  Future<String?> getSavedPinForBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefBiometricKey);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = prefs.getString(_prefSalt);
    final savedHash = prefs.getString(_prefPinHash);

    if (salt == null || savedHash == null) return false;

    final key = _deriveKey(pin, salt);
    final inputHash = sha256.convert(key).toString();
    final isValid = inputHash == savedHash;

    if (isValid) {
      await prefs.setString(_prefBiometricKey, pin);
    }
    return isValid;
  }

  Future<void> resetVault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefPinHash);
    await prefs.remove(_prefSalt);
    await prefs.remove(_prefBiometricKey);
  }

  Map<String, String> encryptString(String plainText, String pin) {
    final keyBytes = sha256
        .convert(utf8.encode('$pin:orbita_vault_salt_v1'))
        .bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));
    final iv = enc.IV.fromSecureRandom(16);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    return {'cipherText': encrypted.base64, 'iv': iv.base64};
  }

  String decryptString(String cipherBase64, String ivBase64, String pin) {
    try {
      final keyBytes = sha256
          .convert(utf8.encode('$pin:orbita_vault_salt_v1'))
          .bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final iv = enc.IV.fromBase64(ivBase64);

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt64(cipherBase64, iv: iv);
    } catch (_) {
      return '[Ошибка расшифровки]';
    }
  }
}
