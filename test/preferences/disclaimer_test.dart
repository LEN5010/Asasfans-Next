import 'dart:convert';

import 'package:asasfans_next/app/asasfans_app.dart';
import 'package:asasfans_next/app/router/app_router.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/backup/data/sqlite_backup_repository.dart';
import 'package:asasfans_next/features/preferences/data/sqlite_preferences_repository.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:asasfans_next/features/preferences/presentation/disclaimer_page.dart';
import 'package:asasfans_next/features/today/presentation/today_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/preferences_fixture.dart';
import '../helpers/sqlite_fixture.dart';
import '../helpers/today_fixture.dart';

void main() {
  testWidgets(
    'first launch waits three seconds; acknowledgement survives restart',
    (tester) async {
      final repository = MemoryPreferencesRepository(const AppPreferences());
      Widget app() => ProviderScope(
        overrides: offlineTodayOverrides(preferences: repository),
        child: const AsasfansApp(),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(TodayPage), findsNothing);
      expect(find.textContaining('AI 大模型自动清洗数据'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2800));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(FilledButton));
      expect(repository.writes, 0);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('我已阅读'));
      await tester.pumpAndSettle();
      expect(repository.values.disclaimerAccepted, isTrue);
      expect(find.byType(TodayPage), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(DisclaimerPage), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AsasfansApp)),
      );
      container.read(appRouterProvider).go('/mine/settings');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('免责声明'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('免责声明'));
      await tester.pumpAndSettle();
      expect(find.byType(DisclaimerPage), findsOneWidget);
      expect(find.textContaining('len5010.top'), findsOneWidget);
      expect(find.text('我已阅读'), findsNothing);
    },
  );

  testWidgets(
    'a failed acknowledgement keeps the app closed and permits retry',
    (tester) async {
      final repository = MemoryPreferencesRepository(const AppPreferences());
      await tester.pumpWidget(
        ProviderScope(
          overrides: offlineTodayOverrides(preferences: repository),
          child: const AsasfansApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      repository.failure = const StorageFailure(StorageFailureKind.unavailable);
      await tester.tap(find.text('我已阅读'));
      await tester.pumpAndSettle();
      expect(find.byType(TodayPage), findsNothing);
      expect(repository.values.disclaimerAccepted, isFalse);
      expect(find.text('本地资料暂时无法读写，请重试'), findsOneWidget);
      repository.failure = null;
      await tester.tap(find.text('我已阅读'));
      await tester.pumpAndSettle();
      expect(find.byType(TodayPage), findsOneWidget);
    },
  );

  test(
    'acknowledgement persists locally, stays out of backup and survives preference edits',
    () async {
      final db = MemoryLocalDatabase();
      addTearDown(db.close);
      final repository = SqlitePreferencesRepository(db);
      expect((await repository.load()).disclaimerAccepted, isFalse);
      await repository.acceptDisclaimer();
      await repository.setAppearance(AppAppearance.dark);
      await repository.setGlass(GlassChoice.smooth);
      await repository.setHomeSection(HomeSection.clips, false);
      expect(
        (await SqlitePreferencesRepository(db).load()).disclaimerAccepted,
        isTrue,
      );
      final backup = SqliteBackupRepository(db, onCommitted: () {});
      expect(
        utf8.decode(await backup.export()),
        isNot(contains('app.disclaimer.accepted')),
      );
    },
  );
}
