import 'dart:convert';
import 'dart:io';

import 'package:asasfans_next/app/asasfans_app.dart';
import 'package:asasfans_next/core/time/local_date_provider.dart';
import 'package:asasfans_next/features/operations/application/operations_controller.dart';
import 'package:asasfans_next/features/operations/domain/app_operations.dart';
import 'package:asasfans_next/features/operations/presentation/operation_widgets.dart';
import 'package:asasfans_next/features/release/domain/app_release.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/operations_fixture.dart';
import '../helpers/sqlite_fixture.dart';
import '../helpers/today_fixture.dart';

Map<String, dynamic> _campaign() => {
  'id': 'concert',
  'title': '此间共鸣',
  'body': '10.24—25 · 上海',
  'startsAt': '2026-10-20T00:00:00+08:00',
  'endsAt': '2026-11-01T00:00:00+08:00',
  'platforms': <String>[],
  'buttonLabel': '查看物料',
  'action': {'type': 'collection', 'value': 'cijian-gongming-2026'},
  'strip': true,
  'splash': null,
};

Map<String, dynamic> _poster() => {
  ..._campaign(),
  'splash': {
    'portrait': {
      'url': 'https://len5010.top/dynamics/api/app/media/a.webp',
      'width': 1080,
      'height': 1920,
    },
    'landscape': null,
    'seconds': 5,
  },
};

Map<String, dynamic> _notice(String id, {List<String> platforms = const []}) =>
    {
      'id': id,
      'title': '公告 $id',
      'body': '正文 $id',
      'startsAt': '2026-10-20T00:00:00+08:00',
      'endsAt': '2026-11-01T00:00:00+08:00',
      'platforms': platforms,
      'important': false,
      'image': null,
      'buttonLabel': '',
      'action': null,
    };

Map<String, dynamic> _policy([String platform = 'android']) => {
  'platform': platform,
  'recommendedVersion': '3.1.5',
  'minimumVersion': '3.1.5',
  'message': '更新后继续使用',
};

void main() {
  testWidgets(
    'important announcements still open when saving read marks fails',
    (tester) async {
      final db = MemoryLocalDatabase();
      final repository = OperationsFixture(
        db,
        value: emptyOperations()
          ..['announcements'] = [
            {..._notice('n1'), 'important': true},
          ],
      )..failReadWrites = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...offlineTodayOverrides(),
            currentTimeProvider.overrideWithValue(
              () => DateTime.utc(2026, 10, 21),
            ),
            operationsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const AsasfansApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('关闭'), findsOneWidget);
      expect(find.text('正文 n1'), findsWidgets);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('关闭'), findsNothing);
      expect(repository.events, ['announcement:n1:impression']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    },
  );

  testWidgets(
    'optional update stays dismissible when its preference cannot be saved',
    (tester) async {
      final db = MemoryLocalDatabase();
      final repository = OperationsFixture(
        db,
        value: emptyOperations()
          ..['updates'] = [
            {
              ..._policy(),
              'minimumVersion': null,
              'message': List.filled(100, '更新内容').join(),
            },
          ],
      )..failSeenWrites = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...offlineTodayOverrides(),
            operationsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const AsasfansApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('发现新版本 3.1.5'), findsOneWidget);
      await tester.tap(find.text('稍后'));
      await tester.pumpAndSettle();
      expect(find.text('发现新版本 3.1.5'), findsNothing);
      expect(find.text('更新偏好保存失败'), findsOneWidget);
      expect(repository.events, [
        'update:android:impression',
        'update:android:dismiss',
      ]);
      expect(find.byTooltip('刷新今日'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    },
  );

  testWidgets(
    'a ready launch poster can be skipped and is shown only once per day',
    (tester) async {
      final db = MemoryLocalDatabase();
      final config = emptyOperations()..['campaigns'] = [_poster()];
      final repository = OperationsFixture(db, value: config)
        ..splashFile = File('assets/brand/asasfans.png').absolute;
      await tester.runAsync(
        () => repository.saveLocal('cache', jsonEncode(config)),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.runAsync(
        () => precacheImage(
          ResizeImage(
            FileImage(repository.splashFile!),
            width: 1440,
            height: 2560,
            policy: ResizeImagePolicy.fit,
          ),
          tester.element(find.byType(SizedBox).first),
        ),
      );
      Widget app() => ProviderScope(
        overrides: [
          ...offlineTodayOverrides(),
          currentTimeProvider.overrideWithValue(
            () => DateTime.utc(2026, 10, 21),
          ),
          operationsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const AsasfansApp(),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('跳过 5'), findsOneWidget);
      await tester.tap(find.text('跳过 5'));
      await tester.pumpAndSettle();
      expect(find.textContaining('跳过'), findsNothing);
      expect(repository.events, [
        'splash:concert:impression',
        'splash:concert:dismiss',
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.textContaining('跳过'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    },
  );

  testWidgets('muting a launch poster stops only that poster on later days', (
    tester,
  ) async {
    final db = MemoryLocalDatabase();
    final config = emptyOperations()..['campaigns'] = [_poster()];
    final repository = OperationsFixture(db, value: config)
      ..splashFile = File('assets/brand/asasfans.png').absolute;
    await tester.runAsync(
      () => repository.saveLocal('cache', jsonEncode(config)),
    );
    var now = DateTime.utc(2026, 10, 21, 4);
    Future<void> launch() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...offlineTodayOverrides(),
            currentTimeProvider.overrideWithValue(() => now),
            operationsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const AsasfansApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }

    await launch();
    expect(find.text('不再提醒'), findsOneWidget);
    await tester.tap(find.text('不再提醒'));
    await tester.pumpAndSettle();
    expect(find.textContaining('跳过'), findsNothing);
    expect(repository.events.last, 'splash:concert:mute');
    await tester.pumpWidget(const SizedBox.shrink());
    now = DateTime.utc(2026, 10, 23, 4);
    await launch();
    expect(find.textContaining('跳过'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });

  testWidgets('closing the campaign strip keeps a toolbar button', (
    tester,
  ) async {
    final db = MemoryLocalDatabase();
    final repository = OperationsFixture(
      db,
      value: emptyOperations()..['campaigns'] = [_campaign()],
    );
    Widget app() => ProviderScope(
      overrides: [
        currentTimeProvider.overrideWithValue(() => DateTime.utc(2026, 10, 21)),
        operationsRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Column(children: [CampaignStrip(), CampaignShortcuts()]),
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('查看物料'), findsOneWidget);
    expect(find.byTooltip('此间共鸣'), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('收起'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('查看物料'), findsNothing);
    expect(find.byTooltip('此间共鸣'), findsOneWidget);
    expect(repository.events, [
      'strip:concert:impression',
      'strip:concert:dismiss',
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('查看物料'), findsNothing);
    expect(find.byTooltip('此间共鸣'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });

  test(
    'campaign starts inclusively and expires at Beijing midnight across device zones',
    () {
      final item = AppOperation.fromJson(_campaign());
      expect(item.activeAt(DateTime.parse('2026-10-19T15:59:59Z')), isFalse);
      expect(item.activeAt(DateTime.parse('2026-10-19T16:00:00Z')), isTrue);
      expect(item.activeAt(DateTime.parse('2026-10-31T15:59:59Z')), isTrue);
      expect(item.activeAt(DateTime.parse('2026-10-31T16:00:00Z')), isFalse);
      final policy = AppUpdatePolicy.fromJson(_policy());
      expect(policy.requires(AppVersion.tryParse('3.1.3')!), isTrue);
      expect(policy.requires(AppVersion.tryParse('3.1.5')!), isFalse);
      expect(policy.requires(AppVersion.tryParse('3.2.0')!), isFalse);
    },
  );

  test('a poster fits the window shape and falls back to the other one', () {
    final splash = AppOperation.fromJson(_poster()).splash!;
    expect(splash.pick(tall: true)!.width, 1080);
    expect(splash.pick(tall: false)!.width, 1080);
    expect(
      AppOperation.fromJson({..._campaign(), 'splash': null}).splash,
      isNull,
    );
  });

  testWidgets('entries for other platforms are left out', (tester) async {
    final db = MemoryLocalDatabase();
    final repository = OperationsFixture(
      db,
      value: emptyOperations()
        ..['campaigns'] = [
          {
            ..._campaign(),
            'platforms': ['ios'],
          },
        ]
        ..['announcements'] = [
          _notice('everywhere'),
          _notice('android', platforms: ['android']),
          _notice('windows', platforms: ['windows']),
        ],
    );
    final controller = OperationsController(
      repository,
      () => DateTime.utc(2026, 10, 21),
    );
    await tester.runAsync(() async {
      await controller.initialized;
      await controller.refresh();
    });
    expect(controller.state.campaigns, isEmpty);
    expect(controller.state.announcements.map((item) => item.id), [
      'everywhere',
      'android',
    ]);
    controller.dispose();
    await db.close();
  });

  testWidgets('opening an announcement marks it read on this device', (
    tester,
  ) async {
    final db = MemoryLocalDatabase();
    final repository = OperationsFixture(
      db,
      value: emptyOperations()..['announcements'] = [_notice('n1')],
    );
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTimeProvider.overrideWithValue(
            () => DateTime.utc(2026, 10, 21),
          ),
          operationsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (_, ref, _) {
                widgetRef = ref;
                return const AnnouncementCards();
              },
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final controller = widgetRef.read(operationsProvider.notifier);
    expect(controller.unread, 1);
    await tester.runAsync(() async {
      await tester.tap(find.text('公告 n1'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('正文 n1'), findsWidgets);
    expect(controller.read('n1'), isTrue);
    expect(controller.unread, 0);
    expect(repository.events, ['announcement:n1:impression']);
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });

  testWidgets(
    'cached campaigns expire and offline cached policies never become fresh',
    (tester) async {
      final db = MemoryLocalDatabase();
      final config = emptyOperations()
        ..['campaigns'] = [
          {..._campaign(), 'startsAt': '2026-10-31T15:59:59Z'},
        ]
        ..['updates'] = [_policy()];
      final repository = OperationsFixture(db, value: config)..offline = true;
      await repository.saveLocal('cache', jsonEncode(config));
      var now = DateTime.parse('2026-10-31T15:59:58Z');
      final controller = OperationsController(repository, () => now);
      await tester.runAsync(() => controller.initialized);
      await tester.pump();
      expect(controller.state.campaigns, isEmpty);
      expect(controller.state.fresh, isFalse);
      now = DateTime.parse('2026-10-31T15:59:59Z');
      await tester.pump(const Duration(seconds: 1));
      expect(controller.state.campaigns.single.title, '此间共鸣');
      now = DateTime.parse('2026-10-31T16:00:00Z');
      await tester.pump(const Duration(seconds: 1));
      expect(controller.state.campaigns, isEmpty);
      controller.dispose();
      await db.close();
    },
  );

  testWidgets(
    'fresh data survives cache writes failing and read marks persist locally',
    (tester) async {
      final db = MemoryLocalDatabase();
      final repository = OperationsFixture(
        db,
        value: emptyOperations()..['campaigns'] = [_campaign()],
      )..failCacheWrites = true;
      final controller = OperationsController(
        repository,
        () => DateTime.utc(2026, 10, 21),
      );
      await tester.runAsync(() async {
        await controller.initialized;
        await controller.refresh();
        await controller.markSeen('notices', 'notice-1');
      });
      expect(controller.state.fresh, isTrue);
      expect(controller.state.campaigns.single.title, '此间共鸣');
      expect(controller.seen('notices', 'notice-1'), isTrue);
      repository.failCacheWrites = false;
      await tester.runAsync(controller.refresh);
      final next = OperationsController(
        repository..offline = true,
        () => DateTime.utc(2026, 10, 21),
      );
      await tester.runAsync(() => next.initialized);
      expect(next.seen('notices', 'notice-1'), isTrue);
      expect(next.state.campaigns.single.title, '此间共鸣');
      controller.dispose();
      next.dispose();
      await db.close();
    },
  );

  testWidgets(
    'campaign entry and mandatory update follow live policy withdrawal',
    (tester) async {
      final platform = defaultTargetPlatform;
      final db = MemoryLocalDatabase();
      final config = emptyOperations()..['campaigns'] = [_campaign()];
      final repository = OperationsFixture(db, value: config);
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...offlineTodayOverrides(),
            currentTimeProvider.overrideWithValue(
              () => DateTime.utc(2026, 10, 21),
            ),
            operationsRepositoryProvider.overrideWithValue(repository),
          ],
          child: Consumer(
            builder: (_, ref, _) {
              widgetRef = ref;
              return const AsasfansApp();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('查看物料'), findsNothing);
      repository.value = {
        ...config,
        'updates': [_policy(platform.name.toLowerCase())],
      };
      await tester.runAsync(
        () => widgetRef.read(operationsProvider.notifier).refresh(),
      );
      await tester.pumpAndSettle();
      expect(find.text('发现新版本 3.1.5'), findsOneWidget);
      repository.value = config;
      await tester.runAsync(
        () => widgetRef.read(operationsProvider.notifier).refresh(),
      );
      await tester.pumpAndSettle();
      expect(find.text('发现新版本 3.1.5'), findsNothing);
      expect(find.byTooltip('刷新今日'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );
}
