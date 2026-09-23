import 'dart:async';

import 'package:flutter/services.dart';

/// Read-only system signal. This bridge never changes OS preferences and is
/// independent of MediaQuery.highContrast / disableAnimations.
abstract interface class TransparencyPreferenceService {
  /// null means not available, never a fabricated "disabled" system setting.
  Stream<bool?> watch();
}

class NativeTransparencyPreference implements TransparencyPreferenceService {
  const NativeTransparencyPreference({
    this.channel = const EventChannel('asasfans.next/reduce_transparency'),
    this.stateChannel = const MethodChannel(
      'asasfans.next/reduce_transparency_state',
    ),
  });

  final EventChannel channel;
  final MethodChannel stateChannel;

  @override
  Stream<bool?> watch() {
    late final StreamController<bool?> controller;
    StreamSubscription<dynamic>? events;
    var stopped = false;

    Future<void> start() async {
      try {
        // EventChannel reports a missing listener through FlutterError instead
        // of its stream. Probe the independent method first.
        final initial = await stateChannel.invokeMethod<Object?>('read');
        if (stopped) return;
        controller.add(initial is bool ? initial : null);
        if (initial is! bool) {
          unawaited(controller.close());
          return;
        }
        events = channel.receiveBroadcastStream().listen(
          (value) {
            if (!stopped) controller.add(value is bool ? value : null);
          },
          onError: (Object _, StackTrace _) {
            if (!stopped) controller.add(null);
          },
          onDone: () {
            if (!stopped) unawaited(controller.close());
          },
        );
      } on MissingPluginException {
        if (!stopped) {
          controller.add(null);
          unawaited(controller.close());
        }
      } on PlatformException {
        if (!stopped) {
          controller.add(null);
          unawaited(controller.close());
        }
      } catch (error, stack) {
        if (!stopped) {
          controller.addError(error, stack);
          unawaited(controller.close());
        }
      }
    }

    controller = StreamController<bool?>(
      onListen: () => unawaited(start()),
      onCancel: () async {
        // Do not use async* + await-for: cancellation can otherwise wait for
        // the next OS change before removing the native observer.
        stopped = true;
        await events?.cancel();
      },
    );
    return controller.stream;
  }
}
