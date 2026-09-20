import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/domain/bilibili_id.dart';
import '../../../core/storage/local_database.dart';
import '../domain/bili_account.dart';

abstract interface class SecretKeyStore {
  Future<String?> read();
  Future<void> write(String value);
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
  Future<void> write(String value) => _store.write(key: _key, value: value);
  @override
  Future<void> delete() => _store.delete(key: _key);
}

class SecureBiliVault implements BiliCredentialVault {
  SecureBiliVault(this._store);
  final SecretKeyStore _store;
  @override
  Future<StoredBiliSession?> read() async {
    try {
      final raw = await _store.read();
      if (raw == null) return null;
      if (raw.length > 40000) {
        throw const AccountFailure(AccountFailureKind.storage);
      }
      final value = jsonDecode(raw);
      if (value is! Map ||
          value['v'] != 1 ||
          value['cookies'] is! Map ||
          value['profile'] is! Map) {
        throw const AccountFailure(AccountFailureKind.storage);
      }
      final credentials = BiliCredentials(
        Map<String, String>.from(value['cookies'] as Map),
        refreshToken: value['refreshToken'] as String?,
      );
      final profile = value['profile'] as Map;
      if (profile['mid'] != credentials.mid ||
          !validBilibiliMid(profile['mid'] as String) ||
          profile['name'] is! String ||
          (profile['name'] as String).trim().isEmpty ||
          (profile['name'] as String).length > 1000) {
        throw const AccountFailure(AccountFailureKind.storage);
      }
      final avatar = Uri.tryParse(profile['avatar'] as String? ?? '');
      return StoredBiliSession(
        credentials,
        BiliAccountProfile(
          mid: credentials.mid,
          name: profile['name'] as String,
          avatar:
              avatar?.scheme == 'https' &&
                  avatar!.host.isNotEmpty &&
                  avatar.userInfo.isEmpty &&
                  avatar.toString().length <= 4096
              ? avatar
              : null,
        ),
      );
    } catch (_) {
      throw const AccountFailure(AccountFailureKind.storage);
    }
  }

  @override
  Future<void> write(StoredBiliSession session) async {
    try {
      if (session.profile.mid != session.credentials.mid ||
          session.profile.name.trim().isEmpty ||
          session.profile.name.length > 1000) {
        throw const AccountFailure(AccountFailureKind.storage);
      }
      final raw = jsonEncode({
        'v': 1,
        'cookies': session.credentials.cookies,
        'refreshToken': session.credentials.refreshToken,
        'profile': {
          'mid': session.profile.mid,
          'name': session.profile.name,
          'avatar': session.profile.avatar?.toString(),
        },
      });
      await _store.write(raw);
      if (await _store.read() != raw) {
        throw const AccountFailure(AccountFailureKind.storage);
      }
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
