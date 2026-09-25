import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'glass_providers.dart';
import '../shared/widgets/glass/app_glass_scope.dart';
import '../shared/widgets/glass/glass_policy.dart';
import 'theme/app_theme.dart';
import '../features/preferences/application/preferences_controller.dart';
import '../features/preferences/domain/app_preferences.dart';

class AsasfansApp extends ConsumerWidget {
  const AsasfansApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          child: child!,
        );
      },
      routerConfig: ref.watch(appRouterProvider),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      locale: const Locale('zh', 'CN'),
    );
  }
}
