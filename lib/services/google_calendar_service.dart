import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

class GoogleCalendarService {
  static final GoogleCalendarService instance =
      GoogleCalendarService._internal();
  GoogleCalendarService._internal();

  // На Android для работы с Calendar API обычно достаточно чистого вызова без serverClientId,
  // либо с Client ID Web-приложения из Google Cloud Console.
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
      _currentUser = await _googleSignIn.signInSilently();
      debugPrint('Google Calendar: тихий вход -> ${_currentUser?.email}');
      return _currentUser != null;
    } catch (e) {
      debugPrint('Ошибка тихого входа Google Calendar: $e');
      return false;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      debugPrint('Google Calendar: запуск интерактивного входа...');
      _currentUser = await _googleSignIn.signIn();
      debugPrint('Google Calendar: результат входа -> ${_currentUser?.email}');
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
      final calendarList = await calendarApi.calendarList.list();
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
      if (client == null) {
        debugPrint(
          'Google Calendar: authenticatedClient вернул NULL (нет токенов доступа)',
        );
        return [];
      }

      final calendarApi = gcal.CalendarApi(client);
      final response = await calendarApi.events.list(
        calendarId,
        timeMin: timeMin.toUtc(),
        timeMax: timeMax.toUtc(),
        singleEvents: true,
        maxResults: 2500,
        orderBy: 'startTime',
      );

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

  /// Сквозная выгрузка всех событий из ВСЕХ доступных календарей аккаунта
  Future<List<gcal.Event>> fetchAllEventsFromAllCalendars({
    required DateTime timeMin,
    required DateTime timeMax,
  }) async {
    final calendars = await fetchUserCalendars();
    final List<gcal.Event> allEvents = [];
    final Set<String> processedEventIds = {};

    // Если список календарей не удалось получить, запрашиваем хотя бы primary
    if (calendars.isEmpty) {
      return fetchEvents(
        calendarId: 'primary',
        timeMin: timeMin,
        timeMax: timeMax,
      );
    }

    for (final cal in calendars) {
      final calId = cal.id;
      if (calId == null) continue;

      // Пропускаем календари, к которым нет прав на чтение
      if (cal.accessRole == 'none') continue;

      final events = await fetchEvents(
        calendarId: calId,
        timeMin: timeMin,
        timeMax: timeMax,
      );

      for (final ev in events) {
        final evId =
            ev.id ?? '${ev.summary}_${ev.start?.dateTime ?? ev.start?.date}';
        // Исключаем дубликаты, если событие числится в нескольких списках
        if (!processedEventIds.contains(evId)) {
          processedEventIds.add(evId);
          allEvents.add(ev);
        }
      }
    }

    debugPrint(
      'Google Calendar: всего собрано уникальных событий со всех календарей: ${allEvents.length}',
    );
    return allEvents;
  }
}
