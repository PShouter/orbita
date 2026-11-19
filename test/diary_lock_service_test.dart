import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orbita/services/diary_lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('DiaryLockService', () {
    test('сохраняет секрет с солью+хэшем и проверяет верный/неверный PIN',
        () async {
      final service = DiaryLockService();
      await service.saveLockData('123456', 'любимый цвет');

      expect(await service.verifyLockData('123456', isRecoveryAnswer: false),
          isTrue);
      expect(await service.verifyLockData('000000', isRecoveryAnswer: false),
          isFalse);
    });

    test('не хранит открытый секрет в SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await DiaryLockService().saveLockData('987654', 'ответ');
      final keys = prefs.getKeys();
      // Открытых значений (без _hash/_salt) быть не должно.
      expect(keys.any((k) => k.contains('diary_lock_secret')
          && k != 'diary_lock_secret_hash'
          && k != 'diary_lock_secret_salt'), isFalse);
    });

    test('проверяет контрольный ответ регистронезависимо', () async {
      final service = DiaryLockService();
      await service.saveLockData('123456', 'Красный мяч');
      expect(await service.verifyLockData('красный мяч', isRecoveryAnswer: true),
          isTrue);
      expect(await service.verifyLockData('синий мяч', isRecoveryAnswer: true),
          isFalse);
    });

    test('обратная совместимость с legacy открытым секретом', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('diary_lock_secret', 'oldpin123');
      final service = DiaryLockService();
      expect(await service.verifyLockData('oldpin123', isRecoveryAnswer: false),
          isTrue);
      expect(await service.verifyLockData('wrong', isRecoveryAnswer: false),
          isFalse);
    });

    test('isUsingHashedSecret корректно отражает формат', () async {
      final service = DiaryLockService();
      expect(await service.isUsingHashedSecret(), isFalse);
      await service.saveLockData('111111', 'вопрос');
      expect(await service.isUsingHashedSecret(), isTrue);
    });

    test('clearLockData удаляет хэшированные данные', () async {
      final service = DiaryLockService();
      await service.saveLockData('222222', 'ответ');
      expect(await service.isUsingHashedSecret(), isTrue);
      await service.clearLockData();
      expect(await service.isUsingHashedSecret(), isFalse);
      // После очистки верный PIN больше не проходит.
      expect(await service.verifyLockData('222222', isRecoveryAnswer: false),
          isFalse);
    });
  });
}