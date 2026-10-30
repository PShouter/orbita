import 'package:flutter_test/flutter_test.dart';

int parsePriorityToInt(dynamic priority) {
  if (priority is int) return priority;
  switch (priority?.toString()) {
    case 'high':
      return 3;
    case 'medium':
      return 2;
    case 'low':
      return 1;
    default:
      return 0;
  }
}

String parseIntToPriority(dynamic priority) {
  if (priority == 3) return 'high';
  if (priority == 2) return 'medium';
  if (priority == 1) return 'low';
  return 'none';
}

void main() {
  group('SyncService Priority Conversion Tests', () {
    test('Should parse string priority to integer correctly', () {
      expect(parsePriorityToInt('high'), 3);
      expect(parsePriorityToInt('medium'), 2);
      expect(parsePriorityToInt('low'), 1);
      expect(parsePriorityToInt('none'), 0);
      expect(parsePriorityToInt(null), 0);
      expect(parsePriorityToInt(2), 2);
    });

    test('Should parse integer priority back to string correctly', () {
      expect(parseIntToPriority(3), 'high');
      expect(parseIntToPriority(2), 'medium');
      expect(parseIntToPriority(1), 'low');
      expect(parseIntToPriority(0), 'none');
      expect(parseIntToPriority(null), 'none');
    });
  });

  group('SyncService UUID Filter Tests', () {
    final uuidRegExp = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    test('Should recognize valid UUIDs for cloud sync', () {
      expect(
        uuidRegExp.hasMatch('123e4567-e89b-12d3-a456-426614174000'),
        isTrue,
      );
      expect(
        uuidRegExp.hasMatch('c2b8c9d0-1234-5678-90ab-cdef12345678'),
        isTrue,
      );
    });

    test('Should ignore local shift ids from cloud payload', () {
      expect(uuidRegExp.hasMatch('shift_ev_1720000000'), isFalse);
      expect(uuidRegExp.hasMatch('habit_1720000000'), isFalse);
    });
  });
}
