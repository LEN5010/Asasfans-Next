import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../domain/bili_account.dart';

enum AccountMode {
  loading,
  guest,
  unverified,
  verified,
  expired,
  storageError,
  logoutPending,
}

enum AccountLoginPhase {
  none,
  creating,
  waiting,
  scanned,
  web,
  checking,
  failed,
  expired,
}

class AccountController extends ChangeNotifier {
  AccountController(this._gateway, this._vault, this._intent, this.cookies);
  final BiliAuthGateway _gateway;
  final BiliCredentialVault _vault;
  final LogoutIntentStore _intent;
  final BiliLoginCookies cookies;
  AccountMode mode = AccountMode.loading;
  AccountLoginPhase loginPhase = AccountLoginPhase.none;
  Object? failure;
  bool busy = false;
  BiliQrTicket? ticket;
  StoredBiliSession? _session;
  BiliAccountProfile? get profile => _session?.profile;
  BiliCredentials? get credentials =>
      mode == AccountMode.verified || mode == AccountMode.unverified
      ? _session?.credentials
      : null;
  int sessionRevision = 0;
  int _generation = 0;
  int get loginGeneration => _generation;
  bool _closed = false;
  bool _foreground = true;
  bool _polling = false;
  Timer? _timer;
  Stopwatch? _qrAge;
  RequestCancellation? _request;
  BiliCredentials? _candidate;
  Future<void> _tail = Future.value();
  Future<void> _browserTail = Future.value();
  Future<void> Function()? _browserCloser;
  bool get loginActive => loginPhase != AccountLoginPhase.none;
  bool get canLogin => mode == AccountMode.guest && !busy;

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  bool _active(int generation) => !_closed && generation == _generation;
  void _notify() {
    if (!_closed) notifyListeners();
  }

  void _cancelRequests() {
    _timer?.cancel();
    _timer = null;
    _request?.cancel();
    _request = null;
    _polling = false;
  }

  Object _failure(Object error) =>
      error is ApiFailure || error is AccountFailure
      ? error
      : const AccountFailure(AccountFailureKind.invalidCredentials);

  Future<void> restore() async {
    if (_closed || busy || loginActive || _session != null) return;
    final generation = ++_generation;
    _cancelRequests();
    mode = AccountMode.loading;
    failure = null;
    busy = true;
    _notify();
    try {
      await cookies.initialize();
      if (!_active(generation)) return;
      if (await _intent.pending()) {
        if (_active(generation)) {
          mode = AccountMode.logoutPending;
          _session = null;
          sessionRevision++;
        }
        return;
      }
      final session = await _serial(_vault.read);
      if (!_active(generation)) return;
      _session = session;
      mode = session == null ? AccountMode.guest : AccountMode.unverified;
      if (session != null) sessionRevision++;
    } catch (error) {
      if (_active(generation)) {
        mode = AccountMode.storageError;
        _session = null;
        failure = _failure(error);
      }
    } finally {
      if (_active(generation)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> verifySession() async {
    final session = _session;
    if (_closed || busy || session == null) return;
    final generation = _generation;
    final cancellation = _request = RequestCancellation();
    busy = true;
    failure = null;
    _notify();
    try {
      final profile = await _gateway.verify(
        session.credentials,
        cancellation: cancellation,
      );
      if (!_active(generation)) return;
      _session = StoredBiliSession(session.credentials, profile);
      if (mode == AccountMode.expired) sessionRevision++;
      mode = AccountMode.verified;
    } catch (error) {
      if (!_active(generation)) return;
      failure = _failure(error);
      if (error is ApiFailure && error.kind == ApiFailureKind.loginRequired) {
        mode = AccountMode.expired;
        sessionRevision++;
      }
      // A timeout, risk response or offline device is not a logout.
    } finally {
      if (_active(generation)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> startQr() async {
    if (!canLogin) return;
    if (loginActive) {
      await cancelLogin();
      if (!canLogin) return;
    }
    final generation = ++_generation;
    _cancelRequests();
    failure = null;
    loginPhase = AccountLoginPhase.creating;
    _notify();
    final cancellation = _request = RequestCancellation();
    try {
      final value = await _gateway.createQr(cancellation: cancellation);
      if (!_active(generation)) return;
      ticket = value;
      _qrAge = Stopwatch()..start();
      loginPhase = AccountLoginPhase.waiting;
      _notify();
      _schedule(generation);
    } catch (error) {
      if (_active(generation)) {
        failure = _failure(error);
        loginPhase = AccountLoginPhase.failed;
        _notify();
      }
    }
  }

  void _schedule(int generation) {
    _timer?.cancel();
    if (!_active(generation) ||
        !_foreground ||
        ticket == null ||
        ![
          AccountLoginPhase.waiting,
          AccountLoginPhase.scanned,
        ].contains(loginPhase)) {
      return;
    }
    _timer = Timer(const Duration(seconds: 2), () => unawaited(pollQr()));
  }

  Future<void> pollQr() async {
    if (_closed ||
        _polling ||
        !_foreground ||
        ticket == null ||
        ![
          AccountLoginPhase.waiting,
          AccountLoginPhase.scanned,
          AccountLoginPhase.failed,
        ].contains(loginPhase)) {
      return;
    }
    _timer?.cancel();
    if (_qrAge!.elapsed >= const Duration(minutes: 3)) {
      loginPhase = AccountLoginPhase.expired;
      _notify();
      return;
    }
    final generation = _generation;
    final current = ticket!;
    _polling = true;
    failure = null;
    final cancellation = _request = RequestCancellation();
    try {
      final result = await _gateway.poll(current, cancellation: cancellation);
      if (!_active(generation)) return;
      switch (result.status) {
        case BiliQrStatus.waiting:
          loginPhase = AccountLoginPhase.waiting;
        case BiliQrStatus.scanned:
          loginPhase = AccountLoginPhase.scanned;
        case BiliQrStatus.expired:
          loginPhase = AccountLoginPhase.expired;
        case BiliQrStatus.confirmed:
          if (result.credentials == null) {
            throw const AccountFailure(AccountFailureKind.invalidCredentials);
          }
          ticket = null;
          _candidate = result.credentials;
          await _finishLogin(generation);
      }
    } catch (error) {
      if (_active(generation)) {
        failure = _failure(error);
        loginPhase = AccountLoginPhase.failed;
      }
    } finally {
      if (_active(generation)) {
        _polling = false;
        _notify();
        _schedule(generation);
      }
    }
  }

  void setForeground(bool value) {
    _foreground = value;
    if (!value) {
      _timer?.cancel();
    } else {
      _schedule(_generation);
    }
  }

  Future<int?> startWeb() async {
    if (!canLogin || !cookies.supportsWebLogin) return null;
    if (loginActive) {
      await cancelLogin();
      if (!canLogin) return null;
    }
    final generation = ++_generation;
    _cancelRequests();
    loginPhase = AccountLoginPhase.web;
    failure = null;
    busy = true;
    _notify();
    try {
      // An embedded browser may persist login cookies before nav verification
      // or a secure-vault commit. A crash here must leave a cleanup obligation.
      await _intent.setPending(true);
      if (!_active(generation)) return null;
      await _clearBrowser();
      if (!_active(generation)) return null;
      return generation;
    } catch (error) {
      if (_active(generation)) {
        failure = _failure(error);
        mode = AccountMode.logoutPending;
        loginPhase = AccountLoginPhase.none;
      }
      return null;
    } finally {
      if (_active(generation)) {
        busy = false;
        _notify();
      }
    }
  }

  void registerBrowserCloser(int generation, Future<void> Function()? closer) {
    if (_active(generation)) _browserCloser = closer;
  }

  Future<bool> completeWeb(int generation, {bool silent = false}) async {
    if (!_active(generation) || loginPhase != AccountLoginPhase.web || busy) {
      return false;
    }
    busy = true;
    failure = null;
    _notify();
    try {
      final value = await cookies.read();
      if (!_active(generation)) return false;
      if (value == null) {
        if (!silent) {
          failure = const AccountFailure(AccountFailureKind.notReady);
        }
        return false;
      }
      try {
        await _clearBrowser();
      } catch (_) {
        if (_active(generation)) {
          mode = AccountMode.logoutPending;
          loginPhase = AccountLoginPhase.none;
          failure = const AccountFailure(AccountFailureKind.cleanup);
        }
        return false;
      }
      if (!_active(generation)) return false;
      _candidate = value;
      await _finishLogin(generation);
      return mode == AccountMode.verified;
    } catch (error) {
      if (_active(generation)) {
        failure = _failure(error);
      }
      return false;
    } finally {
      if (_active(generation)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> retryLogin() async {
    if (_closed || busy) return;
    if (_candidate != null) {
      await _finishLogin(_generation);
      return;
    }
    if (ticket != null) {
      await pollQr();
      return;
    }
    await startQr();
  }

  Future<void> _finishLogin(int generation) async {
    final candidate = _candidate;
    if (candidate == null || !_active(generation)) return;
    loginPhase = AccountLoginPhase.checking;
    busy = true;
    failure = null;
    _timer?.cancel();
    _notify();
    final cancellation = _request = RequestCancellation();
    try {
      final profile = await _gateway.verify(
        candidate,
        cancellation: cancellation,
      );
      if (!_active(generation)) return;
      if (profile.mid != candidate.mid) {
        throw const AccountFailure(AccountFailureKind.invalidCredentials);
      }
      final session = StoredBiliSession(candidate, profile);
      final saved = await _serial(() async {
        if (!_active(generation)) return false;
        try {
          // Until both stores acknowledge the commit, a restart must fail
          // closed rather than revive an abandoned or partly written login.
          await _intent.setPending(true);
          if (!_active(generation)) return false;
          await _vault.write(session);
        } catch (_) {
          // A failing platform write may have partly succeeded. Leave a
          // durable fail-closed intent until explicit cleanup succeeds.
          try {
            await _intent.setPending(true);
          } catch (_) {}
          throw const AccountFailure(AccountFailureKind.storage);
        }
        if (!_active(generation)) {
          await _vault.clear();
          return false;
        }
        await _intent.setPending(false);
        if (!_active(generation)) {
          await _intent.setPending(true);
          await _vault.clear();
          return false;
        }
        return true;
      });
      if (!_active(generation) || !saved) return;
      _session = session;
      _candidate = null;
      ticket = null;
      mode = AccountMode.verified;
      loginPhase = AccountLoginPhase.none;
      sessionRevision++;
    } catch (error) {
      if (!_active(generation)) return;
      failure = _failure(error);
      loginPhase = AccountLoginPhase.failed;
      if (error is AccountFailure && error.kind == AccountFailureKind.storage) {
        mode = AccountMode.logoutPending;
        _candidate = null;
        loginPhase = AccountLoginPhase.none;
      }
    } finally {
      if (_active(generation)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> _clearBrowser() async {
    final work = _browserTail.then((_) async {
      // Take the current closer only when this queued operation starts. A
      // failed stop must remain reachable for a subsequent explicit retry.
      final closer = _browserCloser;
      if (closer != null) await closer();
      if (identical(_browserCloser, closer)) _browserCloser = null;
      await cookies.clear();
    });
    _browserTail = work.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    await work;
  }

  Future<void> cancelLogin({int? generation}) async {
    if (loginActive && (generation == null || generation == _generation)) {
      await logout();
    }
  }

  Future<void> logout() async {
    if (_closed) return;
    final generation = ++_generation;
    _cancelRequests();
    _candidate = null;
    ticket = null;
    _session = null;
    sessionRevision++;
    mode = AccountMode.logoutPending;
    loginPhase = AccountLoginPhase.none;
    busy = true;
    failure = null;
    _notify();
    // Intent is not queued behind a possibly slow keychain write. A restart
    // must not revive credentials after the user has requested local logout.
    final intent = _intent
        .setPending(true)
        .then((_) => true, onError: (Object _, StackTrace _) => false);
    final clear = _serial(
      _vault.clear,
    ).then((_) => true, onError: (Object _, StackTrace _) => false);
    final browser = _clearBrowser().then(
      (_) => true,
      onError: (Object _, StackTrace _) => false,
    );
    final results = await Future.wait([intent, clear, browser]);
    if (!_active(generation)) return;
    try {
      if (!results[1] || !results[2]) {
        throw const AccountFailure(AccountFailureKind.cleanup);
      }
      await _intent.setPending(false);
      if (_active(generation)) mode = AccountMode.guest;
    } catch (_) {
      if (_active(generation)) {
        failure = const AccountFailure(AccountFailureKind.cleanup);
      }
    } finally {
      if (_active(generation)) {
        busy = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _generation++;
    _cancelRequests();
    _candidate = null;
    _session = null;
    super.dispose();
  }
}
