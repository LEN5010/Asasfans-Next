import 'package:flutter/foundation.dart';
import '../../../core/storage/local_database.dart';
import '../../library/data/cloud_collections.dart';
import '../domain/main_account.dart';
import '../data/main_account_api.dart';

/// Asked once per account, the first time it has a verified address on this
/// device: true copies the visitor collections into the account.
typedef ImportChoice = Future<bool> Function();

/// Native sign-in against dynamic_asoul. Collections switch to the account
/// only once it has a verified email; until then the visitor library stays.
class MainAccountController extends ChangeNotifier {
  MainAccountController(this.api, this.vault, this.db);
  final MainAccountApi api;
  final MainCredentialVault vault;
  final LocalDatabase db;
  MainSession? session;
  bool loading = true;
  bool busy = false;
  String? error;
  bool _closed = false;
  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> restore() async {
    try {
      session = await vault.read();
    } catch (_) {
      error = '无法读取账号凭据，请重新登录';
    }
    loading = false;
    _notify();
  }

  /// Runs one account action; false when it failed and [error] says why.
  Future<bool> _run(Future<void> Function() action, String fallback) async {
    if (busy || loading) return false;
    busy = true;
    error = null;
    _notify();
    final token = session?.token;
    try {
      await action();
      return true;
    } on MainAccountFailure catch (failure) {
      if (failure.expired && token != null && session?.token == token) {
        await _clear('登录已过期，请重新登录');
      } else {
        error = failure.message;
      }
      return false;
    } catch (_) {
      error = fallback;
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _accept(MainSession value, ImportChoice chooseImport) async {
    if (value.user.email != null) {
      final collections = CloudCollections(db, value.user.id);
      if (!await collections.initialized()) {
        await collections.initialize(importLocal: await chooseImport());
      }
    }
    await vault.write(value);
    session = value;
  }

  Future<bool> login(
    String account,
    String password,
    ImportChoice chooseImport,
  ) => _run(
    () async => _accept(await api.login(account, password), chooseImport),
    '登录未完成，请重试',
  );

  /// Creates the account and sends the first code to [email].
  Future<bool> register(String username, String email, String password) =>
      _run(() async {
        final issued = await api.register(username, password);
        await vault.write(issued);
        session = issued;
        await api.sendEmailCode(issued.token, email);
      }, '注册未完成，请重试');

  Future<bool> sendEmailCode(String email, {String? currentPassword}) => _run(
    () => api.sendEmailCode(
      session!.token,
      email,
      currentPassword: currentPassword,
    ),
    '验证码发送失败，请重试',
  );

  Future<bool> verifyEmail(String code, ImportChoice chooseImport) =>
      _run(() async {
        final current = session!;
        final email = await api.verifyEmail(current.token, code);
        await _accept(
          MainSession(
            current.token,
            MainUser(current.user.id, current.user.username, email: email),
          ),
          chooseImport,
        );
      }, '验证未完成，请重试');

  /// Picks up an address verified elsewhere, such as on the website.
  Future<bool> refresh(ImportChoice chooseImport) => _run(() async {
    final current = session!;
    await _accept(
      MainSession(current.token, await api.me(current.token)),
      chooseImport,
    );
  }, '账号状态读取失败，请重试');

  Future<bool> requestPasswordReset(String account) =>
      _run(() => api.requestPasswordReset(account), '验证码发送失败，请重试');

  Future<bool> confirmPasswordReset(
    String account,
    String code,
    String newPassword,
  ) => _run(
    () => api.confirmPasswordReset(account, code, newPassword),
    '密码重设未完成，请重试',
  );

  Future<bool> logout() => _run(() async {
    try {
      await api.revoke(session!.token);
    } on MainAccountFailure catch (failure) {
      if (!failure.expired) rethrow;
    }
    await vault.clear();
    session = null;
  }, '退出登录未完成，请重试');

  /// A 401 from any account request returns this device to the visitor.
  Future<void> expire(String token) async {
    if (session?.token != token) return;
    await _clear('登录已过期，请重新登录');
    _notify();
  }

  Future<void> _clear(String message) async {
    session = null;
    error = message;
    try {
      await vault.clear();
    } catch (_) {
      error = '$message；账号凭据清除失败';
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
