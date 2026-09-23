import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/widgets/glass/glass_runtime.dart';

final glassRuntimeProvider = Provider<GlassRuntime>((ref) {
  final runtime = GlassRuntime.device();
  ref.onDispose(runtime.dispose);
  return runtime;
});

/// Installed by executable entry points, not by widget-test hosts. Reports the
/// original error and latches a clear fallback; it never suppresses diagnostics.
Override observeGlassRendererErrors() =>
    glassRuntimeProvider.overrideWith((ref) {
      final runtime = GlassRuntime.device();
      final previous = FlutterError.onError;
      void handler(FlutterErrorDetails details) {
        if ('${details.stack}'.contains('package:liquid_glass_widgets/')) {
          scheduleMicrotask(runtime.fail);
        }
        if (previous != null) {
          previous(details);
        } else {
          FlutterError.presentError(details);
        }
      }

      FlutterError.onError = handler;
      ref.onDispose(() {
        if (identical(FlutterError.onError, handler)) {
          FlutterError.onError = previous;
        }
        runtime.dispose();
      });
      return runtime;
    });
