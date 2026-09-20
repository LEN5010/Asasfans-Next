import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/calendar/application/calendar_providers.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/calendar/presentation/calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _event({
  required String uid,
  required DateTime start,
  DateTime? end,
  String title = '直播',
  bool allDay = false,
  EventStatus status = EventStatus.confirmed,
}) => CalendarEvent(
  uid: uid,
  title: title,
  start: start,
  end: end ?? start.add(const Duration(hours: 2)),
  allDay: allDay,
  status: status,
);

class _StubRepository implements CalendarRepository {
  _StubRepository({
    this.events_ = const [],
    this.failure,
    this.fromCache = false,
  });

  final List<CalendarEvent> events_;
  final ApiFailure? failure;
  final bool fromCache;
  int calls = 0;

  @override
  Future<CalendarSnapshot> events({
    required DateTime from,
    required DateTime until,
    bool forceRefresh = false,
  }) async {
    calls++;
    if (failure != null) throw failure!;
    return CalendarSnapshot(
      events: events_,
      fetchedAt: DateTime.utc(2026, 9, 21, 4),
      fromCache: fromCache,
    );
  }
}

Widget _app(CalendarRepository repository, {DateTime? month}) => ProviderScope(
  overrides: [
    calendarRepositoryProvider.overrideWithValue(repository),
    if (month != null) visibleMonthProvider.overrideWith((ref) => month),
  ],
  child: const MaterialApp(home: CalendarPage()),
);

void main() {
  final september = DateTime.utc(2026, 9);

  setUp(() {
    // The month grid plus its agenda needs more height than the default
    // 800x600 test window.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1000, 1600);
    view.devicePixelRatio = 1;
    addTearDown(view.reset);
  });

  testWidgets('shows the visible month and its day grid', (tester) async {
    await tester.pumpWidget(_app(_StubRepository(), month: september));
    await tester.pumpAndSettle();

    expect(find.text('2026 年 9 月'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('selecting a day lists that day\'s events', (tester) async {
    final repository = _StubRepository(
      events_: [
        _event(uid: '1', start: DateTime.utc(2026, 9, 21, 12), title: '嘉然杂谈'),
      ],
    );
    await tester.pumpWidget(_app(repository, month: september));
    await tester.pumpAndSettle();

    await tester.tap(find.text('21'));
    await tester.pumpAndSettle();

    expect(find.text('嘉然杂谈'), findsOneWidget);
    // 12:00 UTC is 20:00 on the Shanghai calendar the schedule uses.
    expect(find.text('20:00'), findsOneWidget);
  });

  testWidgets('an all-day event is kept and labelled, not filtered away', (
    tester,
  ) async {
    final repository = _StubRepository(
      events_: [
        _event(
          uid: 'bd',
          start: DateTime.utc(2026, 9, 22),
          end: DateTime.utc(2026, 9, 23),
          title: '嘉然生日',
          allDay: true,
        ),
      ],
    );
    await tester.pumpWidget(_app(repository, month: september));
    await tester.pumpAndSettle();

    await tester.tap(find.text('22'));
    await tester.pumpAndSettle();

    expect(find.text('嘉然生日'), findsOneWidget);
    expect(find.text('全天'), findsOneWidget);
  });

  testWidgets('an exclusive all-day end does not occupy the following day', (
    tester,
  ) async {
    final repository = _StubRepository(
      events_: [
        _event(
          uid: 'bd',
          start: DateTime.utc(2026, 9, 22),
          end: DateTime.utc(2026, 9, 23),
          title: '嘉然生日',
          allDay: true,
        ),
      ],
    );
    await tester.pumpWidget(_app(repository, month: september));
    await tester.pumpAndSettle();

    await tester.tap(find.text('23'));
    await tester.pumpAndSettle();

    expect(find.text('嘉然生日'), findsNothing);
    expect(find.textContaining('没有安排'), findsOneWidget);
  });

  testWidgets('the live filter hides non-broadcast entries', (tester) async {
    final repository = _StubRepository(
      events_: [
        _event(uid: '1', start: DateTime.utc(2026, 9, 21, 12), title: '嘉然杂谈'),
        _event(uid: '2', start: DateTime.utc(2026, 9, 21, 13), title: '周边首发'),
      ],
    );
    await tester.pumpWidget(_app(repository, month: september));
    await tester.pumpAndSettle();
    await tester.tap(find.text('21'));
    await tester.pumpAndSettle();
    expect(find.text('周边首发'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '直播'));
    await tester.pumpAndSettle();

    expect(find.text('嘉然杂谈'), findsOneWidget);
    // The entry is hidden from this view but still in the model.
    expect(find.text('周边首发'), findsNothing);
  });

  testWidgets('a cancelled event is shown as cancelled, not deleted', (
    tester,
  ) async {
    final repository = _StubRepository(
      events_: [
        _event(
          uid: '1',
          start: DateTime.utc(2026, 9, 21, 12),
          title: '取消的直播',
          status: EventStatus.cancelled,
        ),
      ],
    );
    await tester.pumpWidget(_app(repository, month: september));
    await tester.pumpAndSettle();

    await tester.tap(find.text('21'));
    await tester.pumpAndSettle();

    expect(find.text('取消的直播'), findsOneWidget);
    expect(find.text('已取消'), findsOneWidget);
  });

  testWidgets('a stale calendar says so instead of implying it is current', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_StubRepository(fromCache: true), month: september),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('缓存内容'), findsOneWidget);
    expect(find.textContaining('上次同步'), findsOneWidget);
  });

  testWidgets('a load failure offers a retry', (tester) async {
    final repository = _StubRepository(
      failure: const ApiFailure(ApiFailureKind.offline),
    );
    await tester.pumpWidget(_app(repository, month: september));
    await tester.pumpAndSettle();

    expect(find.text('网络连接失败'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '重试'));
    await tester.pumpAndSettle();

    expect(repository.calls, greaterThan(1));
  });

  testWidgets('moving to another month loads that month', (tester) async {
    final repository = _StubRepository();
    await tester.pumpWidget(_app(repository, month: september));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('下个月'));
    await tester.pumpAndSettle();

    expect(find.text('2026 年 10 月'), findsOneWidget);
  });
}
