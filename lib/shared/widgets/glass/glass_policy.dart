import 'package:flutter/foundation.dart';

/// A device-local presentation preference, not a content or backup setting.
enum GlassMaterialMode { liquid, clear }

/// How much optical detail glass may use when it is on at all.
/// [platform] is the per-platform default; [full] is the user asking for
/// the most detailed tier.
enum GlassDetail { platform, full }

/// What is actually rendered. [solid] samples no backdrop at all; it is the
/// floor every fallback lands on, not the package's still-blurring minimal.
enum GlassTier { solid, standard, premium }

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
    this.glassTier = GlassTier.standard,
  });

  final GlassFallback fallback;
  final bool reduceMotion;
  final bool active;

  /// The tier glass renders at when [usesLiquid]; see [tier].
  final GlassTier glassTier;
  bool get usesLiquid => fallback == GlassFallback.none;
  bool get canAnimate => !reduceMotion && active;

  /// The effective tier: any fallback means solid.
  GlassTier get tier => usesLiquid ? glassTier : GlassTier.solid;

  /// Android covers everything from flagships to old phones on one default,
  /// so it starts at standard, like desktop Windows/Linux. Apple platforms
  /// keep the premium tier they were tuned on. Shader support alone says the
  /// effect can run, not that it runs smoothly on a given GPU.
  static GlassTier platformTier(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => GlassTier.premium,
    _ => GlassTier.standard,
  };

  static GlassPolicy resolve({
    required GlassMaterialMode mode,
    required GlassRuntimeState runtime,
    required SystemTransparency transparency,
    GlassDetail detail = GlassDetail.platform,
    TargetPlatform? platform,
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
      glassTier: detail == GlassDetail.full
          ? GlassTier.premium
          : platformTier(platform ?? defaultTargetPlatform),
    );
  }
}
