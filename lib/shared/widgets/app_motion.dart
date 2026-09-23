import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import 'glass/app_glass_scope.dart';

/// A motion duration that becomes instant when the system disables animation.
Duration appMotion(BuildContext context, Duration duration) =>
    AppGlassScope.of(context).canAnimate ? duration : Duration.zero;

/// The branch [AsyncValue.when] shows: a refresh keeps its data phase, so
/// pulling to refresh does not fade the module out.
Object asyncPhase(AsyncValue<Object?> value) =>
    value.isLoading && !value.isRefreshing
    ? #loading
    : value.hasError
    ? #error
    : #data;

/// Cross-fades a module between its loading, error and loaded states.
class AppFadeSwitcher extends StatelessWidget {
  const AppFadeSwitcher({super.key, required this.phase, required this.child});
  final Object phase;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: appMotion(context, AppTokens.controlMotion),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topCenter,
      children: [...previous, ?current],
    ),
    child: KeyedSubtree(key: ValueKey(phase), child: child),
  );
}
