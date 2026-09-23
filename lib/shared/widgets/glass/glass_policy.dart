/// A device-local presentation preference, not a content or backup setting.
enum GlassMaterialMode { liquid, clear }

enum GlassRuntimeState { unsupported, idle, loading, ready, failed }

/// Unknown is not the same as a system setting explicitly being off.
enum SystemTransparency { loading, allowed, reduced, unavailable }

enum GlassFallback {
  none,
  userChoice,
  transparencyPending,
  reducedTransparency,
  highContrast,
  nativeContent,
  inactive,
  unsupported,
  preparing,
  failed,
}

class GlassPolicy {
  const GlassPolicy({
    required this.fallback,
    required this.reduceMotion,
    required this.active,
  });

  final GlassFallback fallback;
  final bool reduceMotion;
  final bool active;
  bool get usesLiquid => fallback == GlassFallback.none;
  bool get canAnimate => !reduceMotion && active;

  static GlassPolicy resolve({
    required GlassMaterialMode mode,
    required GlassRuntimeState runtime,
    required SystemTransparency transparency,
    bool highContrast = false,
    bool reduceMotion = false,
    bool nativeContent = false,
    bool active = true,
  }) {
    final reason = switch ((mode, transparency, runtime)) {
      _ when mode == GlassMaterialMode.clear => GlassFallback.userChoice,
      _ when transparency == SystemTransparency.reduced =>
        GlassFallback.reducedTransparency,
      _ when highContrast => GlassFallback.highContrast,
      _ when nativeContent => GlassFallback.nativeContent,
      _ when !active => GlassFallback.inactive,
      _ when transparency == SystemTransparency.loading =>
        GlassFallback.transparencyPending,
      (_, _, GlassRuntimeState.unsupported) => GlassFallback.unsupported,
      (_, _, GlassRuntimeState.failed) => GlassFallback.failed,
      (_, _, GlassRuntimeState.ready) => GlassFallback.none,
      _ => GlassFallback.preparing,
    };
    return GlassPolicy(
      fallback: reason,
      reduceMotion: reduceMotion,
      active: active,
    );
  }
}
