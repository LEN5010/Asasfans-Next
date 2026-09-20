import 'dart:async';
import 'dart:typed_data';

import 'package:asasfans_next/features/backup/application/backup_providers.dart';
import 'package:asasfans_next/features/backup/data/backup_files.dart';
import 'package:asasfans_next/features/backup/domain/personal_backup.dart';
import 'package:asasfans_next/features/backup/presentation/backup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Import implements BackupImport {
  @override
  final summary = BackupSummary(
    exportedAt: DateTime.utc(2026, 9, 21),
    counts: {'collection_items': 5, 'local_subscriptions': 2},
  );
}

class _Repository implements BackupRepository {
  final imported = _Import();
  int merges = 0;
  BackupImport? accepted;
  bool invalid = false;
  Completer<void>? mergeGate;
  @override
  Future<Uint8List> export() async => Uint8List.fromList([1, 2, 3]);
  @override
  Future<BackupImport> inspect(Uint8List bytes) async {
    if (invalid) throw const BackupFailure(BackupFailureKind.invalid);
    return imported;
  }

  @override
  Future<void> merge(BackupImport backup) async {
    accepted = backup;
    merges++;
    await mergeGate?.future;
  }
}

class _Files implements BackupFiles {
  Uint8List? bytes = Uint8List.fromList([1, 2, 3]);
  int picks = 0;
  BackupExportResult result = BackupExportResult.saved;
  Rect? origin;
  @override
  Future<Uint8List?> pick() async {
    picks++;
    return bytes;
  }

  @override
  Future<BackupExportResult> save(Uint8List bytes, Rect origin) async {
    this.origin = origin;
    return result;
  }
}

Widget _host(_Repository repo, _Files files, {double scale = 1}) =>
    ProviderScope(
      overrides: [
        backupRepositoryProvider.overrideWithValue(repo),
        backupFilesProvider.overrideWithValue(files),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const BackupPage(),
      ),
    );
void main() {
  testWidgets(
    'import shows counts before confirmation, cancellation does not write or reread file',
    (tester) async {
      final repo = _Repository();
      final files = _Files();
      await tester.pumpWidget(_host(repo, files));
      await tester.tap(find.text('导入备份'));
      await tester.pumpAndSettle();
      expect(find.text('收藏：5 项'), findsOneWidget);
      expect(find.textContaining('新增'), findsNothing);
      expect(repo.merges, 0);
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(repo.merges, 0);
      await tester.tap(find.text('导入备份'));
      await tester.pumpAndSettle();
      files.bytes = Uint8List.fromList([9]);
      await tester.tap(find.text('确认合并'));
      await tester.pumpAndSettle();
      expect(repo.accepted, same(repo.imported));
      expect(repo.merges, 1);
      expect(files.picks, 2);
      expect(find.text('备份已合并'), findsOneWidget);
    },
  );
  testWidgets(
    'bad backup does not show confirmation or write, failed read remains retryable',
    (tester) async {
      final repo = _Repository()..invalid = true;
      final files = _Files();
      await tester.pumpWidget(_host(repo, files));
      await tester.tap(find.text('导入备份'));
      await tester.pumpAndSettle();
      expect(find.text('备份内容不完整或已损坏'), findsOneWidget);
      expect(find.text('确认合并'), findsNothing);
      expect(repo.merges, 0);
      files.bytes = null;
      await tester.tap(find.text('导入备份'));
      await tester.pumpAndSettle();
      expect(find.text('已取消导入'), findsOneWidget);
    },
  );
  testWidgets(
    'mobile share outcomes never claim persisted backup and receive a valid iPad origin',
    (tester) async {
      final repo = _Repository();
      final files = _Files();
      await tester.pumpWidget(_host(repo, files));
      for (final entry in {
        BackupExportResult.saved: '备份已保存',
        BackupExportResult.shared: '已交给系统分享',
        BackupExportResult.dismissed: '已取消导出',
        BackupExportResult.unknown: '已打开系统分享，请确认文件是否保存',
      }.entries) {
        files.result = entry.key;
        await tester.tap(find.text('导出备份'));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(files.origin!.width, greaterThan(0));
        expect(files.origin!.height, greaterThan(0));
        if (entry.key != BackupExportResult.saved) {
          expect(find.text('备份已保存'), findsNothing);
        }
      }
    },
  );
  testWidgets(
    'accepted import is single-flight and route stays until transaction finishes',
    (tester) async {
      final repo = _Repository()..mergeGate = Completer<void>();
      final files = _Files();
      await tester.pumpWidget(_host(repo, files));
      await tester.tap(find.text('导入备份'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认合并'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, '导入备份')).enabled,
        isFalse,
      );
      expect(repo.merges, 1);
      repo.mergeGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
      expect(find.text('备份已合并'), findsOneWidget);
    },
  );
  testWidgets('backup confirmation scrolls at narrow width and large text', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(_Repository(), _Files(), scale: 2));
    await tester.tap(find.text('导入备份'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
