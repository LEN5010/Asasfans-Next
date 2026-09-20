import 'package:asasfans_next/features/account/data/platform_login_cookies.dart';
import 'package:asasfans_next/features/account/domain/bili_account.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/account_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('asasfans.next/bilibili_login_cookies');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'null capability is a probe failure, not declared unsupported',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      final browser = PlatformLoginCookies(supportedHost: true);
      await browser.initialize();
      expect(browser.supportsWebLogin, isFalse);
      await expectLater(browser.clear(), throwsA(isA<AccountFailure>()));
    },
  );
  test(
    'stop addresses exactly one native WebView, including a detached view',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
      final browser = PlatformLoginCookies(supportedHost: true);
      await browser.initialize();
      await browser.stopNavigation(webViewId: 42);
      expect(calls.last.method, 'stop');
      expect(calls.last.arguments, {'webViewId': 42});
    },
  );
  test(
    'missing native capability is uncertain cleanup, not successful logout; retry probes again',
    () async {
      var available = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (!available) {
          throw PlatformException(
            code: 'FIXTURE',
            message: 'private native detail',
          );
        }
        return true;
      });
      final browser = PlatformLoginCookies(supportedHost: true);
      await browser.initialize();
      expect(browser.supportsWebLogin, isFalse);
      await expectLater(
        browser.clear(),
        throwsA(
          isA<AccountFailure>().having(
            (e) => e.kind,
            'kind',
            AccountFailureKind.cleanup,
          ),
        ),
      );
      available = true;
      await browser.clear();
      expect(browser.supportsWebLogin, isTrue);
    },
  );
  test(
    'unsupported platform avoids channel calls, while declared unsupported profile never opens old cookie store',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        expect(call.method, 'available');
        return false;
      });
      final windows = PlatformLoginCookies(supportedHost: false);
      await windows.initialize();
      await windows.clear();
      expect(calls, 0);
      final legacy = PlatformLoginCookies(supportedHost: true);
      await legacy.initialize();
      await legacy.clear();
      expect(legacy.supportsWebLogin, isFalse);
      expect(calls, 2);
    },
  );
  test(
    'native HTTP-only cookie records are allowlisted and duplicate conflicts fail closed',
    () async {
      final values = [
        for (final entry in accountCredentials().cookies.entries)
          {'name': entry.key, 'value': entry.value},
      ];
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'read' ? values : true,
      );
      final browser = PlatformLoginCookies(supportedHost: true);
      await browser.initialize();
      expect((await browser.read())?.mid, '123');
      values.add({'name': 'SESSDATA', 'value': 'conflicting-session'});
      await expectLater(browser.read(), throwsA(isA<AccountFailure>()));
      values.clear();
      expect(await browser.read(), isNull);
    },
  );
}
