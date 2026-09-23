import 'dart:async';

import 'package:asasfans_next/core/platform/transparency_preference.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const native = NativeTransparencyPreference();
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      native.stateChannel,
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      MethodChannel(native.channel.name),
      null,
    );
  });
  test(
    'cancelling before the initial probe completes cannot attach a listener',
    () async {
      final read = Completer<Object?>();
      var listens = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        native.stateChannel,
        (_) => read.future,
      );
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(native.channel.name),
        (_) async {
          listens++;
          return null;
        },
      );
      final values = <bool?>[];
      final subscription = native.watch().listen(values.add);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      read.complete(false);
      await Future<void>.delayed(Duration.zero);
      expect(listens, 0);
      expect(values, isEmpty);
    },
  );
  test('missing native API is an unavailable signal, not false', () async {
    expect(await native.watch().toList(), [null]);
  });
  test('platform read failure yields an unavailable signal', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      native.stateChannel,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    expect(await native.watch().toList(), [null]);
  });
  test('malformed state never enables an event subscription', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      native.stateChannel,
      (_) async => 'false',
    );
    expect(await native.watch().toList(), [null]);
  });
  test(
    'reads initial value, forwards changes and cancels native subscription',
    () async {
      final methods = <String>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        native.stateChannel,
        (call) async {
          expect(call.method, 'read');
          return false;
        },
      );
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(native.channel.name),
        (call) async {
          methods.add(call.method);
          return null;
        },
      );
      final values = <bool?>[];
      final subscription = native.watch().listen(values.add);
      await Future<void>.delayed(Duration.zero);
      binding.channelBuffers.push(
        native.channel.name,
        const StandardMethodCodec().encodeSuccessEnvelope(true),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(values, [false, true]);
      await subscription.cancel();
      expect(methods, ['listen', 'cancel']);
    },
  );
}
