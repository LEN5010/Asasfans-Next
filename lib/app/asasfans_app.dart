import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../features/preferences/application/preferences_controller.dart';
import '../features/preferences/domain/app_preferences.dart';

class AsasfansApp extends ConsumerWidget {
  const AsasfansApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Asasfans Next',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (ref.watch(
        preferencesControllerProvider.select(
          (state) => state.values.appearance,
        ),
      )) {
        AppAppearance.system => ThemeMode.system,
        AppAppearance.light => ThemeMode.light,
        AppAppearance.dark => ThemeMode.dark,
      },
      routerConfig: ref.watch(appRouterProvider),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      locale: const Locale('zh', 'CN'),
    );
  }
}
