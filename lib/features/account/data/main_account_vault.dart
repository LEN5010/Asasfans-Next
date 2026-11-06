import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/main_account.dart';

class MainAccountVault implements MainCredentialVault {
  static const _key = 'asasfans.main.session.v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: false,
      sharedPreferencesName: 'asasfans_main_account',
      preferencesKeyPrefix: 'asasfans_main_',
    ),
    iOptions: IOSOptions(
      accountName: 'asasfans.main',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    ),
    // Login Keychain also supports the app's ad-hoc signed macOS builds.
    mOptions: MacOsOptions(
      accountName: 'asasfans.main',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
      useDataProtectionKeyChain: false,
    ),
  );
  @override
  Future<MainSession?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    final json = jsonDecode(value) as Map<String, dynamic>;
    return MainSession(
      json['token'] as String,
      MainUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<void> write(MainSession session) => _storage.write(
    key: _key,
    value: jsonEncode({'token': session.token, 'user': session.user.toJson()}),
  );
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
