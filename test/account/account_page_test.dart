import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/account/application/account_controller.dart';
import 'package:asasfans_next/features/account/application/account_providers.dart';
import 'package:asasfans_next/features/account/domain/bili_account.dart';
import 'package:asasfans_next/features/account/presentation/account_page.dart';
import 'package:asasfans_next/features/account/presentation/web_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../helpers/account_fixture.dart';

void main() {
  late OfflineAuthGateway gateway;
  late MemoryAccountVault vault;
  late MemoryLogoutIntent intent;
  late MemoryLoginCookies cookies;
  late AccountController controller;
  // Built inside the test body, never in setUp: the controller chains its
  // serialized work onto a Future created with it. Constructing it in setUp
  // leaves that chain in setUp's real-time zone, which the test's FakeAsync
  // never advances, so every await on it hangs until the suite times out.
  void createController() {
    gateway = OfflineAuthGateway();
    vault = MemoryAccountVault();
    intent = MemoryLogoutIntent();
    cookies = MemoryLoginCookies(supportsWebLogin: true);
    controller = AccountController(gateway, vault, intent, cookies);
    addTearDown(controller.dispose);
  }

  Widget host({double scale = 1}) => ProviderScope(
    overrides: [accountControllerProvider.overrideWith((ref) => controller)],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const AccountPage(),
    ),
  );
  testWidgets(
    'phone has web login alongside QR, and scanned state does not report logged in',
    (tester) async {
      createController();
      await controller.restore();
      gateway.poller = (_) async => const BiliQrResult(BiliQrStatus.scanned);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('网页登录'), findsOneWidget);
      await tester.tap(find.text('扫码登录'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(QrImageView), findsOneWidget);
      await controller.pollQr();
      await tester.pump();
      expect(find.text('请在 B 站确认登录'), findsOneWidget);
      expect(find.text('已登录'), findsNothing);
      await tester.tap(find.text('取消登录'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
    },
  );
  testWidgets('failed deletion visibly offers retry, not successful logout', (
    tester,
  ) async {
    createController();
    vault.value = accountSession();
    await controller.restore();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    vault.clearError = const AccountFailure(AccountFailureKind.cleanup);
    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.text('重试退出清理'), findsOneWidget);
    expect(find.text('未登录'), findsNothing);
    vault.clearError = null;
    await tester.tap(find.text('重试退出清理'));
    await tester.pumpAndSettle();
    expect(find.text('未登录'), findsOneWidget);
  });
  testWidgets('offline verification retains profile and does not log out', (
    tester,
  ) async {
    createController();
    vault.value = accountSession();
    await controller.restore();
    gateway.verifyError = const ApiFailure(ApiFailureKind.offline);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('验证登录'));
    await tester.pumpAndSettle();
    expect(find.text('测试账号'), findsOneWidget);
    expect(find.text('网络连接失败'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
  });
  test(
    'top-level login navigation is HTTPS first-party only; challenge iframe may use its own HTTPS origin',
    () {
      expect(
        BiliLoginNavigation.allowed('https://passport.bilibili.com/login'),
        isTrue,
      );
      for (final url in [
        'http://passport.bilibili.com/login',
        'https://bilibili.com.evil.test',
        'https://evilbilibili.com',
        'javascript:alert(1)',
        'file:///private',
        'https://u@www.bilibili.com/',
        'https://www.bilibili.com:444/',
      ]) {
        expect(BiliLoginNavigation.allowed(url), isFalse);
      }
      expect(
        BiliLoginNavigation.allowed(
          'https://challenge.example.test/',
          mainFrame: false,
        ),
        isTrue,
      );
    },
  );
  for (final size in [const Size(320, 568), const Size(1280, 800)]) {
    testWidgets('account controls and QR fit $size with large text', (
      tester,
    ) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      createController();
      await controller.restore();
      await tester.pumpWidget(host(scale: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('扫码登录'));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await controller.cancelLogin();
      await tester.pumpAndSettle();
    });
  }
}
