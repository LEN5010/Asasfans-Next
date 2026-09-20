import 'dart:async';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/account/application/account_controller.dart';
import 'package:asasfans_next/features/account/domain/bili_account.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/account_fixture.dart';

void main() {
  late OfflineAuthGateway gateway;
  late MemoryAccountVault vault;
  late MemoryLogoutIntent intent;
  late MemoryLoginCookies cookies;
  late AccountController controller;
  setUp(() {
    gateway = OfflineAuthGateway();
    vault = MemoryAccountVault();
    intent = MemoryLogoutIntent();
    cookies = MemoryLoginCookies(supportsWebLogin: true);
    controller = AccountController(gateway, vault, intent, cookies);
  });
  tearDown(() => controller.dispose());
  test(
    'restored credentials stay unverified, network failure is not logout, explicit expiry revokes runtime use',
    () async {
      vault.value = accountSession();
      await controller.restore();
      expect(controller.mode, AccountMode.unverified);
      expect(gateway.verifications, 0);
      gateway.verifyError = const ApiFailure(ApiFailureKind.offline);
      await controller.verifySession();
      expect(controller.credentials, isNotNull);
      expect(vault.value, isNotNull);
      expect(controller.mode, AccountMode.unverified);
      gateway.verifyError = const ApiFailure(ApiFailureKind.riskControl);
      await controller.verifySession();
      expect(controller.credentials, isNotNull);
      gateway.verifyError = const ApiFailure(ApiFailureKind.loginRequired);
      await controller.verifySession();
      expect(controller.mode, AccountMode.expired);
      expect(controller.credentials, isNull);
      expect(vault.value, isNotNull);
    },
  );
  test('durable pending intent prevents vault reads after restart', () async {
    vault.value = accountSession();
    intent.value = true;
    await controller.restore();
    expect(vault.reads, 0);
    expect(controller.mode, AccountMode.logoutPending);
    expect(controller.credentials, isNull);
    await controller.logout();
    expect(controller.mode, AccountMode.guest);
    expect(vault.value, isNull);
    expect(intent.value, isFalse);
  });
  test(
    'QR confirmation verifies and persists before reporting signed in',
    () async {
      await controller.restore();
      await controller.startQr();
      expect(controller.loginPhase, AccountLoginPhase.waiting);
      final pending = Completer<void>();
      vault.duringWrite = () => pending.future;
      final login = controller.pollQr();
      await Future<void>.delayed(Duration.zero);
      expect(intent.value, isTrue);
      expect(controller.mode, AccountMode.guest);
      expect(controller.credentials, isNull);
      pending.complete();
      await login;
      expect(controller.mode, AccountMode.verified);
      expect(vault.value, isNotNull);
      expect(intent.value, isFalse);
      expect(controller.ticket, isNull);
    },
  );
  test(
    'a partially successful secure write fails closed and must clean up',
    () async {
      vault.writeError = const AccountFailure(AccountFailureKind.storage);
      await controller.restore();
      await controller.startQr();
      await controller.pollQr();
      expect(vault.value, isNotNull);
      expect(intent.value, isTrue);
      expect(controller.mode, AccountMode.logoutPending);
      expect(controller.credentials, isNull);
      await controller.logout();
      expect(vault.value, isNull);
      expect(intent.value, isFalse);
      expect(controller.mode, AccountMode.guest);
    },
  );
  test(
    'logout during slow login write revokes immediately and cleans the late write',
    () async {
      await controller.restore();
      await controller.startQr();
      final pending = Completer<void>();
      vault.duringWrite = () => pending.future;
      final login = controller.pollQr();
      await Future<void>.delayed(Duration.zero);
      final logout = controller.logout();
      expect(controller.credentials, isNull);
      expect(controller.mode, AccountMode.logoutPending);
      await Future<void>.delayed(Duration.zero);
      expect(intent.value, isTrue);
      pending.complete();
      await Future.wait([login, logout]);
      expect(vault.value, isNull);
      expect(controller.mode, AccountMode.guest);
      expect(intent.value, isFalse);
    },
  );
  test(
    'delete and browser failure do not claim logout success; retry survives restart',
    () async {
      vault.value = accountSession();
      await controller.restore();
      vault.clearError = const AccountFailure(AccountFailureKind.cleanup);
      await controller.logout();
      expect(controller.mode, AccountMode.logoutPending);
      expect(controller.credentials, isNull);
      expect(intent.value, isTrue);
      vault.clearError = null;
      cookies.clearError = const AccountFailure(AccountFailureKind.cleanup);
      await controller.logout();
      expect(vault.value, isNull);
      expect(controller.mode, AccountMode.logoutPending);
      expect(intent.value, isTrue);
      cookies.clearError = null;
      await controller.logout();
      expect(controller.mode, AccountMode.guest);
      expect(intent.value, isFalse);
    },
  );
  test(
    'late QR generation after cancel cannot resurrect login or start polling',
    () async {
      final pending = Completer<BiliQrTicket>();
      RequestCancellation? cancellation;
      gateway.generator = (cancel) {
        cancellation = cancel;
        return pending.future;
      };
      await controller.restore();
      final login = controller.startQr();
      await controller.cancelLogin();
      expect(cancellation?.isCancelled, isTrue);
      pending.complete(accountTicket());
      await login;
      expect(controller.ticket, isNull);
      expect(controller.mode, AccountMode.guest);
      expect(gateway.polls, 0);
    },
  );
  test(
    'an old page cancellation cannot cancel a newer login attempt',
    () async {
      await controller.restore();
      await controller.startQr();
      final old = controller.loginGeneration;
      await controller.startQr();
      expect(controller.loginGeneration, greaterThan(old));
      await controller.cancelLogin(generation: old);
      expect(controller.loginPhase, AccountLoginPhase.waiting);
      expect(controller.ticket, isNotNull);
    },
  );
  test(
    'logout intent failure cannot resurrect credentials when secure deletion succeeds',
    () async {
      vault.value = accountSession();
      await controller.restore();
      intent.error = const AccountFailure(AccountFailureKind.storage);
      await controller.logout();
      expect(controller.credentials, isNull);
      expect(vault.value, isNull);
      expect(controller.mode, AccountMode.logoutPending);
      intent.error = null;
      await controller.logout();
      expect(controller.mode, AccountMode.guest);
    },
  );
  test(
    'poll error pauses; explicit retry reuses ticket, background disables polling',
    () async {
      gateway.poller = (_) async =>
          throw const ApiFailure(ApiFailureKind.rateLimited);
      await controller.restore();
      await controller.startQr();
      await controller.pollQr();
      expect(controller.loginPhase, AccountLoginPhase.failed);
      controller.setForeground(false);
      await controller.pollQr();
      expect(gateway.polls, 1);
      controller.setForeground(true);
      gateway.poller = (_) async => const BiliQrResult(BiliQrStatus.scanned);
      await controller.retryLogin();
      expect(controller.loginPhase, AccountLoginPhase.scanned);
      expect(gateway.polls, 2);
    },
  );
  test(
    'web login clears old store first, closes browser before candidate verification',
    () async {
      await controller.restore();
      cookies.candidate = accountCredentials();
      final generation = await controller.startWeb();
      expect(intent.value, isTrue);
      expect(cookies.candidate, isNull);
      cookies.candidate = accountCredentials();
      var closed = false;
      controller.registerBrowserCloser(generation!, () async {
        closed = true;
      });
      gateway.verifier = (credentials, cancel) async {
        expect(closed, isTrue);
        expect(cookies.candidate, isNull);
        return BiliAccountProfile(mid: credentials.mid, name: '测试账号');
      };
      expect(await controller.completeWeb(generation), isTrue);
      expect(controller.mode, AccountMode.verified);
      expect(intent.value, isFalse);
    },
  );
  test(
    'a crash during web login leaves an explicit cleanup obligation',
    () async {
      await controller.restore();
      await controller.startWeb();
      cookies.candidate = accountCredentials();
      expect(intent.value, isTrue);
      controller.dispose();
      controller = AccountController(gateway, vault, intent, cookies);
      final reads = vault.reads;
      await controller.restore();
      expect(vault.reads, reads);
      expect(controller.mode, AccountMode.logoutPending);
      expect(await controller.startWeb(), isNull);
      await controller.logout();
      expect(cookies.candidate, isNull);
      expect(intent.value, isFalse);
      expect(controller.mode, AccountMode.guest);
    },
  );
  test(
    'a failed browser stop is retained for explicit cleanup retry',
    () async {
      await controller.restore();
      final generation = (await controller.startWeb())!;
      cookies.candidate = accountCredentials();
      var attempts = 0;
      controller.registerBrowserCloser(generation, () async {
        if (++attempts == 1) {
          throw const AccountFailure(AccountFailureKind.cleanup);
        }
      });
      expect(await controller.completeWeb(generation), isFalse);
      expect(controller.mode, AccountMode.logoutPending);
      expect(controller.loginPhase, AccountLoginPhase.none);
      expect(intent.value, isTrue);
      expect(cookies.candidate, isNotNull);
      expect(gateway.verifications, 0);
      await controller.startQr();
      expect(controller.ticket, isNull);
      await controller.logout();
      expect(attempts, 2);
      expect(cookies.candidate, isNull);
      expect(intent.value, isFalse);
      expect(controller.mode, AccountMode.guest);
    },
  );
  test(
    'no browser is opened if its durable cleanup guard cannot commit',
    () async {
      await controller.restore();
      intent.error = const AccountFailure(AccountFailureKind.storage);
      expect(await controller.startWeb(), isNull);
      expect(cookies.clears, 0);
      expect(controller.mode, AccountMode.logoutPending);
      expect(controller.busy, isFalse);
      intent.error = null;
      await controller.logout();
      expect(controller.mode, AccountMode.guest);
    },
  );
  test(
    'failed initial browser cleanup does not fall through to QR login',
    () async {
      await controller.restore();
      cookies.clearError = const AccountFailure(AccountFailureKind.cleanup);
      expect(await controller.startWeb(), isNull);
      expect(intent.value, isTrue);
      expect(controller.mode, AccountMode.logoutPending);
      await controller.retryLogin();
      expect(controller.ticket, isNull);
      cookies.clearError = null;
      await controller.logout();
      expect(controller.mode, AccountMode.guest);
    },
  );
  test(
    'logout waits for an already closing browser; no late cleanup overlaps a new login',
    () async {
      await controller.restore();
      final generation = await controller.startWeb();
      cookies.candidate = accountCredentials();
      final closing = Completer<void>();
      controller.registerBrowserCloser(generation!, () => closing.future);
      final login = controller.completeWeb(generation);
      await Future<void>.delayed(Duration.zero);
      final logout = controller.logout();
      await Future<void>.delayed(Duration.zero);
      expect(controller.canLogin, isFalse);
      closing.complete();
      await Future.wait([login, logout]);
      expect(vault.value, isNull);
      expect(controller.mode, AccountMode.guest);
      expect(gateway.verifications, 0);
    },
  );
}
