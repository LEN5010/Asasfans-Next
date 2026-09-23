import 'dart:convert';
import 'package:asasfans_next/features/account/data/secure_bili_vault.dart';
import 'package:asasfans_next/features/account/domain/bili_account.dart';
import 'package:asasfans_next/features/backup/data/sqlite_backup_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/sqlite_fixture.dart';

class _Secrets implements SecretKeyStore {
  String? value;
  bool ignoreDelete = false;
  bool failRead = false;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('native private detail');
    return value;
  }

  @override
  Future<void> delete() async {
    if (!ignoreDelete) value = null;
  }
}

void main() {
  test('any stored envelope counts, whatever its shape, and clears', () async {
    final keys = _Secrets();
    final vault = SecureBiliVault(keys);
    expect(await vault.stored(), isFalse);
    keys.value = '{"v":99,"private":"do not leak"}';
    expect(await vault.stored(), isTrue);
    await vault.clear();
    expect(keys.value, isNull);
    expect(await vault.stored(), isFalse);
  });
  test('platform errors and failed deletion are sanitized', () async {
    final keys = _Secrets()..value = 'stored';
    final vault = SecureBiliVault(keys);
    keys.ignoreDelete = true;
    await expectLater(
      vault.clear(),
      throwsA(
        isA<AccountFailure>().having(
          (e) => e.kind,
          'kind',
          AccountFailureKind.cleanup,
        ),
      ),
    );
    keys.failRead = true;
    await expectLater(
      vault.stored(),
      throwsA(
        isA<AccountFailure>().having(
          (e) => e.toString(),
          'redacted',
          isNot(contains('native private')),
        ),
      ),
    );
  });
  test(
    'logout intent persists separately but is excluded from ordinary backups',
    () async {
      final db = MemoryLocalDatabase();
      addTearDown(db.close);
      final intent = SqliteLogoutIntentStore(db);
      expect(await intent.pending(), isFalse);
      await intent.setPending(true);
      expect(await SqliteLogoutIntentStore(db).pending(), isTrue);
      final bytes = await SqliteBackupRepository(
        db,
        onCommitted: () {},
      ).export();
      expect(utf8.decode(bytes), isNot(contains('bilibili.logout_pending')));
      expect(utf8.decode(bytes), isNot(contains('SESSDATA')));
      await intent.setPending(false);
      expect(await intent.pending(), isFalse);
    },
  );
}
