import 'package:asasfans_next/core/platform/window_appearance.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('asasfans.next/window_appearance');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'macOS and Windows windows get the choice; others are left alone',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        await WindowAppearance.apply(AppAppearance.dark);
      }
      expect(calls, hasLength(2));
      expect(
        calls.map((c) => (c.method, c.arguments)),
        everyElement(('set', 'dark')),
      );

      calls.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      for (final appearance in AppAppearance.values) {
        await WindowAppearance.apply(appearance);
      }
      expect(calls.map((c) => c.arguments), [
        for (final appearance in AppAppearance.values) appearance.name,
      ]);
    },
  );

  test(
    'a host without the bridge keeps its title bar and does not throw',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await expectLater(WindowAppearance.apply(AppAppearance.light), completes);
    },
  );
}
