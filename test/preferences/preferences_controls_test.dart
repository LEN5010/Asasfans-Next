import 'dart:async';

import 'package:asasfans_next/app/asasfans_app.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/core/time/shanghai_date_provider.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/preferences/application/preferences_controller.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:asasfans_next/features/preferences/presentation/preferences_controls.dart';
import 'package:asasfans_next/features/today/application/today_providers.dart';
import 'package:asasfans_next/features/today/presentation/today_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/preferences_fixture.dart';
import '../helpers/today_fixture.dart';

class _DelayedPreferences extends MemoryPreferencesRepository {
  final result = Completer<AppPreferences>();
  @override
  Future<AppPreferences> load() => result.future;
}

void main() {
  testWidgets(
    'theme selection commits then updates the actual application theme mode',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 1100)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = MemoryPreferencesRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: offlineTodayOverrides(preferences: repository),
          child: const AsasfansApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('主题'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('深色'));
      await tester.pumpAndSettle();
      expect(repository.values.appearance, AppAppearance.dark);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(repository.writes, 1);
    },
  );

  testWidgets(
    'failed preference writes do not flip the switch and can be retried',
    (tester) async {
      final repository = MemoryPreferencesRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: PreferencesControls()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      repository.failure = const StorageFailure(StorageFailureKind.unavailable);
      await tester.tap(find.text('首页切片'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '首页切片'))
            .value,
        isTrue,
      );
      expect(find.text('本地资料暂时无法读写，请重试'), findsOneWidget);
      repository.failure = null;
      await tester.tap(find.text('首页切片'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '首页切片'))
            .value,
        isFalse,
      );
      expect(repository.values.shows(HomeSection.clips), isFalse);
    },
  );

  testWidgets(
    'hidden home modules do not load before settings arrive, on display or on refresh',
    (tester) async {
      final repository = _DelayedPreferences();
      var sourceLoads = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesRepositoryProvider.overrideWithValue(repository),
            currentTimeProvider.overrideWithValue(
              () => DateTime.utc(2026, 9, 21, 4),
            ),
            todayScheduleProvider.overrideWith((ref) async {
              sourceLoads++;
              throw StateError('must remain hidden');
            }),
            todayFanartProvider.overrideWith((ref) async {
              sourceLoads++;
              return [];
            }),
            todayClipsProvider.overrideWith((ref) async {
              sourceLoads++;
              return [];
            }),
            onThisDayProvider.overrideWith((ref) async {
              sourceLoads++;
              return [];
            }),
          ],
          child: const MaterialApp(home: TodayPage()),
        ),
      );
      await tester.pump();
      expect(sourceLoads, 0);
      repository.result.complete(
        AppPreferences(hiddenHomeSections: HomeSection.values.toSet()),
      );
      await tester.pumpAndSettle();
      expect(sourceLoads, 0);
      expect(find.text('最新二创'), findsNothing);
      expect(find.text('最新切片'), findsNothing);
      expect(find.text('历史上的今天'), findsNothing);
      expect(find.text('二创档案'), findsOneWidget);
      await tester.tap(find.byTooltip('刷新今日'));
      await tester.pumpAndSettle();
      expect(sourceLoads, 0);
    },
  );
}
