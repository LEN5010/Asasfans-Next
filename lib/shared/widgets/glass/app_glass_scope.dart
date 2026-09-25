import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/platform/transparency_preference.dart';
import 'glass_policy.dart';
import 'glass_runtime.dart';

/// Place inside MaterialApp.builder, above its Navigator/root Overlay.
/// The caller owns [runtime]; the scope owns its native signal subscription.
class AppGlassScope extends StatefulWidget {
  const AppGlassScope({
    super.key,
    required this.runtime,
    required this.mode,
    required this.child,
    this.detail = GlassDetail.platform,
    this.transparency = const NativeTransparencyPreference(),
    this.transparencyOverride,
  });

  final GlassRuntime runtime;
  final GlassMaterialMode mode;
  final GlassDetail detail;
  final Widget child;
  final TransparencyPreferenceService transparency;
  final SystemTransparency? transparencyOverride;

  static GlassPolicy of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassPolicyScope>()?.policy ??
      const GlassPolicy(
        fallback: GlassFallback.userChoice,
        reduceMotion: false,
        active: true,
      );

  @override
  State<AppGlassScope> createState() => _AppGlassScopeState();
}

class _AppGlassScopeState extends State<AppGlassScope>
    with WidgetsBindingObserver {
  StreamSubscription<bool?>? _subscription;
  SystemTransparency _transparency = SystemTransparency.loading;
  bool _active = true;
  bool _prepareScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _active = _isActive(WidgetsBinding.instance.lifecycleState);
    _subscribe();
  }

  void _subscribe() {
    _subscription = widget.transparency.watch().listen(
      (value) {
        if (!mounted) return;
        setState(() {
          _transparency = switch (value) {
            true => SystemTransparency.reduced,
            false => SystemTransparency.allowed,
            null => SystemTransparency.unavailable,
          };
        });
      },
      onError: (Object _, StackTrace _) {
        if (mounted) {
          setState(() => _transparency = SystemTransparency.unavailable);
        }
      },
    );
  }

  @override
  void didUpdateWidget(AppGlassScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transparency != oldWidget.transparency) {
      unawaited(_subscription?.cancel());
      _transparency = SystemTransparency.loading;
      _subscribe();
    }
  }

  static bool _isActive(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _active = _isActive(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.runtime,
    child: widget.child,
    builder: (context, child) {
      final policy = _resolve(context);
      if (policy.fallback == GlassFallback.preparing &&
          widget.runtime.state == GlassRuntimeState.idle &&
          !_prepareScheduled) {
        _prepareScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _prepareScheduled = false;
          if (mounted &&
              _resolve(context).fallback == GlassFallback.preparing) {
            unawaited(widget.runtime.prepare());
          }
        });
      }
      return _GlassPolicyScope(
        policy: policy,
        child: GlassAccessibilityScope(
          reduceMotion: !policy.canAnimate,
          reduceTransparency: !policy.usesLiquid,
          child: LiquidGlassWidgets.wrap(
            brightnessResolver: Theme.maybeBrightnessOf,
            child: child!,
          ),
        ),
      );
    },
  );

  GlassPolicy _resolve(BuildContext context) => GlassPolicy.resolve(
    mode: widget.mode,
    runtime: widget.runtime.state,
    transparency: widget.transparencyOverride ?? _transparency,
    detail: widget.detail,
    platform: Theme.of(context).platform,
    highContrast: MediaQuery.highContrastOf(context),
    reduceMotion: MediaQuery.disableAnimationsOf(context),
    active: _active,
  );
}

class _GlassPolicyScope extends InheritedWidget {
  const _GlassPolicyScope({required this.policy, required super.child});
  final GlassPolicy policy;
  @override
  bool updateShouldNotify(_GlassPolicyScope oldWidget) =>
      policy.fallback != oldWidget.policy.fallback ||
      policy.glassTier != oldWidget.policy.glassTier ||
      policy.reduceMotion != oldWidget.policy.reduceMotion ||
      policy.active != oldWidget.policy.active;
}
