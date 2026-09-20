import 'dart:io';
import 'package:flutter/services.dart';

import '../domain/bili_account.dart';

class PlatformLoginCookies implements BiliLoginCookies {
  PlatformLoginCookies({bool? supportedHost})
    : _hostSupports = supportedHost ?? _platformSupports,
      _supported = supportedHost ?? _platformSupports;
  static const _channel = MethodChannel('asasfans.next/bilibili_login_cookies');
  static final bool _platformSupports =
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  final bool _hostSupports;
  bool _supported;
  bool _probeFailed = false;
  @override
  bool get supportsWebLogin => _supported;
  @override
  Future<void> initialize() async {
    if (!_hostSupports) return;
    try {
      final available = await _channel.invokeMethod<bool>('available');
      if (available == null) throw const FormatException();
      _supported = available;
      _probeFailed = false;
    } catch (_) {
      _supported = false;
      _probeFailed = true;
    }
  }

  @override
  Future<void> stopNavigation({required int webViewId}) async {
    if (_probeFailed) throw const AccountFailure(AccountFailureKind.cleanup);
    if (!supportsWebLogin) return;
    try {
      if (await _channel.invokeMethod<bool>('stop', {'webViewId': webViewId}) !=
          true) {
        throw const AccountFailure(AccountFailureKind.cleanup);
      }
    } catch (_) {
      throw const AccountFailure(AccountFailureKind.cleanup);
    }
  }

  @override
  Future<BiliCredentials?> read() async {
    if (!supportsWebLogin) {
      throw const AccountFailure(AccountFailureKind.webLogin);
    }
    try {
      final entries = await _channel.invokeListMethod<Object?>('read');
      if (entries == null || entries.length > 128) {
        throw const FormatException();
      }
      final values = <String, String>{};
      for (final entry in entries) {
        if (entry is! Map ||
            entry['name'] is! String ||
            entry['value'] is! String) {
          throw const FormatException();
        }
        final name = entry['name'] as String;
        final value = entry['value'] as String;
        if (!BiliCredentials.cookieNames.contains(name)) continue;
        if (values[name] != null && values[name] != value) {
          throw const FormatException();
        }
        values[name] = value;
      }
      if (!values.containsKey('SESSDATA') ||
          !values.containsKey('bili_jct') ||
          !values.containsKey('DedeUserID')) {
        return null;
      }
      return BiliCredentials(values);
    } catch (_) {
      throw const AccountFailure(AccountFailureKind.webLogin);
    }
  }

  @override
  Future<void> clear() async {
    await initialize();
    if (_probeFailed) throw const AccountFailure(AccountFailureKind.cleanup);
    if (!supportsWebLogin) return;
    try {
      if (await _channel.invokeMethod<bool>('clear') != true) {
        throw const AccountFailure(AccountFailureKind.cleanup);
      }
    } catch (_) {
      throw const AccountFailure(AccountFailureKind.cleanup);
    }
  }
}
