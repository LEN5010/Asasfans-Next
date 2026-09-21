import 'package:asasfans_next/features/backup/application/backup_providers.dart';
import 'package:asasfans_next/features/backup/data/backup_codec.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/storage/storage_providers.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/application/fanart_feed_controller.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/library/application/library_providers.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/rules/application/rules_providers.dart';
import 'package:asasfans_next/features/rules/data/sqlite_rules_repository.dart';
import 'package:asasfans_next/features/rules/domain/content_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

FanartItem _item(int id, String text) => FanartItem(
  identity: ContentIdentity(
    source: ContentSource.bilibiliDynamic,
    value: '$id',
  ),
  text: text,
  authorName: '作者',
  authorUid: '123',
  images: const [],
  kind: FanartKind.fanart,
  contentType: FanartContentType.text,
  category: FanartCategory.normal,
  characterTags: const [],
);

class _Source implements FanartRepository {
  int calls = 0;
  bool longHiddenRun = false;
  bool shortHiddenRun = false;
  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    calls++;
    final hidden = longHiddenRun
        ? calls < 6
        : shortHiddenRun
        ? calls == 1
        : false;
    return FanartPage(
      items: [_item(calls, hidden ? 'hide $calls' : '保留的图文')],
      snapshotId: 'same',
      nextCursor: hidden ? '$calls' : null,
    );
  }

  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async => null;
}

void main() {
  late MemoryLocalDatabase db;
  late SqliteRulesRepository rules;
  late SqliteLibraryRepository library;
  late _Source source;
  setUp(() {
    db = MemoryLocalDatabase();
    rules = SqliteRulesRepository(db);
    library = SqliteLibraryRepository(db, backgroundDecoding: false);
    source = _Source();
  });
  tearDown(() async {
    await rules.close();
    await library.close();
    await db.close();
  });
  Widget host() => ProviderScope(
    overrides: [
      localDatabaseProvider.overrideWithValue(db),
      rulesRepositoryProvider.overrideWithValue(rules),
      libraryRepositoryProvider.overrideWithValue(library),
      fanartRepositoryProvider.overrideWithValue(source),
    ],
    child: const MaterialApp(home: ContentPage()),
  );

  testWidgets(
    'blocked first page auto-refills; undo reprojects raw rows without another network request',
    (tester) async {
      source.shortHiddenRun = true;
      final change = await rules.save(
        const RuleDraft(kind: RuleKind.word, value: 'hide'),
      );
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(source.calls, 2);
      expect(find.text('保留的图文'), findsOneWidget);
      expect(find.text('hide 1'), findsNothing);
      expect(find.text('已屏蔽 1'), findsOneWidget);
      await rules.undo(change);
      await tester.pumpAndSettle();
      expect(source.calls, 2);
      expect(find.text('hide 1'), findsOneWidget);
    },
  );
  testWidgets(
    'all-hidden upstream pages stay ready and stop at viewport scan budget, not false end',
    (tester) async {
      source.longHiddenRun = true;
      await rules.save(const RuleDraft(kind: RuleKind.word, value: 'hide'));
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(source.calls, 5);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ContentPage)),
      );
      final state = container
          .read(fanartFeedControllerProvider(ContentChannel.fanart))
          .state;
      expect(state.status, FeedStatus.ready);
      expect(state.items, hasLength(5));
      expect(state.nextCursor, '5');
      expect(find.text('没有更多了'), findsNothing);
      await tester.tap(find.text('继续加载'));
      await tester.pumpAndSettle();
      expect(source.calls, 6);
      expect(find.text('保留的图文'), findsOneWidget);
    },
  );
  testWidgets(
    'quick block and snackbar undo use committed rules without reloading the source',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.longPress(find.text('保留的图文'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('屏蔽'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('屏蔽此内容'));
      await tester.pumpAndSettle();
      expect((await rules.load()).rules.single.draft.kind, RuleKind.content);
      expect(find.text('保留的图文'), findsNothing);
      expect(source.calls, 1);
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();
      expect((await rules.load()).rules, isEmpty);
      expect(find.text('保留的图文'), findsOneWidget);
      expect(source.calls, 1);
    },
  );
  testWidgets(
    'backup merge refreshes live rule projection without replacing the source controller',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ContentPage)),
      );
      final controller = container.read(
        fanartFeedControllerProvider(ContentChannel.fanart),
      );
      final data = <String, Object?>{
        for (final table in BackupCodec.columns.keys) table: <Object?>[],
      };
      data['collection_folders'] = [
        {'id': 'default', 'name': '默认收藏夹', 'created_at': 0},
      ];
      data['content_rules'] = [
        {
          'id': 'a' * 32,
          'kind': 'content',
          'scope': 'bilibiliDynamic',
          'value': '1',
          'enabled': 1,
          'expires_at': null,
          'created_at': 1,
          'updated_at': 1,
        },
      ];
      final file = BackupCodec.decode(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'format': 'asasfans.personal',
              // The table set above is BackupCodec.columns, so the file must
              // declare the version that carries it. An older number with newer
              // tables is a file no release ever wrote.
              'version': BackupCodec.formatVersion,
              'exported_at': DateTime.utc(2026).toIso8601String(),
              'data': data,
            }),
          ),
        ),
      );
      await container.read(backupRepositoryProvider).merge(file);
      await tester.pumpAndSettle();
      expect(find.text('保留的图文'), findsNothing);
      expect(source.calls, 1);
      expect(
        container.read(fanartFeedControllerProvider(ContentChannel.fanart)),
        same(controller),
      );
      expect(controller.state.items, hasLength(1));
    },
  );
}
