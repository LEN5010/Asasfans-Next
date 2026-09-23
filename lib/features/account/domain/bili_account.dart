/// What is left of the retired Bilibili sign-in: enough to find a session an
/// earlier build stored on this device and to remove it on request.
abstract interface class BiliCredentialVault {
  Future<bool> stored();
  Future<void> clear();
}

abstract interface class LogoutIntentStore {
  Future<bool> pending();
  Future<void> setPending(bool value);
}

/// The embedded browser store the retired web sign-in wrote its cookies into.
abstract interface class BiliLoginCookies {
  Future<void> clear();
}

enum AccountFailureKind { storage, cleanup }

class AccountFailure implements Exception {
  const AccountFailure(this.kind);
  final AccountFailureKind kind;
  String get message => switch (kind) {
    AccountFailureKind.storage => '账号安全存储暂不可用，请重试',
    AccountFailureKind.cleanup => '清除未完成，请重试',
  };
  @override
  String toString() => 'AccountFailure(${kind.name})';
}
