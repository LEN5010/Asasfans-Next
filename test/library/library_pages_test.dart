import 'package:asasfans_next/core/storage/storage_providers.dart';
import 'package:asasfans_next/features/creator/application/creator_providers.dart';
import 'package:asasfans_next/features/creator/presentation/creator_page.dart';
import '../helpers/creator_fixture.dart';
import 'package:asasfans_next/features/library/domain/library_repository.dart';
import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/calendar/presentation/calendar_event_widgets.dart';
import 'package:asasfans_next/features/library/application/library_providers.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/features/library/presentation/calendar_follow_button.dart';
import 'package:asasfans_next/features/library/presentation/calendar_follows.dart';
import 'package:asasfans_next/features/library/presentation/content_actions.dart';
import 'package:asasfans_next/features/library/presentation/library_pages.dart';
import 'package:asasfans_next/features/library/presentation/saved_content_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

const _item = ContentSnapshot(
  identity: ContentIdentity(
    source: ContentSource.bilibiliDynamic,
    value: '12345',
  ),
  title: '保存的作品',
  body: '离线阅读的全文',
  authorName: '作者',
  authorId: '123',
);

class _Links implements ExternalLinkService {
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

class _FailingWrites implements LocalDatabase {
  _FailingWrites(this.inner);
  final LocalDatabase inner;
  bool fail = false;
  @override
  Future<SqlResults> batch(List<SqlStatement> commands, {bool write = false}) {
    if (write && fail) {
      return Future.error(const StorageFailure(StorageFailureKind.unavailable));
    }
    return inner.batch(commands, write: write);
  }

  @override
  Future<void> close() => inner.close();
}

Widget _host(LibraryRepository repository, Widget child, {_Links? links}) =>
    ProviderScope(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(repository),
        localDatabaseProvider.overrideWith((ref) {
          final db = MemoryLocalDatabase();
          ref.onDispose(db.close);
          return db;
        }),
        creatorRepositoryProvider.overrideWithValue(OfflineCreatorRepository()),
        if (links != null) externalLinkServiceProvider.overrideWithValue(links),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  late MemoryLocalDatabase database;
  late _FailingWrites writes;
  late SqliteLibraryRepository repository;
  setUp(() {
    database = MemoryLocalDatabase();
    writes = _FailingWrites(database);
    repository = SqliteLibraryRepository(writes, backgroundDecoding: false);
  });
  tearDown(() async {
    await repository.close();
    await database.close();
  });

  testWidgets(
    'actions save to folders, later and local subscriptions with live committed state',
    (tester) async {
      tester.view
        ..physicalSize = const Size(800, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          repository,
          const Scaffold(body: ContentActionsSheet(item: _item)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, '默认收藏夹'));
      await tester.pumpAndSettle();
      expect((await repository.itemState(_item.identity)).folderIds, {
        'default',
      });
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, '默认收藏夹'),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.widgetWithText(SwitchListTile, '稍后看'));
      await tester.pumpAndSettle();
      expect(await repository.later(), hasLength(1));
      await tester.tap(find.text('新建收藏夹'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '精选');
      // The save button stays disabled until the field reports a non-empty
      // value, so let that rebuild land before tapping it.
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(CheckboxListTile, '精选'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(SwitchListTile, '订阅 作者'));
      await tester.tap(find.widgetWithText(SwitchListTile, '订阅 作者'));
      await tester.pumpAndSettle();
      expect((await repository.subscriptions()).single.mid, '123');
    },
  );

  testWidgets(
    'failed saves leave the checkbox unchanged and recover on retry',
    (tester) async {
      await tester.pumpWidget(
        _host(
          repository,
          const Scaffold(body: ContentActionsSheet(item: _item)),
        ),
      );
      await tester.pumpAndSettle();
      writes.fail = true;
      await tester.tap(find.widgetWithText(CheckboxListTile, '默认收藏夹'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, '默认收藏夹'),
            )
            .value,
        isFalse,
      );
      expect(find.text('本地资料暂时无法读写，请重试'), findsOneWidget);
      writes.fail = false;
      await tester.tap(find.widgetWithText(CheckboxListTile, '默认收藏夹'));
      await tester.pumpAndSettle();
      expect((await repository.collection('default')), hasLength(1));
    },
  );

  testWidgets('saved content opens natively and logs detail, not playback', (
    tester,
  ) async {
    await repository.setCollected(_item, 'default', true);
    await tester.pumpWidget(
      _host(repository, const CollectionPage(folderId: 'default')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存的作品'));
    await tester.pumpAndSettle();
    expect(find.byType(SavedContentPage), findsOneWidget);
    expect(find.text('离线阅读的全文'), findsOneWidget);
    expect((await repository.history()).single.action, HistoryAction.detail);
    expect(await repository.history(action: HistoryAction.playback), isEmpty);
  });

  testWidgets(
    'history filtering and removal do not affect favorites or other actions',
    (tester) async {
      await repository.setCollected(_item, 'default', true);
      await repository.recordHistory(_item, HistoryAction.detail);
      await repository.recordHistory(_item, HistoryAction.external);
      await tester.pumpWidget(_host(repository, const LibraryHistoryPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '外部打开'));
      await tester.pumpAndSettle();
      expect(find.text('保存的作品'), findsOneWidget);
      await tester.tap(find.byTooltip('管理内容'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除这条记录'));
      await tester.pumpAndSettle();
      expect(find.text('暂无记录'), findsOneWidget);
      expect((await repository.history()).single.action, HistoryAction.detail);
      expect(await repository.collection('default'), hasLength(1));
    },
  );

  testWidgets(
    'manual local subscription validates MID and only opens the explicit profile link',
    (tester) async {
      final links = _Links();
      await tester.pumpWidget(
        _host(repository, const SubscriptionsPage(), links: links),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('添加 UP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'invalid');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '订阅'))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField).first, '123');
      await tester.enterText(find.byType(TextField).last, '测试 UP');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '订阅'));
      await tester.pumpAndSettle();
      expect(links.opened, isEmpty);
      expect((await repository.subscriptions()).single.mid, '123');
      await tester.tap(find.text('测试 UP'));
      await tester.pumpAndSettle();
      expect(find.byType(CreatorPage), findsOneWidget);
      expect(links.opened, isEmpty);
      await tester.tap(find.byTooltip('在 B 站打开 UP 主页'));
      await tester.pumpAndSettle();
      expect(links.opened, [Uri.parse('https://space.bilibili.com/123')]);
      expect(await repository.history(), isEmpty);
    },
  );

  testWidgets(
    'followed calendar entries reopen with correct source and can be unfollowed',
    (tester) async {
      final source = Uri.parse('https://different.example/calendar.ics');
      final event = CalendarEvent(
        uid: 'event',
        title: '已关注歌会',
        start: DateTime.utc(2026, 9, 21, 12),
        end: DateTime.utc(2026, 9, 21, 14),
        allDay: false,
      );
      await repository.followCalendar(
        CalendarFollowKey(source: source, uid: event.uid),
        event,
      );
      await tester.pumpWidget(_host(repository, const CalendarFollowsPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('已关注歌会'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventDetail), findsOneWidget);
      // The toggle is built with TextButton.icon, whose private widget is not a
      // TextButton, so anchor on the follow button itself rather than on a
      // Material internal that can change shape between versions.
      final toggle = find.descendant(
        of: find.byType(CalendarFollowButton),
        matching: find.text('已关注'),
      );
      expect(toggle, findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(await repository.calendarFollows(), isEmpty);
      expect(
        find.descendant(
          of: find.byType(CalendarFollowButton),
          matching: find.text('关注日程'),
        ),
        findsOneWidget,
      );
    },
  );

  for (final size in const [Size(320, 568), Size(1280, 800)]) {
    testWidgets('personal pages fit ${size.width} with large text', (
      tester,
    ) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await repository.setCollected(_item, 'default', true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [libraryRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const CollectionPage(folderId: 'default'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
