import '../../../core/bilibili/bili_credentials.dart';
import '../../../core/domain/request_cancellation.dart';

export '../../../core/bilibili/bili_credentials.dart';
export '../../../core/domain/request_cancellation.dart';

class BiliAccountProfile {
  const BiliAccountProfile({
    required this.mid,
    required this.name,
    this.avatar,
  });
  final String mid;
  final String name;
  final Uri? avatar;
}

class StoredBiliSession {
  const StoredBiliSession(this.credentials, this.profile);
  final BiliCredentials credentials;
  final BiliAccountProfile profile;
  @override
  String toString() => 'StoredBiliSession(redacted)';
}

class BiliQrTicket {
  const BiliQrTicket({required this.key, required this.url});
  final String key;
  final Uri url;
  @override
  String toString() => 'BiliQrTicket(redacted)';
}

enum BiliQrStatus { waiting, scanned, expired, confirmed }

class BiliQrResult {
  const BiliQrResult(this.status, {this.credentials});
  final BiliQrStatus status;
  final BiliCredentials? credentials;
  @override
  String toString() => 'BiliQrResult(${status.name}, redacted)';
}

abstract interface class BiliAuthGateway {
  Future<BiliQrTicket> createQr({RequestCancellation? cancellation});
  Future<BiliQrResult> poll(
    BiliQrTicket ticket, {
    RequestCancellation? cancellation,
  });
  Future<BiliAccountProfile> verify(
    BiliCredentials credentials, {
    RequestCancellation? cancellation,
  });
}

abstract interface class BiliCredentialVault {
  Future<StoredBiliSession?> read();
  Future<void> write(StoredBiliSession session);
  Future<void> clear();
}

abstract interface class LogoutIntentStore {
  Future<bool> pending();
  Future<void> setPending(bool value);
}

abstract interface class BiliLoginCookies {
  bool get supportsWebLogin;
  Future<void> initialize();
  Future<void> stopNavigation({required int webViewId});
  Future<BiliCredentials?> read();
  Future<void> clear();
}

enum AccountFailureKind {
  storage,
  invalidCredentials,
  cleanup,
  notReady,
  webLogin,
}

class AccountFailure implements Exception {
  const AccountFailure(this.kind);
  final AccountFailureKind kind;
  String get message => switch (kind) {
    AccountFailureKind.storage => '账号安全存储暂不可用，请重试',
    AccountFailureKind.invalidCredentials => '登录信息无效，请重新登录',
    AccountFailureKind.cleanup => '退出清理未完成，请重试',
    AccountFailureKind.notReady => '账号尚未就绪',
    AccountFailureKind.webLogin => '登录页面暂不可用，请重试',
  };
  @override
  String toString() => 'AccountFailure(${kind.name})';
}
