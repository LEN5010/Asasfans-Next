import 'dart:io';
import 'package:flutter/services.dart';

import '../domain/bili_account.dart';

/// Clears the isolated browser store the retired web sign-in wrote into.
///
/// The probe keeps its old meaning: a failed probe is an unfinished cleanup,
/// while a store the platform declares unavailable was never opened and has
/// nothing to clear.
class PlatformLoginCookies implements BiliLoginCookies {
  PlatformLoginCookies({bool? supportedHost})
    : _supportedHost =
          supportedHost ??
          (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
  static const _channel = MethodChannel('asasfans.next/bilibili_login_cookies');
  final bool _supportedHost;

  @override
  Future<void> clear() async {
    if (!_supportedHost) return;
    try {
      final available = await _channel.invokeMethod<bool>('available');
      if (available == null) throw const FormatException();
      if (!available) return;
      if (await _channel.invokeMethod<bool>('clear') != true) {
        throw const AccountFailure(AccountFailureKind.cleanup);
      }
    } catch (_) {
      throw const AccountFailure(AccountFailureKind.cleanup);
    }
  }
}
