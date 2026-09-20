import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../data/bili_auth_client.dart';
import '../data/platform_login_cookies.dart';
import '../data/secure_bili_vault.dart';
import '../domain/bili_account.dart';
import 'account_controller.dart';

final biliAuthGatewayProvider = Provider<BiliAuthGateway>((ref) {
  final client = BiliAuthClient(clock: ref.watch(currentTimeProvider));
  ref.onDispose(client.close);
  return client;
});
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
    ref.watch(biliAuthGatewayProvider),
    ref.watch(biliVaultProvider),
    ref.watch(logoutIntentProvider),
    ref.watch(biliLoginCookiesProvider),
  );
  final lifecycle = AppLifecycleListener(
    onResume: () => controller.setForeground(true),
    onPause: () => controller.setForeground(false),
    onInactive: () => controller.setForeground(false),
  );
  ref.onDispose(lifecycle.dispose);
  unawaited(controller.restore());
  return controller;
});
final accountSessionRevisionProvider = Provider<int>(
  (ref) => ref.watch(accountControllerProvider).sessionRevision,
);
