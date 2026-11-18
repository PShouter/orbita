import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Хэширование секрета блокировки дневника (PIN или ключ доступа)
/// с солью и PBKDF2, чтобы в SharedPreferences не хранился открытый текст.
class DiaryLockService {
  static const _secretHashKey = 'diary_lock_secret_hash';
  static const _secretSaltKey = 'diary_lock_secret_salt';
  static const _answerHashKey = 'diary_lock_answer_hash';
  static const _answerSaltKey = 'diary_lock_answer_salt';

  // Legacy ключи с открытым текстом для обратной совместимости
  static const _prefSecretLegacy = 'diary_lock_secret';
  static const _prefAnswerLegacy = 'diary_lock_answer';

  /// Генерация случайной криптографической соли
  String _generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Encode(bytes);
  }

  /// PBKDF2-HMAC-SHA256 вывод ключа
  Uint8List _deriveKey(String secret, String salt, {int iterations = 10000}) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    final blockIndexBytes = Uint8List(4);
    ByteData.view(blockIndexBytes.buffer).setUint32(0, 1, Endian.big);

    List<int> u = hmac
        .convert([...utf8.encode(salt), ...blockIndexBytes])
        .bytes;
    final t = List<int>.from(u);
    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int k = 0; k < t.length; k++) {
        t[k] ^= u[k];
      }
    }
    return Uint8List.fromList(t.take(32).toList());
  }

  /// Сохраняет секрет (PIN/ключ) и ответ на контрольный вопрос как соль+хэш.
  Future<void> saveLockData(String secret, String answer) async {
    final prefs = await SharedPreferences.getInstance();

    final secretSalt = _generateSalt();
    final secretHash = sha256
        .convert(_deriveKey(secret, secretSalt))
        .toString();
    await prefs.setString(_secretSaltKey, secretSalt);
    await prefs.setString(_secretHashKey, secretHash);

    final answerSalt = _generateSalt();
    final answerHash = sha256
        .convert(_deriveKey(answer.trim().toLowerCase(), answerSalt))
        .toString();
    await prefs.setString(_answerSaltKey, answerSalt);
    await prefs.setString(_answerHashKey, answerHash);

    // Удаляем устаревшие открытые значения
    await prefs.remove(_prefSecretLegacy);
    await prefs.remove(_prefAnswerLegacy);
  }

  /// Проверка секрета с обратной совместимостью со старым открытым видом.
  Future<bool> verifyLockData(
    String secret, {
    required bool isRecoveryAnswer,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (isRecoveryAnswer) {
      final answerHash = prefs.getString(_answerHashKey);
      final answerSalt = prefs.getString(_answerSaltKey);
      if (answerHash != null && answerSalt != null) {
        final input = secret.trim().toLowerCase();
        final candidate =
            sha256.convert(_deriveKey(input, answerSalt)).toString();
        return candidate == answerHash;
      }
      // legacy
      final legacyAnswer = prefs.getString(_prefAnswerLegacy);
      return legacyAnswer != null &&
          secret.trim().toLowerCase() == legacyAnswer.trim().toLowerCase();
    }

    final secretHash = prefs.getString(_secretHashKey);
    final secretSalt = prefs.getString(_secretSaltKey);
    if (secretHash != null && secretSalt != null) {
      final input = secret.trim();
      final candidate =
          sha256.convert(_deriveKey(input, secretSalt)).toString();
      return candidate == secretHash;
    }
    // legacy open-text
    final legacySecret = prefs.getString(_prefSecretLegacy);
    return legacySecret != null && secret.trim() == legacySecret;
  }

  /// Проверяет, сохранён ли секрет уже в новом (соль+хэш) формате.
  Future<bool> isUsingHashedSecret() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_secretHashKey) &&
        prefs.containsKey(_secretSaltKey);
  }

  /// Удаляет все сохранённые данные блокировки (например, при выключении).
  Future<void> clearLockData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_secretHashKey);
    await prefs.remove(_secretSaltKey);
    await prefs.remove(_answerHashKey);
    await prefs.remove(_answerSaltKey);
  }
}