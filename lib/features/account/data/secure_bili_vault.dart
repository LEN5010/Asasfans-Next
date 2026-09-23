import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/local_database.dart';
import '../domain/bili_account.dart';

abstract interface class SecretKeyStore {
  Future<String?> read();
  Future<void> delete();
}

class PlatformBiliKeyStore implements SecretKeyStore {
  static const _key = 'asasfans.flutter.bilibili.session.v1';
  static const _store = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: false,
      sharedPreferencesName: 'asasfans_flutter_bilibili',
      preferencesKeyPrefix: 'asasfans_flutter_',
    ),
    iOptions: IOSOptions(
      accountName: 'asasfans.flutter.bilibili',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    ),
    mOptions: MacOsOptions(
      accountName: 'asasfans.flutter.bilibili',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    ),
  );
  @override
  Future<String?> read() => _store.read(key: _key);
  @override
  Future<void> delete() => _store.delete(key: _key);
}

/// The session envelope an earlier build wrote. It is no longer parsed:
/// whatever sits under the key, well-formed or not, is only there to be removed.
class SecureBiliVault implements BiliCredentialVault {
  SecureBiliVault(this._store);
  final SecretKeyStore _store;
  @override
  Future<bool> stored() async {
    try {
      return await _store.read() != null;
    } catch (_) {
      throw const AccountFailure(AccountFailureKind.storage);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _store.delete();
      if (await _store.read() != null) {
        throw const AccountFailure(AccountFailureKind.cleanup);
      }
    } catch (_) {
      throw const AccountFailure(AccountFailureKind.cleanup);
    }
  }
}

/// Non-secret fail-closed intent, deliberately outside the portable preference
/// allowlist. No cookies or account identifiers enter SQLite.
class SqliteLogoutIntentStore implements LogoutIntentStore {
  SqliteLogoutIntentStore(this._db);
  final LocalDatabase _db;
  static const _key = 'bilibili.logout_pending';
  @override
  Future<bool> pending() async {
    try {
      final rows = (await _db.batch([
        const SqlStatement('SELECT value FROM preferences WHERE key=?', [
          _key,
        ], true),
      ])).single;
      if (rows.isEmpty) return false;
      if (rows.single['value'] != 'true') {
        throw const AccountFailure(AccountFailureKind.storage);
      }
      return true;
    } catch (_) {
      throw const AccountFailure(AccountFailureKind.storage);
    }
  }

  @override
  Future<void> setPending(bool value) async {
    try {
      await _db.batch([
        value
            ? const SqlStatement(
                "INSERT INTO preferences VALUES(?,'true') ON CONFLICT(key) DO UPDATE SET value='true'",
                [_key],
              )
            : const SqlStatement('DELETE FROM preferences WHERE key=?', [_key]),
      ], write: true);
    } catch (_) {
      throw const AccountFailure(AccountFailureKind.storage);
    }
  }
}
