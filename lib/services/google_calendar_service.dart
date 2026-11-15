import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

class GoogleCalendarService {
  static final GoogleCalendarService instance =
      GoogleCalendarService._internal();
  GoogleCalendarService._internal();

  static const String? _kServerClientId = null;

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _kServerClientId,
    scopes: [gcal.CalendarApi.calendarScope],
  );

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  Future<bool> init() async {
    try {
      _currentUser = await _googleSignIn
          .signInSilently()
          .timeout(const Duration(seconds: 3), onTimeout: () => null);

      if (_currentUser != null) {
        debugPrint(
            'Google Calendar: восстановлена сессия (${_currentUser!.email})');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Google Calendar: сессия не найдена или офлайн ($e)');
      return false;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      debugPrint('Google Calendar: запуск интерактивного входа...');
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) {
        debugPrint('Google Calendar: успешный вход -> ${_currentUser!.email}');
      }
      return _currentUser;
    } catch (e, stack) {
      debugPrint('Критическая ошибка авторизации Google: $e');
      debugPrint('Стек ошибки: $stack');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
      _currentUser = null;
      debugPrint('Google Calendar: успешный выход');
    } catch (e) {
      debugPrint('Ошибка выхода из Google Calendar: $e');
    }
  }

  /// Получение списка всех подключенных календарей пользователя
  Future<List<gcal.CalendarListEntry>> fetchUserCalendars() async {
    try {
      final client = await _googleSignIn.authenticatedClient();
      if (client == null) return [];

      final calendarApi = gcal.CalendarApi(client);
      final calendarList = await calendarApi.calendarList
          .list()
          .timeout(const Duration(seconds: 8));
      final items = calendarList.items ?? [];
      debugPrint(
        'Google Calendar: найдено календарей у пользователя: ${items.length}',
      );
      return items;
    } catch (e) {
      debugPrint('Ошибка получения списка календарей: $e');
      return [];
    }
  }

  /// Получение событий из одного конкретного календаря
  Future<List<gcal.Event>> fetchEvents({
    String calendarId = 'primary',
    required DateTime timeMin,
    required DateTime timeMax,
  }) async {
    try {
      final client = await _googleSignIn.authenticatedClient();
      if (client == null) return [];

      final calendarApi = gcal.CalendarApi(client);
      final response = await calendarApi.events
          .list(
            calendarId,
            timeMin: timeMin.toUtc(),
            timeMax: timeMax.toUtc(),
            singleEvents: true,
            maxResults: 2500,
            orderBy: 'startTime',
          )
          .timeout(const Duration(seconds: 8));

      final items = response.items ?? [];
      debugPrint(
        'Google Calendar: получено ${items.length} событий из календаря "$calendarId"',
      );
      return items;
    } catch (e, stack) {
      debugPrint('Ошибка запроса событий из календаря "$calendarId": $e');
      debugPrint('Стек ошибки: $stack');
      return [];
    }
  }

  /// Сквозная выгрузка событий со всех доступных календарей аккаунта,
  /// с сохранением привязки события к его календарю.
  Future<List<GCalEvent>> fetchAllEventsFromAllCalendars({
    required DateTime timeMin,
    required DateTime timeMax,
  }) async {
    final calendars = await fetchUserCalendars();
    final List<GCalEvent> result = [];
    final Set<String> processedEventIds = {};

    if (calendars.isEmpty) {
      final events = await fetchEvents(
        calendarId: 'primary',
        timeMin: timeMin,
        timeMax: timeMax,
      );
      for (final ev in events) {
        final evId =
            ev.id ?? '${ev.summary}_${ev.start?.dateTime ?? ev.start?.date}';
        result.add(
          GCalEvent(
            event: ev,
            calendarId: 'primary',
            calendarTitle: 'Google',
            colorArgb: 0xFF4285F4,
          ),
        );
        processedEventIds.add(evId);
      }
      return result;
    }

    for (final cal in calendars) {
      final calId = cal.id;
      if (calId == null || cal.accessRole == 'none') continue;

      final events = await fetchEvents(
        calendarId: calId,
        timeMin: timeMin,
        timeMax: timeMax,
      );

      for (final ev in events) {
        final evId =
            ev.id ?? '${ev.summary}_${ev.start?.dateTime ?? ev.start?.date}';
        if (processedEventIds.contains(evId)) continue;
        processedEventIds.add(evId);
        result.add(
          GCalEvent(
            event: ev,
            calendarId: calId,
            calendarTitle: cal.summaryOverride ?? cal.summary ?? 'Google',
            colorArgb: _parseHexColor(cal.backgroundColor),
          ),
        );
      }
    }

debugPrint(
      'Google Calendar: всего собрано уникальных событий со всех календарей: ${result.length}',
    );
    return result;
  }

  /// Преобразует hex-строку (#RRGGBB / #AARRGGBB) в ARGB int.
  static int _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return 0xFF4285F4;
    var cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 3) {
      cleaned = '${cleaned[0]}${cleaned[0]}${cleaned[1]}${cleaned[1]}${cleaned[2]}${cleaned[2]}';
    }
    if (cleaned.length != 6) return 0xFF4285F4;
    return int.parse('FF$cleaned', radix: 16);
  }

  /// Обновление локальной копии события уже попало в БД приложения.
  /// Полная синхронизация изменений обратно в Google Calendar (название,
  /// время) выполняется через API. Здесь — заглушка-хук для обратной записи.
  Future<void> updateEventLocalChanges({
    required String eventId,
    required String title,
  }) async {
    try {
      // В текущей версии события Google импортируются локально,
      // изменение локальной копии достаточно. Обратная запись в Google
      // недоступна без серверного refresh-токена; при его появлении
      // реализация добавляется здесь.
      debugPrint('Google Calendar: локальное обновление "$title" ($eventId)');
    } catch (e) {
      debugPrint('Google Calendar: ошибка обратной записи: $e');
    }
  }
}

/// Событие Google вместе с календарём, из которого оно пришло.
class GCalEvent {
  final gcal.Event event;
  final String calendarId;
  final String calendarTitle;
  final int colorArgb;

  GCalEvent({
    required this.event,
    required this.calendarId,
    required this.calendarTitle,
    this.colorArgb = 0xFF4285F4,
  });
}
