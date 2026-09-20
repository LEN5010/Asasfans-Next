import 'dart:convert';
import 'package:asasfans_next/features/account/data/secure_bili_vault.dart';
import 'package:asasfans_next/features/account/domain/bili_account.dart';
import 'package:asasfans_next/features/backup/data/sqlite_backup_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/account_fixture.dart';
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
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> delete() async {
    if (!ignoreDelete) value = null;
  }
}

void main() {
  test(
    'single encrypted envelope round-trips without exposing secrets through toString',
    () async {
      final keys = _Secrets();
      final vault = SecureBiliVault(keys);
      await vault.write(accountSession());
      final read = await vault.read();
      expect(read?.credentials.mid, '123');
      expect(read?.profile.name, '测试账号');
      expect(read.toString(), isNot(contains('fixture-session')));
      expect(read!.credentials.toString(), isNot(contains('fixture-session')));
      await vault.clear();
      expect(await vault.read(), isNull);
    },
  );
  test(
    'unknown version is retained; platform errors and failed deletion are sanitized',
    () async {
      final keys = _Secrets()..value = '{"v":99,"private":"do not leak"}';
      final vault = SecureBiliVault(keys);
      await expectLater(vault.read(), throwsA(isA<AccountFailure>()));
      expect(keys.value, isNotNull);
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
        vault.read(),
        throwsA(
          isA<AccountFailure>().having(
            (e) => e.toString(),
            'redacted',
            isNot(contains('native private')),
          ),
        ),
      );
    },
  );
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
  test('cookies can only be assembled for the trusted HTTPS metadata host', () {
    final credentials = accountCredentials();
    expect(
      credentials.metadataHeader(
        Uri.parse('https://api.bilibili.com/x/web-interface/nav'),
      ),
      contains('SESSDATA=fixture-session'),
    );
    for (final uri in [
      'http://api.bilibili.com/x',
      'https://api.bilibili.com.evil.test/x',
      'https://api.bilibili.com:444/x',
      'https://u@api.bilibili.com/x',
      'https://cdn.hdslb.com/x',
      'https://asoul.love/calendar.ics',
    ]) {
      expect(credentials.metadataHeader(Uri.parse(uri)), isNull);
    }
    for (final value in ['x\r\nInjected: yes', 'x;y', 'x,y', 'x"y', 'x\\y']) {
      expect(
        () => BiliCredentials({...credentials.cookies, 'SESSDATA': value}),
        throwsFormatException,
      );
    }
  });
}
