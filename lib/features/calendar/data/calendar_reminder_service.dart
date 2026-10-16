import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/storage/local_database.dart';
import '../domain/calendar_agenda.dart';
import '../domain/calendar_event.dart';
import '../domain/event_classifier.dart';

class CalendarReminderPreferences {
  const CalendarReminderPreferences({this.enabled = true, this.minutes = 5});
  final bool enabled;
  final int minutes;
  String get timing => minutes == 0 ? '准点提醒' : '开播前 $minutes 分钟提醒';
}

class CalendarReminderService {
  CalendarReminderService(this.database);
  final LocalDatabase database;
  final plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;

  Future<CalendarReminderPreferences> loadPreferences() async {
    final rows = (await database.batch([
      const SqlStatement(
        "SELECT key,value FROM preferences WHERE key IN ('calendar.reminders.enabled','calendar.reminders.minutes')",
        [],
        true,
      ),
    ])).single;
    final values = {for (final row in rows) row['key']: row['value']};
    return CalendarReminderPreferences(
      enabled: values['calendar.reminders.enabled'] != 'false',
      minutes:
          int.tryParse(values['calendar.reminders.minutes'] as String? ?? '') ??
          5,
    );
  }

  Future<void> savePreferences(CalendarReminderPreferences value) async {
    await database.batch([
      SqlStatement(
        'INSERT INTO preferences(key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
        ['calendar.reminders.enabled', '${value.enabled}'],
      ),
      SqlStatement(
        'INSERT INTO preferences(key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
        ['calendar.reminders.minutes', '${value.minutes}'],
      ),
    ], write: true);
  }

  Future<void> initialize(void Function(String?) onOpen) async {
    try {
      await (_initialization ??= _initialize(onOpen));
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initialize(void Function(String?) onOpen) async {
    tz_data.initializeTimeZones();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_calendar'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
        windows: WindowsInitializationSettings(
          appName: 'Asasfans Next',
          appUserModelId: 'Asasfans.Next',
          guid: '91f67015-5bfc-4e77-a593-58e6de86d519',
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onOpen(response.payload),
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      onOpen(launch?.notificationResponse?.payload);
    }
  }

  Future<bool> permitted({bool request = false}) async {
    if (Platform.isAndroid) {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      if (request) {
        return await android.requestNotificationsPermission() ?? false;
      }
      return await android.areNotificationsEnabled() ?? false;
    }
    if (Platform.isIOS) {
      final ios = plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()!;
      if (request) {
        return await ios.requestPermissions(
              alert: true,
              sound: true,
              badge: false,
            ) ??
            false;
      }
      return (await ios.checkPermissions())?.isEnabled ?? false;
    }
    if (Platform.isMacOS) {
      final mac = plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()!;
      if (request) {
        return await mac.requestPermissions(
              alert: true,
              sound: true,
              badge: false,
            ) ??
            false;
      }
      return (await mac.checkPermissions())?.isEnabled ?? false;
    }
    return Platform.isWindows;
  }

  Future<bool> exactPermitted({bool request = false}) async {
    if (!Platform.isAndroid) return true;
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!;
    if (request) await android.requestExactAlarmsPermission();
    return await android.canScheduleExactNotifications() ?? false;
  }

  Future<void> openSettings() async {
    if (Platform.isAndroid) {
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
    } else if (Platform.isIOS) {
      await plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
    } else if (Platform.isMacOS) {
      await plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
    }
  }

  static String payload(Uri calendar, CalendarEvent event) => jsonEncode({
    'calendar': '$calendar',
    'uid': event.uid,
    'recurrenceId': event.recurrenceId,
    'sequence': event.sequence,
    'title': event.title,
    'url': event.sourceUrl?.toString(),
  });

  static String title(CalendarEvent event) {
    final members = EventClassifier.members(event);
    return '${members.isEmpty ? '直播' : members.join('、')} · ${CalendarAgenda.time(event.start)} 开播';
  }

  Future<void> schedule(
    int id,
    Uri calendar,
    CalendarEvent event,
    DateTime at,
  ) => plugin.zonedSchedule(
    id: id,
    title: title(event),
    body: event.title,
    scheduledDate: tz.TZDateTime.from(at, tz.getLocation('Asia/Shanghai')),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'calendar_live',
        '开播提醒',
        channelDescription: '已关注成员和星标场次的开播时间',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      windows: WindowsNotificationDetails(),
    ),
    payload: payload(calendar, event),
  );
}
