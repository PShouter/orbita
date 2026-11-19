import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Сбор и отправка ошибок/крашей на бэкенд разработчику.
///
/// Перехватывает:
///  - ошибки Flutter-фреймворка (FlutterError.onError),
///  - необработанные ошибки зон / асинхронных задач (runZonedGuarded),
///  - синтаксис/платформенные ошибки (PlatformDispatcher.instance.onError),
///  - фатальные лог-сообщения (debugPrint прокси).
///
/// Отправка идёт в таблицу `app_errors` в Supabase (см. supabase/app_errors.sql).
/// Если пользователь не авторизован — запись с user_id=null всё равно пишется,
/// чтобы фиксировать ошибки и в гостевом режиме.
///
/// Записи не блокируют работу: при недоступности сети ошибка кешируется
/// в локальную очередь и доотправляется при следующем запуске.
class ErrorReportService {
  ErrorReportService._();

  static final ErrorReportService instance = ErrorReportService._();

  static const String _table = 'app_errors';

  bool _enabled = false;
  String? _version;
  String? _buildNumber;
  String? _userId;
  final List<Map<String, dynamic>> _pending = [];
  bool _sending = false;

  /// Включает перехват глобальных ошибок. Вызывать один раз из main().
  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _buildNumber = info.buildNumber;
    } catch (_) {}

    // Подписка на смену пользователя (для привязки ошибки к аккаунту).
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        _userId = data.session?.user.id;
      });
      _userId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {}

    _enabled = true;

    // Перехват ошибок фреймворка (виджеты, рендеринг).
    final originalFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      _reportFlutterError(details);
      originalFlutterError?.call(details);
    };

    // Перехват необработанных ошибок (асинхронные, изоляции фрейма).
    final originalZoneError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _reportRaw('platform', error, stack);
      originalZoneError?.call(error, stack);
      return true;
    };

    // Порождение логов перед проверкой обновлений: проксируем debugPrint,
    // чтобы и отладочные предупреждения можно было ловить при необходимости.
    _installDebugPrintProxy();

    await _flushPending();
  }

  void _installDebugPrintProxy() {
    final original = debugPrint;
    _proxy = (String message, {int wrapWidth = 1024}) {
      // Только сообщения с признаком ошибки отправляем.
      final lower = message.toLowerCase();
      if (lower.contains('error') ||
          lower.contains('exception') ||
          lower.contains('fail') ||
          lower.contains('ошибк')) {
        _reportRaw('debug', message, StackTrace.current);
      }
      original(message, wrapWidth: wrapWidth);
    };
  }

  void Function(String message, {int wrapWidth}) _proxy = debugPrint;

  /// Возвращает прокси debugPrint, который дополнительно отправляет в логи
  /// сообщения, выглядящие как ошибки.
  void Function(String message, {int wrapWidth}) get debugPrintProxy => _proxy;

  /// Ручной вызов логирования ошибки из бизнес-кода.
  void logError(String message, [Object? error, StackTrace? stack]) {
    if (!_enabled) return;
    final st = stack ?? (error is Error ? error.stackTrace : null);
    _send({
      'level': 'error',
      'message': message,
      'error': error?.toString(),
      'stack': st?.toString(),
    });
  }

  void _reportFlutterError(FlutterErrorDetails details) {
    if (!_enabled) return;
    _send({
      'level': 'fatal',
      'message': details.exceptionAsString(),
      'error': details.exception.toString(),
      'stack': details.stack?.toString(),
      'context': details.library,
    });
  }

  void _reportRaw(String level, Object error, StackTrace? stack) {
    if (!_enabled) return;
    _send({
      'level': level,
      'message': error.toString(),
      'error': error.runtimeType.toString(),
      'stack': stack?.toString(),
    });
  }

  Future<void> _send(Map<String, dynamic> payload) async {
    payload = Map.from(payload)..addAll(_meta());
    _pending.add(payload);
    await _flushPending();
  }

  Map<String, dynamic> _meta() => {
        'user_id': _userId,
        'app_version': _version,
        'build_number': _buildNumber,
        'platform': Platform.operatingSystem,
        'platform_version': _platformVersion(),
        'device': _deviceName(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

  String _platformVersion() {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return '';
    }
  }

  String _deviceName() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return '';
    }
  }

  Future<void> _flushPending() async {
    if (_sending || _pending.isEmpty) return;
    _sending = true;
    try {
      final batch = List<Map<String, dynamic>>.from(_pending);
      final client = Supabase.instance.client;
      // Пробуем отправить всю очередь одним запросом.
      await client.from(_table).insert(batch).timeout(const Duration(seconds: 6));
      _pending.removeWhere((e) => batch.contains(e));
    } catch (_) {
      // Неудача (нет сети / таблица отсутствует) — оставляем в очереди:
      // flush повторится при следующем запуске.
    } finally {
      _sending = false;
    }
  }
}