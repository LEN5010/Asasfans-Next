import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/backup/data/backup_codec.dart';
import 'package:asasfans_next/features/backup/data/sqlite_backup_repository.dart';
import 'package:asasfans_next/features/preferences/application/preferences_controller.dart';
import 'package:asasfans_next/features/preferences/data/sqlite_preferences_repository.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/preferences_fixture.dart';
import '../helpers/sqlite_fixture.dart';

class _DelayedMaterial extends MemoryPreferencesRepository {
  final saved = Completer<AppPreferences>();
  @override
  Future<AppPreferences> setMaterial(AppMaterial value) => saved.future;
}

void main() {
  test('material default and copies preserve independent preferences', () {
    const defaults = AppPreferences();
    expect(defaults.material, AppMaterial.liquid);
    final changed = defaults
        .withMaterial(AppMaterial.clear)
        .withAppearance(AppAppearance.dark)
        .withSection(HomeSection.clips, false);
    expect(changed.material, AppMaterial.clear);
    expect(changed.appearance, AppAppearance.dark);
    expect(changed.hiddenHomeSections, {HomeSection.clips});
    expect(changed.withMaterial(AppMaterial.liquid).hiddenHomeSections, {
      HomeSection.clips,
    });
  });

  test('device material is per-key, with no schema or default write', () async {
    final db = MemoryLocalDatabase();
    addTearDown(db.close);
    final prefs = SqlitePreferencesRepository(db);
    expect((await prefs.load()).material, AppMaterial.liquid);
    expect(db.database.select('SELECT * FROM preferences'), isEmpty);
    await prefs.setMaterial(AppMaterial.clear);
    await prefs.setAppearance(AppAppearance.dark);
    await prefs.setHomeSection(HomeSection.fanart, false);
    final loaded = await SqlitePreferencesRepository(db).load();
    expect(loaded.material, AppMaterial.clear);
    expect(loaded.appearance, AppAppearance.dark);
    expect(loaded.hiddenHomeSections, {HomeSection.fanart});
    expect(
      db.database
          .select("SELECT value FROM preferences WHERE key='ui.material'")
          .single['value'],
      'clear',
    );
  });

  test(
    'invalid material stays untouched; unrelated unknown keys are ignored',
    () async {
      final db = MemoryLocalDatabase();
      addTearDown(db.close);
      await db.batch(const [
        SqlStatement('INSERT INTO preferences VALUES (?, ?)', [
          'future.setting',
          'opaque',
        ]),
      ], write: true);
      final prefs = SqlitePreferencesRepository(db);
      expect((await prefs.load()).material, AppMaterial.liquid);
      await db.batch(const [
        SqlStatement('INSERT INTO preferences VALUES (?, ?)', [
          'ui.material',
          'invalid',
        ]),
      ], write: true);
      await expectLater(prefs.load(), throwsA(isA<StorageFailure>()));
      expect(
        db.database
            .select("SELECT value FROM preferences WHERE key='ui.material'")
            .single['value'],
        'invalid',
      );
    },
  );

  test(
    'material applies only after commit and failure retains committed state',
    () async {
      final repository = _DelayedMaterial();
      final controller = PreferencesController(repository);
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      final writing = controller.setMaterial(AppMaterial.clear);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.values.material, AppMaterial.liquid);
      expect(controller.state.saving, isTrue);
      repository.saved.completeError(
        const StorageFailure(StorageFailureKind.unavailable),
      );
      expect(await writing, isFalse);
      expect(controller.state.values.material, AppMaterial.liquid);
      expect(controller.state.canEdit, isTrue);
    },
  );

  test('queued theme, home and material writes preserve each other', () async {
    final controller = PreferencesController(MemoryPreferencesRepository());
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    await Future.wait([
      controller.setMaterial(AppMaterial.clear),
      controller.setAppearance(AppAppearance.dark),
      controller.setHomeSection(HomeSection.clips, false),
    ]);
    expect(controller.state.values.material, AppMaterial.clear);
    expect(controller.state.values.appearance, AppAppearance.dark);
    expect(controller.state.values.hiddenHomeSections, {HomeSection.clips});
  });

  for (final version in [1, BackupCodec.formatVersion]) {
    test(
      'v$version portable backup never exports or overwrites device material',
      () async {
        final source = MemoryLocalDatabase(), target = MemoryLocalDatabase();
        addTearDown(source.close);
        addTearDown(target.close);
        await SqlitePreferencesRepository(
          source,
        ).setMaterial(AppMaterial.liquid);
        await SqlitePreferencesRepository(
          source,
        ).setAppearance(AppAppearance.dark);
        await SqlitePreferencesRepository(
          target,
        ).setMaterial(AppMaterial.clear);
        final exported = await SqliteBackupRepository(
          source,
          onCommitted: () {},
        ).export();
        expect(utf8.decode(exported), isNot(contains('ui.material')));
        final map = jsonDecode(utf8.decode(exported)) as Map<String, dynamic>;
        if (version == 1) {
          // A genuine old-format preference-only backup, not a v6 table set
          // mislabeled as v1.
          map['version'] = 1;
          map['data'] = {
            for (final key in BackupCodec.columnsV1.keys)
              key: (map['data'] as Map)[key],
          };
        }
        final backup = SqliteBackupRepository(target, onCommitted: () {});
        await backup.merge(
          await backup.inspect(
            Uint8List.fromList(utf8.encode(jsonEncode(map))),
          ),
        );
        final restored = await SqlitePreferencesRepository(target).load();
        expect(restored.material, AppMaterial.clear);
        expect(restored.appearance, AppAppearance.dark);
        expect(BackupCodec.preferenceKeys, isNot(contains('ui.material')));
      },
    );
  }
}
