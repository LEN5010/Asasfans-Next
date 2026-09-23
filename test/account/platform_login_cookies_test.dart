import 'package:asasfans_next/features/account/data/platform_login_cookies.dart';
import 'package:asasfans_next/features/account/domain/bili_account.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
      await expectLater(browser.clear(), throwsA(isA<AccountFailure>()));
    },
  );
  test(
    'missing native capability is uncertain cleanup, not success; retry probes again',
    () async {
      var available = false;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (!available) {
          throw PlatformException(
            code: 'FIXTURE',
            message: 'private native detail',
          );
        }
        return true;
      });
      final browser = PlatformLoginCookies(supportedHost: true);
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
      expect(calls, ['available', 'available', 'clear']);
    },
  );
  test('an incomplete native clear is reported', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'available',
    );
    await expectLater(
      PlatformLoginCookies(supportedHost: true).clear(),
      throwsA(isA<AccountFailure>()),
    );
  });
  test(
    'unsupported platform avoids channel calls, while declared unsupported profile never opens old cookie store',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        expect(call.method, 'available');
        return false;
      });
      await PlatformLoginCookies(supportedHost: false).clear();
      expect(calls, 0);
      await PlatformLoginCookies(supportedHost: true).clear();
      expect(calls, 1);
    },
  );
}
