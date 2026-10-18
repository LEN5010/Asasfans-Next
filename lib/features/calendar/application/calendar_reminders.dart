import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/time/local_date_provider.dart';
import '../../library/application/library_providers.dart';
import '../data/calendar_event_store.dart';
import '../data/calendar_reminder_service.dart';
import '../domain/calendar_event.dart';
import '../domain/event_classifier.dart';
import 'calendar_follow_selection.dart';
import 'calendar_providers.dart';

final calendarReminderServiceProvider = Provider<CalendarReminderService>(
  (ref) => CalendarReminderService(ref.watch(localDatabaseProvider)),
);

class CalendarReminderOpen {
  const CalendarReminderOpen({required this.calendar, required this.event});
  final Uri calendar;
  final CalendarEvent event;
}

final calendarReminderOpenProvider = StateProvider<CalendarReminderOpen?>(
  (ref) => null,
);

class CalendarReminderState {
  const CalendarReminderState({
    this.preferences = const CalendarReminderPreferences(),
    this.ready = false,
    this.busy = false,
    this.permission = false,
    this.exactPermission = false,
    this.failure,
  });
  final CalendarReminderPreferences preferences;
  final bool ready;
  final bool busy;
  final bool permission;
  final bool exactPermission;
  final String? failure;
}

final calendarReminderControllerProvider =
    StateNotifierProvider<CalendarReminderController, CalendarReminderState>(
      (ref) => CalendarReminderController(ref),
    );

/// Mounted by the shell after the disclaimer is accepted. No permission prompt
/// is shown until the user subscribes or explicitly enables notifications.
final calendarReminderBootstrapProvider = Provider<void>((ref) {
  var active = true;
  ref.onDispose(() => active = false);
  final controller = ref.read(calendarReminderControllerProvider.notifier);
  ref.listen(calendarLibraryChangesProvider, (_, next) {
    if (next.hasValue) unawaited(controller.synchronize());
  });
  unawaited(
    Future(() async {
      await controller.initialize();
      if (!active) return;
      final now = ref.read(currentTimeProvider)();
      try {
        await ref
            .read(calendarRepositoryProvider)
            .events(from: now, until: now.add(const Duration(days: 30)));
        if (active) await controller.synchronize();
      } catch (_) {
        // The calendar views show the source failure. Existing scheduled alarms
        // remain usable, and synchronization still reads the last stored events.
        if (active) await controller.synchronize();
      }
    }),
  );
});

class CalendarReminderController extends StateNotifier<CalendarReminderState> {
  CalendarReminderController(this.ref) : super(const CalendarReminderState());
  final Ref ref;
  Future<void>? _initialization;
  Future<void> _queue = Future.value();

  Future<void> initialize() async {
    await (_initialization ??= _initialize());
    if (mounted && !state.ready) _initialization = null;
  }

  Future<void> _initialize() async {
    try {
      final service = ref.read(calendarReminderServiceProvider);
      final preferences = await service.loadPreferences();
      await service.initialize((payload) => unawaited(_open(payload)));
      final permission = await service.permitted();
      final exact = await service.exactPermitted();
      if (mounted) {
        state = CalendarReminderState(
          preferences: preferences,
          ready: true,
          permission: permission,
          exactPermission: exact,
        );
      }
    } catch (_) {
      if (mounted) {
        state = CalendarReminderState(
          preferences: state.preferences,
          failure: '开播提醒暂时不可用',
        );
      }
    }
  }

  Future<void> _open(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final calendar = Uri.parse(data['calendar'] as String);
      final events = await ref
          .read(calendarEventStoreProvider)
          .readEvents(calendar, includeGone: true);
      final event = events
          .where(
            (event) =>
                event.uid == data['uid'] &&
                event.recurrenceId == data['recurrenceId'],
          )
          .firstOrNull;
      if (event != null && mounted) {
        ref.read(calendarReminderOpenProvider.notifier).state =
            CalendarReminderOpen(calendar: calendar, event: event);
      }
    } catch (_) {
      if (mounted) {
        state = CalendarReminderState(
          preferences: state.preferences,
          ready: state.ready,
          permission: state.permission,
          exactPermission: state.exactPermission,
          failure: '无法读取这场日程',
        );
      }
    }
  }

  Future<void> setPreferences({bool? enabled, int? minutes}) async {
    await initialize();
    if (!mounted || !state.ready || state.busy) return;
    final previous = state;
    state = CalendarReminderState(
      preferences: previous.preferences,
      ready: true,
      busy: true,
      permission: previous.permission,
      exactPermission: previous.exactPermission,
    );
    try {
      final service = ref.read(calendarReminderServiceProvider);
      final value = CalendarReminderPreferences(
        enabled: enabled ?? previous.preferences.enabled,
        minutes: minutes ?? previous.preferences.minutes,
      );
      var permission = previous.permission;
      var exact = previous.exactPermission;
      if (enabled == true) {
        permission = await service.permitted(request: true);
        exact = await service.exactPermitted(request: true);
      }
      await service.savePreferences(value);
      if (mounted) {
        state = CalendarReminderState(
          preferences: value,
          ready: true,
          permission: permission,
          exactPermission: exact,
        );
      }
      await synchronize();
    } catch (_) {
      if (mounted) {
        state = CalendarReminderState(
          preferences: previous.preferences,
          ready: true,
          permission: previous.permission,
          exactPermission: previous.exactPermission,
          failure: '提醒设置未保存',
        );
      }
    }
  }

  Future<void> requestPermission() => setPreferences(enabled: true);

  Future<void> refreshPermissions() async {
    await initialize();
    if (!mounted || !state.ready) return;
    final service = ref.read(calendarReminderServiceProvider);
    try {
      final permission = await service.permitted();
      final exact = await service.exactPermitted();
      if (mounted) {
        state = CalendarReminderState(
          preferences: await service.loadPreferences(),
          ready: true,
          permission: permission,
          exactPermission: exact,
        );
      }
      await synchronize();
    } catch (_) {
      if (mounted) {
        state = CalendarReminderState(
          preferences: state.preferences,
          ready: true,
          permission: state.permission,
          exactPermission: state.exactPermission,
          failure: '无法读取通知权限',
        );
      }
    }
  }

  Future<void> synchronize() {
    final operation = _queue.then((_) => _synchronize());
    _queue = operation;
    return operation;
  }

  Future<void> _synchronize() async {
    await initialize();
    if (!mounted || !state.ready) return;
    try {
      final calendar = ref.read(appEnvironmentProvider).calendarUrl;
      final store = ref.read(calendarEventStoreProvider);
      final service = ref.read(calendarReminderServiceProvider);
      final library = ref.read(libraryRepositoryProvider);
      final clock = ref.read(currentTimeProvider);
      final preferences = await service.loadPreferences();
      if (!mounted) return;
      state = CalendarReminderState(
        preferences: preferences,
        ready: true,
        permission: state.permission,
        exactPermission: state.exactPermission,
      );
      final members = await store.readMemberFollows();
      final stars = await library.calendarFollows();
      if (!mounted) return;
      final selection = CalendarFollowSelection(members: members, stars: stars);
      final now = clock().toUtc();
      final events = await store.readEvents(
        calendar,
        from: now,
        until: now.add(const Duration(days: 30)),
      );
      if (!mounted) return;
      final desired =
          state.preferences.enabled && state.permission && state.exactPermission
          ? calendarReminderPlan(
              events: events,
              calendar: calendar,
              selection: selection,
              now: now,
              minutes: state.preferences.minutes,
            )
          : <({CalendarEvent event, CalendarReminderRecord record})>[];
      final old = await store.readReminders(calendar);
      final pending = {
        for (final item in await service.plugin.pendingNotificationRequests())
          item.id,
      };
      final wanted = {for (final item in desired) item.record.notificationId};
      final obsolete = {
        for (final item in old)
          if (!wanted.contains(item.notificationId)) item.notificationId,
        for (final id in pending)
          if (id >= 0x20000000 && id < 0x40000000 && !wanted.contains(id)) id,
      };
      for (final id in obsolete) {
        await service.plugin.cancel(id: id);
      }
      for (final item in desired) {
        if (!pending.contains(item.record.notificationId)) {
          await service.schedule(
            item.record.notificationId,
            calendar,
            item.event,
            item.record.fireAt,
          );
        }
      }
      // Any library change lands here, a history entry included; most leave
      // the plan as it was, and then nothing is written.
      final kept = {for (final item in old) item.notificationId};
      if (kept.length != wanted.length || !kept.containsAll(wanted)) {
        await store.replaceReminders(calendar, [
          for (final item in desired) item.record,
        ]);
      }
      if (mounted && state.failure != null) {
        state = CalendarReminderState(
          preferences: state.preferences,
          ready: true,
          permission: state.permission,
          exactPermission: state.exactPermission,
        );
      }
    } catch (_) {
      if (mounted) {
        state = CalendarReminderState(
          preferences: state.preferences,
          ready: true,
          permission: state.permission,
          exactPermission: state.exactPermission,
          failure: '开播提醒排程失败，请重试',
        );
      }
    }
  }
}

/// IDs incorporate content and fire time so a title edit or reschedule is a
/// remove/add difference even on Windows, whose pending API returns IDs only.
List<({CalendarEvent event, CalendarReminderRecord record})>
calendarReminderPlan({
  required List<CalendarEvent> events,
  required Uri calendar,
  required CalendarFollowSelection selection,
  required DateTime now,
  required int minutes,
}) {
  final until = now.add(const Duration(days: 30));
  final eligible =
      events
          .where(
            (event) =>
                !event.isCancelled &&
                !event.allDay &&
                event.start.subtract(Duration(minutes: minutes)).isAfter(now) &&
                !event.start.isAfter(until) &&
                EventClassifier.classify(event) == EventKind.live &&
                selection.contains(event, calendar),
          )
          .toList()
        ..sort((a, b) {
          final time = a.start.compareTo(b.start);
          return time != 0 ? time : a.identity.compareTo(b.identity);
        });
  final used = <int>{};
  return [
    for (final event in eligible.take(50))
      ...() {
        final requested = event.start.subtract(Duration(minutes: minutes));
        final fireAt = requested;
        final key =
            '${CalendarReminderService.payload(calendar, event)}|${requested.millisecondsSinceEpoch}';
        var id = 0x811c9dc5;
        for (final byte in utf8.encode(key)) {
          id = ((id ^ byte) * 0x01000193) & 0x7fffffff;
        }
        id = 0x20000000 | (id & 0x1fffffff);
        while (!used.add(id)) {
          id = 0x20000000 | ((id + 1) & 0x1fffffff);
        }
        return [
          (
            event: event,
            record: CalendarReminderRecord(
              uid: event.uid,
              recurrenceId: event.recurrenceId,
              fireAt: fireAt,
              notificationId: id,
            ),
          ),
        ];
      }(),
  ];
}
