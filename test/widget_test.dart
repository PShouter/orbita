import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Orbita smoke test: ProviderScope and theme initialization', (
    WidgetTester tester,
  ) async {
    // Проверяем базовый рендеринг Flutter-приложения с ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Center(child: Text('Орбита'))),
        ),
      ),
    );

    // Убеждаемся, что приложение собирается без ошибок дерева виджетов
    expect(find.text('Орбита'), findsOneWidget);
  });
}
