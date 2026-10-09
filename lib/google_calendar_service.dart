import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class GoogleCalendarService {
  static final GoogleCalendarService _instance =
      GoogleCalendarService._internal();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      gcal.CalendarApi.calendarScope,
      gcal.CalendarApi.calendarEventsScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  gcal.CalendarApi? _calendarApi;

  bool get isSignedIn => _currentUser != null;
  String? get userEmail => _currentUser?.email;

  // Авторизация пользователя
  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;

      _currentUser = account;
      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient != null) {
        _calendarApi = gcal.CalendarApi(authClient);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Ошибка авторизации Google: $e');
      return false;
    }
  }

  // Выход из Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _calendarApi = null;
  }

  // Получить события из основного календаря Google
  Future<List<Map<String, dynamic>>> fetchEvents({
    DateTime? from,
    DateTime? to,
  }) async {
    if (_calendarApi == null) {
      final ok = await signIn();
      if (!ok) return [];
    }

    try {
      final start = from ?? DateTime.now().subtract(const Duration(days: 30));
      final end = to ?? DateTime.now().add(const Duration(days: 90));

      final eventsResult = await _calendarApi!.events.list(
        'primary',
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      final items = eventsResult.items ?? [];
      final List<Map<String, dynamic>> parsedEvents = [];

      for (final ev in items) {
        final startDt = ev.start?.dateTime ?? ev.start?.date;
        final endDt = ev.end?.dateTime ?? ev.end?.date;
        final isAllDay = ev.start?.dateTime == null;

        if (startDt != null) {
          parsedEvents.add({
            'id': 'g_${ev.id}',
            'googleEventId': ev.id,
            'title': ev.summary ?? 'Без названия',
            'desc': ev.description ?? '',
            'location': ev.location ?? '',
            'date': startDt.toLocal(),
            'endDate': endDt?.toLocal() ?? startDt.toLocal(),
            'startTime': isAllDay
                ? '00:00'
                : '${startDt.toLocal().hour.toString().padLeft(2, '0')}:${startDt.toLocal().minute.toString().padLeft(2, '0')}',
            'endTime': isAllDay
                ? '23:59'
                : (endDt != null
                      ? '${endDt.toLocal().hour.toString().padLeft(2, '0')}:${endDt.toLocal().minute.toString().padLeft(2, '0')}'
                      : '01:00'),
            'isAllDay': isAllDay,
            'calendar': 'Google',
            'isGoogle': true,
          });
        }
      }

      return parsedEvents;
    } catch (e) {
      debugPrint('Ошибка получения событий Google Calendar: $e');
      return [];
    }
  }

  // Добавить событие из «Орбиты» прямо в Google Календарь
  Future<bool> insertEvent(Map<String, dynamic> event) async {
    if (_calendarApi == null) return false;

    try {
      final DateTime start = event['date'];
      final DateTime end = event['endDate'] ?? start;
      final bool isAllDay = event['isAllDay'] == true;

      gcal.EventDateTime eventStart;
      gcal.EventDateTime eventEnd;

      if (isAllDay) {
        eventStart = gcal.EventDateTime(
          date: DateTime(start.year, start.month, start.day),
        );
        eventEnd = gcal.EventDateTime(
          date: DateTime(
            end.year,
            end.month,
            end.day,
          ).add(const Duration(days: 1)),
        );
      } else {
        final startParts = (event['startTime'] as String? ?? '12:00').split(
          ':',
        );
        final endParts = (event['endTime'] as String? ?? '13:00').split(':');

        final fullStart = DateTime(
          start.year,
          start.month,
          start.day,
          int.tryParse(startParts.first) ?? 12,
          int.tryParse(startParts.last) ?? 0,
        );
        final fullEnd = DateTime(
          end.year,
          end.month,
          end.day,
          int.tryParse(endParts.first) ?? 13,
          int.tryParse(endParts.last) ?? 0,
        );

        eventStart = gcal.EventDateTime(dateTime: fullStart.toUtc());
        eventEnd = gcal.EventDateTime(dateTime: fullEnd.toUtc());
      }

      final gEvent = gcal.Event(
        summary: event['title'],
        description: event['desc'],
        location: event['location'],
        start: eventStart,
        end: eventEnd,
      );

      await _calendarApi!.events.insert(gEvent, 'primary');
      return true;
    } catch (e) {
      debugPrint('Ошибка создания события в Google: $e');
      return false;
    }
  }
}
