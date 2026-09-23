import 'package:flutter/foundation.dart';

import '../domain/bili_account.dart';

enum AccountMode {
  loading,

  /// Nothing from the retired sign-in is left on this device.
  none,
  stored,
  storageError,

  /// A cleanup was started and has not been confirmed complete.
  logoutPending,
}

/// Finds a Bilibili session an earlier build stored and removes it when asked.
///
/// Nothing is removed without the user asking: a stored session or a pending
/// cleanup is only reported until [clear] runs.
class AccountController extends ChangeNotifier {
  AccountController(this._vault, this._intent, this._cookies);
  final BiliCredentialVault _vault;
  final LogoutIntentStore _intent;
  final BiliLoginCookies _cookies;
  AccountMode mode = AccountMode.loading;
  AccountFailure? failure;
  bool busy = false;
  bool _closed = false;

  bool get hasLocalLogin =>
      mode == AccountMode.stored ||
      mode == AccountMode.storageError ||
      mode == AccountMode.logoutPending;

  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> restore() async {
    if (_closed || busy) return;
    busy = true;
    failure = null;
    _notify();
    try {
      mode = await _intent.pending()
          ? AccountMode.logoutPending
          : await _vault.stored()
          ? AccountMode.stored
          : AccountMode.none;
    } on AccountFailure catch (error) {
      mode = AccountMode.storageError;
      failure = error;
    } finally {
      busy = false;
      _notify();
    }
  }

  /// The intent is committed before anything is deleted, so an interrupted
  /// cleanup is still reported after a restart instead of reviving the
  /// credentials. It is withdrawn only once every store confirms the removal.
  Future<void> clear() async {
    if (_closed || busy) return;
    busy = true;
    failure = null;
    _notify();
    try {
      await _intent.setPending(true);
      mode = AccountMode.logoutPending;
      await _vault.clear();
      await _cookies.clear();
      await _intent.setPending(false);
      mode = AccountMode.none;
    } on AccountFailure catch (error) {
      failure = error;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
