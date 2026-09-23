import 'dart:io';

import 'package:asasfans_next/app/asasfans_app.dart';
import 'package:asasfans_next/app/glass_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_environment.dart';

/// Explicit development entry point. Never imported by lib/main.dart.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = OfflinePreviewHttpOverrides();
  runApp(
    ProviderScope(
      overrides: [...offlinePreviewOverrides(), observeGlassRendererErrors()],
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Banner(
          message: 'OFFLINE',
          location: BannerLocation.topEnd,
          child: AsasfansApp(),
        ),
      ),
    ),
  );
}
