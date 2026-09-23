import 'dart:async';
import 'dart:io';

import 'package:asasfans_next/shared/widgets/glass/glass_runtime.dart';
import 'package:flutter/material.dart';

import 'probe_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _NoNetwork();
  final runtime = GlassRuntime.device();
  // Probe-only instrumentation: report (never hide) failures and retain an
  // operable solid surface if this package's renderer reports an exception.
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if ('${details.stack}'.contains('package:liquid_glass_widgets/')) {
      scheduleMicrotask(runtime.fail);
    }
    previous?.call(details);
  };
  runApp(GlassProbeApp(runtime: runtime));
}

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('No network in the glass probe.');
}
