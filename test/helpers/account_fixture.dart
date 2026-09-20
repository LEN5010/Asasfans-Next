import 'dart:async';
import 'package:asasfans_next/features/account/application/account_controller.dart';
import 'package:asasfans_next/features/account/application/account_providers.dart';
import 'package:asasfans_next/features/account/domain/bili_account.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

BiliCredentials accountCredentials({String mid = '123'}) => BiliCredentials({
  'SESSDATA': 'fixture-session',
  'bili_jct': '0123456789abcdef0123456789abcdef',
  'DedeUserID': mid,
});
StoredBiliSession accountSession() => StoredBiliSession(
  accountCredentials(),
  const BiliAccountProfile(mid: '123', name: '测试账号'),
);
BiliQrTicket accountTicket() => BiliQrTicket(
  key: '0123456789abcdef0123456789abcdef',
  url: Uri.parse(
    'https://passport.bilibili.com/h5-app/passport/login/scan?qrcode_key=0123456789abcdef0123456789abcdef',
  ),
);

class MemoryAccountVault implements BiliCredentialVault {
  StoredBiliSession? value;
  Object? readError, writeError, clearError;
  Future<void> Function()? duringWrite;
  int reads = 0, writes = 0, clears = 0;
  @override
  Future<StoredBiliSession?> read() async {
    reads++;
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> write(StoredBiliSession session) async {
    writes++;
    await duringWrite?.call();
    value = session;
    if (writeError != null) throw writeError!;
  }

  @override
  Future<void> clear() async {
    clears++;
    if (clearError != null) throw clearError!;
    value = null;
  }
}

class MemoryLogoutIntent implements LogoutIntentStore {
  bool value = false;
  Object? error;
  @override
  Future<bool> pending() async {
    if (error != null) throw error!;
    return value;
  }

  @override
  Future<void> setPending(bool pending) async {
    if (error != null) throw error!;
    value = pending;
  }
}

class MemoryLoginCookies implements BiliLoginCookies {
  MemoryLoginCookies({this.supportsWebLogin = false});
  @override
  final bool supportsWebLogin;
  BiliCredentials? candidate;
  Object? clearError;
  int clears = 0;
  @override
  Future<void> initialize() async {}
  @override
  Future<BiliCredentials?> read() async => candidate;
  @override
  Future<void> stopNavigation({required int webViewId}) async {}
  @override
  Future<void> clear() async {
    clears++;
    if (clearError != null) throw clearError!;
    candidate = null;
  }
}

class OfflineAuthGateway implements BiliAuthGateway {
  Object? verifyError;
  Future<BiliAccountProfile> Function(BiliCredentials, RequestCancellation?)?
  verifier;
  Future<BiliQrTicket> Function(RequestCancellation?)? generator;
  Future<BiliQrResult> Function(RequestCancellation?)? poller;
  int polls = 0, verifications = 0;
  @override
  Future<BiliQrTicket> createQr({RequestCancellation? cancellation}) async =>
      generator == null ? accountTicket() : await generator!(cancellation);
  @override
  Future<BiliQrResult> poll(
    BiliQrTicket ticket, {
    RequestCancellation? cancellation,
  }) async {
    polls++;
    return poller == null
        ? BiliQrResult(
            BiliQrStatus.confirmed,
            credentials: accountCredentials(),
          )
        : await poller!(cancellation);
  }

  @override
  Future<BiliAccountProfile> verify(
    BiliCredentials credentials, {
    RequestCancellation? cancellation,
  }) async {
    verifications++;
    if (verifyError != null) throw verifyError!;
    return verifier == null
        ? BiliAccountProfile(mid: credentials.mid, name: '测试账号')
        : await verifier!(credentials, cancellation);
  }
}

Override offlineAccount() => accountControllerProvider.overrideWith((ref) {
  final controller = AccountController(
    OfflineAuthGateway(),
    MemoryAccountVault(),
    MemoryLogoutIntent(),
    MemoryLoginCookies(),
  );
  unawaited(controller.restore());
  return controller;
});
