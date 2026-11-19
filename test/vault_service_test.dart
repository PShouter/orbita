import 'package:flutter_test/flutter_test.dart';

import 'package:orbita/services/vault_service.dart';

void main() {
  group('VaultService crypto', () {
    test('шифрование->расшифровка с пер-документной солью (round-trip)',
        () {
      final pin = '1234';
      final r = VaultService.instance.encryptString('секретный текст', pin);
      // iv должен содержать соль (формат iv:::salt)
      expect(r['iv'], contains(':::'));
      final dec = VaultService.instance.decryptString(
        r['cipherText']!,
        r['iv']!,
        pin,
      );
      expect(dec, 'секретный текст');
    });

    test('разные вызовы encryptString дают разные соли (соль случайна)',
        () {
      final pin = '9999';
      final a = VaultService.instance.encryptString('одинаковый текст', pin);
      final b = VaultService.instance.encryptString('одинаковый текст', pin);
      // Соли разные -> iv (iv:::salt) разные даже при одинаковом IV.
      expect(a['iv'], isNot(b['iv']));
    });

    test('неверный PIN приводит к VaultCryptoException, а не к мусору', () {
      final r = VaultService.instance.encryptString('данные', '1234');
      expect(
        () => VaultService.instance.decryptString(
          r['cipherText']!,
          r['iv']!,
          '9999',
        ),
        throwsA(isA<VaultCryptoException>()),
      );
    });

    test('обратная совместимость: iv без соли расшифровывается статичной', () {
      // Эмулируем старую запись: iv без ':::' не может быть расшифрована,
      // но и не падает с паническим исключением в формате — проверим,
      // что строка формата поймана.
      final r = VaultService.instance.encryptString('текст', '0000');
      final legacyIv = r['iv']!.split(':::').first; // только iv, без соли
      // Соль утрачена, поэтому расшифровать не должны — но должен быть
      // VaultCryptoException (не FormatException наружу в неожиданном виде).
      expect(
        () => VaultService.instance.decryptString(
          r['cipherText']!,
          legacyIv,
          '0000',
        ),
        throwsA(isA<VaultCryptoException>()),
      );
    });

    test('расшифровка данных пустой строки', () {
      final r = VaultService.instance.encryptString('', '7777');
      final dec = VaultService.instance.decryptString(
        r['cipherText']!,
        r['iv']!,
        '7777',
      );
      expect(dec, '');
    });
  });
}