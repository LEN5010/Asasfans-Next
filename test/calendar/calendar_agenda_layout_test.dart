import '../helpers/library_fixture.dart';
import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/core/time/shanghai_date_provider.dart';
import 'package:asasfans_next/features/calendar/application/calendar_providers.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/calendar/presentation/calendar_event_widgets.dart';
import 'package:asasfans_next/features/calendar/presentation/calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Calendar implements CalendarRepository {
  _Calendar(this.items, {this.failure});
  final List<CalendarEvent> items;
  final ApiFailure? failure;
  @override
  Future<CalendarSnapshot> events({
    required DateTime from,
    required DateTime until,
    bool forceRefresh = false,
  }) async {
    if (failure != null) throw failure!;
    return CalendarSnapshot(
      events: items,
      fetchedAt: DateTime.utc(2026, 9, 21, 4),
    );
  }
}

class _Links implements ExternalLinkService {
  final opened = <Uri>[];
  bool success = true;
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return success;
  }
}

CalendarEvent _event(
  String title,
  int day, {
  Uri? url,
  String member = '嘉然',
  EventStatus status = EventStatus.confirmed,
}) => CalendarEvent(
  uid: title,
  title: title,
  start: DateTime.utc(2026, 9, day, 12),
  end: DateTime.utc(2026, 9, day, 14),
  allDay: false,
  members: [member],
  description: '完整的日程简介',
  location: '直播间',
  categories: const ['歌会'],
  sourceUrl: url,
  status: status,
);

Widget _host(
  List<CalendarEvent> events, {
  double textScale = 1,
  DateTime? selected,
  _Links? links,
  ApiFailure? failure,
}) => ProviderScope(
  overrides: [
    ...offlineLibrary(),
    currentTimeProvider.overrideWithValue(() => DateTime.utc(2026, 9, 21, 4)),
    calendarRepositoryProvider.overrideWithValue(
      _Calendar(events, failure: failure),
    ),
    if (selected != null) ...[
      visibleMonthProvider.overrideWith(
        (ref) => DateTime.utc(selected.year, selected.month),
      ),
      selectedCalendarDayProvider.overrideWith((ref) => selected),
    ],
    if (links != null) externalLinkServiceProvider.overrideWithValue(links),
  ],
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const CalendarPage(),
  ),
);

void _size(WidgetTester tester, Size value) {
  tester.view
    ..physicalSize = value
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets(
    'phone defaults to a week strip and can expand and collapse the month',
    (tester) async {
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(_host([_event('今晚歌会', 21)]));
      await tester.pumpAndSettle();
      expect(find.text('今晚歌会'), findsOneWidget);
      expect(find.text('30'), findsNothing);
      await tester.tap(find.byTooltip('展开月历'));
      await tester.pumpAndSettle();
      expect(find.text('30'), findsOneWidget);
      await tester.tap(find.byTooltip('收起月历'));
      await tester.pumpAndSettle();
      expect(find.text('30'), findsNothing);
      await tester.tap(find.byTooltip('下个月'));
      await tester.pumpAndSettle();
      expect(find.text('2026 年 10 月'), findsOneWidget);
      await tester.tap(find.byTooltip('回到今天'));
      await tester.pumpAndSettle();
      expect(find.text('2026 年 9 月'), findsOneWidget);
      expect(find.text('今晚歌会'), findsOneWidget);
    },
  );

  testWidgets('desktop bounds the sidebar and puts agenda alongside it', (
    tester,
  ) async {
    _size(tester, const Size(1280, 800));
    await tester.pumpWidget(_host([_event('今晚歌会', 21)]));
    await tester.pumpAndSettle();
    final sidebar = tester.getRect(
      find.byKey(const ValueKey('calendar-sidebar')),
    );
    final agenda = tester.getRect(
      find.byKey(const ValueKey('calendar-agenda-true')),
    );
    expect(sidebar.width, inInclusiveRange(320, 380));
    expect(agenda.left, greaterThanOrEqualTo(sidebar.right));
    expect(agenda.top, sidebar.top);
    expect(find.byTooltip('展开月历'), findsNothing);
  });

  testWidgets(
    'member filter uses structured members and reset restores events',
    (tester) async {
      _size(tester, const Size(1280, 800));
      await tester.pumpWidget(
        _host([_event('安排甲', 21), _event('安排乙', 21, member: '贝拉')]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, '嘉然'));
      await tester.pumpAndSettle();
      expect(find.text('安排甲'), findsOneWidget);
      expect(find.text('安排乙'), findsNothing);
      await tester.tap(find.text('重置筛选'));
      await tester.pumpAndSettle();
      expect(find.text('安排乙'), findsOneWidget);
    },
  );

  testWidgets('week agenda includes both sides of a month boundary', (
    tester,
  ) async {
    _size(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _host([
        _event('九月安排', 30),
        _event('十月安排', 31),
      ], selected: DateTime.utc(2026, 9, 30)),
    );
    await tester.pumpAndSettle();
    expect(find.text('十月安排'), findsNothing);
    await tester.tap(find.text('周议程'));
    await tester.pumpAndSettle();
    expect(find.text('九月安排'), findsOneWidget);
    expect(find.text('十月安排'), findsOneWidget);
    expect(find.text('9 月 28 日 — 10 月 4 日'), findsOneWidget);
  });

  testWidgets('entry without a URL opens a native detail with full fields', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    await tester.pumpWidget(
      _host([_event('今晚歌会', 21, status: EventStatus.tentative)]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('今晚歌会'));
    await tester.pumpAndSettle();
    final detail = find.byType(CalendarEventDetail);
    expect(detail, findsOneWidget);
    expect(
      find.descendant(of: detail, matching: find.text('完整的日程简介')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detail, matching: find.text('直播间')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detail, matching: find.text('待定')),
      findsOneWidget,
    );
    expect(find.text('打开原站'), findsNothing);
    await tester.tap(find.byTooltip('关闭日程'));
    await tester.pumpAndSettle();
    expect(detail, findsNothing);
  });

  testWidgets(
    'source only opens after the explicit action and reports failure',
    (tester) async {
      _size(tester, const Size(390, 844));
      final links = _Links()..success = false;
      final url = Uri.parse('https://example.com/schedule');
      await tester.pumpWidget(
        _host([_event('今晚歌会', 21, url: url)], links: links),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('今晚歌会'));
      await tester.pumpAndSettle();
      expect(links.opened, isEmpty);
      await tester.tap(find.text('打开原站'));
      await tester.pumpAndSettle();
      expect(links.opened, [url]);
      expect(find.text('无法打开链接'), findsOneWidget);
    },
  );

  testWidgets('loading errors do not remove date and filter controls', (
    tester,
  ) async {
    _size(tester, const Size(1280, 800));
    await tester.pumpWidget(
      _host([], failure: const ApiFailure(ApiFailureKind.offline)),
    );
    await tester.pumpAndSettle();
    expect(find.text('网络连接失败'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '嘉然'), findsOneWidget);
    expect(find.byTooltip('回到今天'), findsOneWidget);
  });

  testWidgets('expanded month and agenda fit a narrow window with large text', (
    tester,
  ) async {
    _size(tester, const Size(320, 568));
    await tester.pumpWidget(
      _host([_event('一个非常长的直播标题用来检查换行', 21)], textScale: 3),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('展开月历'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('周议程'),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('calendar-compact')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
