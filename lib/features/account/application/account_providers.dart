import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../data/platform_login_cookies.dart';
import '../data/secure_bili_vault.dart';
import '../domain/bili_account.dart';
import 'account_controller.dart';

final biliVaultProvider = Provider<BiliCredentialVault>(
  (ref) => SecureBiliVault(PlatformBiliKeyStore()),
);
final logoutIntentProvider = Provider<LogoutIntentStore>(
  (ref) => SqliteLogoutIntentStore(ref.watch(localDatabaseProvider)),
);
final biliLoginCookiesProvider = Provider<BiliLoginCookies>(
  (ref) => PlatformLoginCookies(),
);
final accountControllerProvider = ChangeNotifierProvider<AccountController>((
  ref,
) {
  final controller = AccountController(
    ref.watch(biliVaultProvider),
    ref.watch(logoutIntentProvider),
    ref.watch(biliLoginCookiesProvider),
  );
  unawaited(controller.restore());
  return controller;
});
