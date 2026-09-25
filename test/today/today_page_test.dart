import '../helpers/library_fixture.dart';
import 'dart:async';

import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/core/time/shanghai_date_provider.dart';
import 'package:asasfans_next/features/calendar/application/calendar_providers.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/calendar/presentation/calendar_page.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/community_video_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/video_card.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/features/today/application/today_providers.dart';
import 'package:asasfans_next/features/today/presentation/today_page.dart';
import 'package:asasfans_next/shared/widgets/app_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../helpers/preferences_fixture.dart';

const _fanart = FanartItem(
  identity: ContentIdentity(source: ContentSource.doubanTopic, value: '1'),
  text: '最新二创正文',
  authorName: '作者',
  authorUid: '1',
  images: [],
  kind: FanartKind.fanart,
  contentType: FanartContentType.text,
  category: FanartCategory.normal,
  characterTags: [],
);
const _clip = CommunityVideo(
  identity: ContentIdentity(
    source: ContentSource.bilibiliVideo,
    value: 'BV1xx411c7mD',
  ),
  title: '最新切片标题',
  creatorName: '切片作者',
  creatorId: '2',
);

class _Calendar implements CalendarRepository {
  List<CalendarEvent> items = [];
  ApiFailure? failure;
  final forced = <bool>[];
  @override
  Future<CalendarSnapshot> events({
    required DateTime from,
    required DateTime until,
    bool forceRefresh = false,
  }) async {
    forced.add(forceRefresh);
    if (failure != null) throw failure!;
    return CalendarSnapshot(
      events: items,
      fetchedAt: DateTime.utc(2026, 9, 21, 4),
    );
  }
}

CalendarEvent _event(
  String title,
  int day, {
  EventStatus status = EventStatus.confirmed,
}) => CalendarEvent(
  uid: title,
  title: title,
  start: DateTime.utc(2026, 9, day, 12),
  end: DateTime.utc(2026, 9, day, 14),
  allDay: false,
  status: status,
);

Widget _host(
  _Calendar calendar, {
  DateTime Function()? clock,
  Future<List<FanartItem>> Function()? fanartLoader,
  double scale = 1,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const TodayPage()),
      GoRoute(path: '/calendar', builder: (_, _) => const CalendarPage()),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      ...offlineLibrary(),
      offlinePreferences(),
      currentTimeProvider.overrideWithValue(
        clock ?? () => DateTime.utc(2026, 9, 21, 4),
      ),
      calendarRepositoryProvider.overrideWithValue(calendar),
      todayFanartProvider.overrideWith(
        (ref) async => fanartLoader == null ? [_fanart] : await fanartLoader(),
      ),
      todayClipsProvider.overrideWith((ref) async => [_clip]),
      onThisDayProvider.overrideWith((ref) async => []),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
  );
}

void _size(WidgetTester tester, Size value) {
  tester.view
    ..physicalSize = value
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets(
    'Density: desktop pairs modules but keeps schedule events vertical',
    (tester) async {
      _size(tester, const Size(1280, 1100));
      final calendar = _Calendar()
        ..items = [_event('今日歌会', 21), _event('今日杂谈', 21)];
      await tester.pumpWidget(_host(calendar));
      await tester.pumpAndSettle();
      expect(find.text('今日歌会'), findsOneWidget);
      expect(find.text('最新二创正文'), findsOneWidget);
      expect(find.text('最新切片标题'), findsOneWidget);
      expect(find.text('Asasfans Next'), findsNothing);
      final art = tester.getRect(find.byType(FanartCard));
      final clip = tester.getRect(find.byType(VideoCard));
      expect(art.top, greaterThan(clip.bottom));
      expect(find.text('最近更新'), findsNothing);
      expect(
        tester.getTopLeft(find.text('今日安排')).dx,
        lessThan(tester.getTopLeft(find.text('历史上的今天')).dx),
      );
      expect(tester.getTopLeft(find.text('历史上的今天')).dy, lessThan(clip.top));
      expect(
        tester.getTopLeft(find.text('今日歌会')).dx,
        tester.getTopLeft(find.text('今日杂谈')).dx,
      );
      expect(
        tester.getTopLeft(find.text('今日歌会')).dy,
        isNot(tester.getTopLeft(find.text('今日杂谈')).dy),
      );
    },
  );

  testWidgets(
    'empty today falls forward to the first non-cancelled event within seven days',
    (tester) async {
      _size(tester, const Size(1000, 900));
      final calendar = _Calendar()
        ..items = [
          _event('已取消安排', 22, status: EventStatus.cancelled),
          _event('下次歌会', 23),
          _event('更晚安排', 24),
        ];
      await tester.pumpWidget(_host(calendar));
      await tester.pumpAndSettle();
      expect(find.text('接下来'), findsOneWidget);
      expect(find.text('下次歌会'), findsOneWidget);
      expect(find.text('9-23'), findsOneWidget);
      expect(find.text('已取消安排'), findsNothing);
      expect(find.text('更晚安排'), findsNothing);
    },
  );

  testWidgets(
    'summary limits today to two events and exposes the remaining count',
    (tester) async {
      _size(tester, const Size(1000, 900));
      final calendar = _Calendar()
        ..items = [_event('a', 21), _event('b', 21), _event('c', 21)];
      await tester.pumpWidget(_host(calendar));
      await tester.pumpAndSettle();
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      expect(find.text('c'), findsNothing);
      expect(find.text('还有 1 项安排'), findsOneWidget);
    },
  );

  testWidgets(
    'calendar retry invalidates the owning month, not just the dependent future',
    (tester) async {
      _size(tester, const Size(1280, 1100));
      final calendar = _Calendar()
        ..failure = const ApiFailure(ApiFailureKind.offline);
      await tester.pumpWidget(_host(calendar));
      await tester.pumpAndSettle();
      expect(calendar.forced, [false]);
      expect(find.text('网络连接失败'), findsOneWidget);
      expect(find.text('最新二创正文'), findsOneWidget);
      expect(find.text('最新切片标题'), findsOneWidget);
      calendar
        ..failure = null
        ..items = [_event('重试后安排', 21)];
      await tester.tap(find.widgetWithText(AppButton, '重试'));
      await tester.pumpAndSettle();
      expect(calendar.forced, [false, false]);
      expect(find.text('重试后安排'), findsOneWidget);
      expect(find.text('网络连接失败'), findsNothing);
    },
  );

  testWidgets(
    'failed fanart stays local and retry leaves clips and schedule intact',
    (tester) async {
      _size(tester, const Size(1280, 1100));
      var calls = 0;
      await tester.pumpWidget(
        _host(
          _Calendar()..items = [_event('今日歌会', 21)],
          fanartLoader: () async {
            if (++calls == 1) throw const ApiFailure(ApiFailureKind.offline);
            return [_fanart];
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('最新切片标题'), findsOneWidget);
      expect(find.text('今日歌会'), findsOneWidget);
      expect(find.text('网络连接失败'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, '重试'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('最新二创正文'), findsOneWidget);
    },
  );

  testWidgets(
    'refresh waits for modules and disables duplicate manual refresh',
    (tester) async {
      _size(tester, const Size(1280, 1100));
      var calls = 0;
      final pending = Completer<List<FanartItem>>();
      final calendar = _Calendar();
      await tester.pumpWidget(
        _host(
          calendar,
          fanartLoader: () =>
              ++calls == 1 ? Future.value([_fanart]) : pending.future,
        ),
      );
      await tester.pumpAndSettle();
      final refreshButton = find.descendant(
        of: find.byTooltip('刷新今日'),
        matching: find.byType(TextButton),
      );
      await tester.tap(refreshButton);
      await tester.pump();
      // byTooltip matches the Tooltip, not the button it wraps.
      expect(tester.widget<TextButton>(refreshButton).onPressed, isNull);
      expect(calls, 2);
      expect(calendar.forced.where((forced) => forced), hasLength(1));
      pending.complete([_fanart]);
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(refreshButton).onPressed, isNotNull);
    },
  );

  testWidgets(
    'Shanghai rollover replaces the schedule date and monthly dependency',
    (tester) async {
      _size(tester, const Size(1280, 1100));
      var now = DateTime.utc(2026, 9, 30, 15, 59, 59);
      final calendar = _Calendar()
        ..items = [_event('九月安排', 30), _event('十月安排', 31)];
      await tester.pumpWidget(_host(calendar, clock: () => now));
      await tester.pumpAndSettle();
      expect(find.text('今日 · 9 月 30 日'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TodayPage)),
      );
      now = now.add(const Duration(seconds: 2));
      container.read(shanghaiDateProvider.notifier).resync();
      await tester.pumpAndSettle();
      expect(find.text('今日 · 10 月 1 日'), findsOneWidget);
      expect(find.text('十月安排'), findsOneWidget);
      expect(find.text('九月安排'), findsNothing);
      expect(calendar.forced, [false, false]);
    },
  );

  testWidgets('home calendar shortcut resets an old selection to today', (
    tester,
  ) async {
    _size(tester, const Size(1000, 900));
    await tester.pumpWidget(_host(_Calendar()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodayPage)),
    );
    container.read(visibleMonthProvider.notifier).state = DateTime.utc(
      2026,
      10,
    );
    container.read(selectedCalendarDayProvider.notifier).state = DateTime.utc(
      2026,
      10,
      10,
    );
    await tester.tap(find.widgetWithText(TextButton, '日历'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarPage), findsOneWidget);
    expect(container.read(visibleMonthProvider), DateTime.utc(2026, 9));
    expect(container.read(selectedCalendarDayProvider), isNull);
  });

  testWidgets('phone shelves remain vertically ordered and fit large text', (
    tester,
  ) async {
    _size(tester, const Size(320, 568));
    await tester.pumpWidget(_host(_Calendar(), scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byType(VideoCard),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('today-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(VideoCard), findsOneWidget);
  });
}
