import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/window_appearance.dart';
import 'router/app_router.dart';
import 'router/app_shell.dart';
import 'glass_providers.dart';
import '../shared/widgets/glass/app_glass_scope.dart';
import '../shared/widgets/glass/glass_policy.dart';
import 'theme/app_theme.dart';
import '../features/preferences/application/preferences_controller.dart';
import '../features/preferences/domain/app_preferences.dart';

class AsasfansApp extends ConsumerStatefulWidget {
  const AsasfansApp({super.key});

  @override
  ConsumerState<AsasfansApp> createState() => _AsasfansAppState();
}

class _AsasfansAppState extends ConsumerState<AsasfansApp> {
  @override
  void initState() {
    super.initState();
    // The native title bar follows the saved choice once it is known.
    ref.listenManual(
      preferencesControllerProvider.select(
        (state) => state.ready ? state.values.appearance : null,
      ),
      (_, appearance) {
        if (appearance != null) unawaited(WindowAppearance.apply(appearance));
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only what the root draws: saving flags and home-module toggles must
    // not rebuild MaterialApp.
    final (ready, appearance, glass) = ref.watch(
      preferencesControllerProvider.select(
        (state) => (state.ready, state.values.appearance, state.values.glass),
      ),
    );
    final runtime = ref.watch(glassRuntimeProvider);
    return MaterialApp.router(
      title: 'Asasfans Next',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (appearance) {
        AppAppearance.system => ThemeMode.system,
        AppAppearance.light => ThemeMode.light,
        AppAppearance.dark => ThemeMode.dark,
      },
      builder: (context, child) {
        return AppGlassScope(
          runtime: runtime,
          // No default-liquid flash while a saved clear preference is loading.
          mode: ready && glass != GlassChoice.smooth
              ? GlassMaterialMode.liquid
              : GlassMaterialMode.clear,
          detail: glass == GlassChoice.visual
              ? GlassDetail.full
              : GlassDetail.platform,
          // The default reading order, revealing focus clear of the bars.
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(
              requestFocusCallback: revealFocusClear,
            ),
            child: child!,
          ),
        );
      },
      routerConfig: ref.watch(appRouterProvider),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      locale: const Locale('zh', 'CN'),
    );
  }
}
