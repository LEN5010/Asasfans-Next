import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'glass_policy.dart';

/// Loads after the first usable (solid) frame, never on the startup critical path.
/// Shader support is a runtime capability, not proof of visual/performance QA.
class GlassRuntime extends ChangeNotifier {
  GlassRuntime({
    required bool shaderFiltersSupported,
    required Future<void> Function(bool premium) load,
    this.timeout = const Duration(seconds: 8),
  }) : _load = load,
       _state = shaderFiltersSupported
           ? GlassRuntimeState.idle
           : GlassRuntimeState.unsupported;

  factory GlassRuntime.device() => GlassRuntime(
    shaderFiltersSupported: ui.ImageFilter.isShaderFilterSupported,
    load: _loadDeviceShaders,
  );

  final Future<void> Function(bool premium) _load;
  final Duration timeout;
  GlassRuntimeState _state;
  GlassRuntimeState get state => _state;
  Future<void>? _pending;
  bool _disposed = false;

  /// [premium] also loads the multi-pass shaders that only the premium tier
  /// draws.
  Future<void> prepare({bool premium = false}) {
    if (_disposed || _state != GlassRuntimeState.idle) {
      return _pending ?? Future<void>.value();
    }
    _state = GlassRuntimeState.loading;
    // Install the future before notifying: a reentrant caller must share it.
    final completion = Completer<void>();
    _pending = completion.future;
    notifyListeners();
    unawaited(_prepare(completion, premium));
    return completion.future;
  }

  Future<void> _prepare(Completer<void> completion, bool premium) async {
    try {
      await Future<void>.sync(() => _load(premium)).timeout(timeout);
      if (!_disposed && _state == GlassRuntimeState.loading) {
        _state = GlassRuntimeState.ready;
        notifyListeners();
      }
    } catch (_) {
      fail();
    } finally {
      completion.complete();
    }
  }

  /// A renderer/performance failure latches clear mode for this runtime.
  /// No automatic retry loop, silent lightweight replacement or route reset.
  void fail() {
    if (_disposed || _state == GlassRuntimeState.failed) return;
    _state = GlassRuntimeState.failed;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static Future<void> _loadDeviceShaders(bool premium) async {
    // Loading a program compiles it on the raster thread. On Windows
    // (Impeller over ANGLE) the premium geometry pass alone held it for about
    // eight seconds after the first frame, so only the premium tier pays.
    if (premium) {
      // 0.30.2's premium preloader reports errors but completes successfully.
      // Verify its required programs ourselves so missing assets fail closed.
      for (final asset in [
        'liquid_glass_geometry_blended.frag',
        'liquid_glass_final_render.frag',
      ]) {
        await ui.FragmentProgram.fromAsset(
          'packages/liquid_glass_widgets/shaders/$asset',
        );
      }
    }
    await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  }
}
