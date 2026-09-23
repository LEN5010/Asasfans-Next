import 'package:asasfans_next/shared/widgets/glass/glass_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GlassPolicy resolve({
    GlassMaterialMode mode = GlassMaterialMode.liquid,
    GlassRuntimeState runtime = GlassRuntimeState.ready,
    SystemTransparency transparency = SystemTransparency.allowed,
    bool highContrast = false,
    bool reduceMotion = false,
    bool nativeContent = false,
    bool active = true,
  }) => GlassPolicy.resolve(
    mode: mode,
    runtime: runtime,
    transparency: transparency,
    highContrast: highContrast,
    reduceMotion: reduceMotion,
    nativeContent: nativeContent,
    active: active,
  );

  test(
    'ready shader capability enables liquid; platform names do not decide',
    () {
      expect(resolve().usesLiquid, isTrue);
    },
  );
  test('motion and transparency are independent', () {
    expect(resolve(reduceMotion: true).usesLiquid, isTrue);
    expect(resolve(reduceMotion: true).reduceMotion, isTrue);
    expect(
      resolve(transparency: SystemTransparency.reduced).fallback,
      GlassFallback.reducedTransparency,
    );
    expect(resolve(highContrast: true).fallback, GlassFallback.highContrast);
  });
  test(
    'unknown signal stays explicitly unavailable, not claimed supported',
    () {
      expect(
        resolve(transparency: SystemTransparency.loading).usesLiquid,
        isFalse,
      );
      // Unsupported OS still has the user's explicit clear-mode switch.
      expect(
        resolve(transparency: SystemTransparency.unavailable).usesLiquid,
        isTrue,
      );
      expect(
        resolve(
          mode: GlassMaterialMode.clear,
          transparency: SystemTransparency.unavailable,
        ).fallback,
        GlassFallback.userChoice,
      );
    },
  );
  test('inactive and native-content boundaries cannot use a sampler', () {
    expect(resolve(nativeContent: true).fallback, GlassFallback.nativeContent);
    expect(resolve(active: false).fallback, GlassFallback.inactive);
  });
  for (final state in GlassRuntimeState.values.where(
    (s) => s != GlassRuntimeState.ready,
  )) {
    test('$state never masquerades as real liquid', () {
      expect(resolve(runtime: state).usesLiquid, isFalse);
    });
  }
  test('inactive stops motion even when a stronger fallback is selected', () {
    for (final mode in GlassMaterialMode.values) {
      expect(resolve(mode: mode, active: false).canAnimate, isFalse);
      expect(
        resolve(
          mode: mode,
          active: false,
          transparency: SystemTransparency.reduced,
        ).canAnimate,
        isFalse,
      );
    }
  });
  test('clear request dominates ready shaders', () {
    expect(resolve(mode: GlassMaterialMode.clear).usesLiquid, isFalse);
  });
}
