import 'dart:async';

import 'package:asasfans_next/shared/widgets/glass/glass_policy.dart';
import 'package:asasfans_next/shared/widgets/glass/glass_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsupported renderer performs no shader loading', () async {
    var calls = 0;
    final runtime = GlassRuntime(
      shaderFiltersSupported: false,
      load: () async {
        calls++;
      },
    );
    addTearDown(runtime.dispose);
    await runtime.prepare();
    expect(calls, 0);
    expect(runtime.state, GlassRuntimeState.unsupported);
  });
  test('preparation is shared, including reentrant listeners', () async {
    final loading = Completer<void>();
    var calls = 0;
    final runtime = GlassRuntime(
      shaderFiltersSupported: true,
      load: () {
        calls++;
        return loading.future;
      },
    );
    addTearDown(runtime.dispose);
    Future<void>? reentrant;
    runtime.addListener(() {
      reentrant ??= runtime.prepare();
    });
    final first = runtime.prepare();
    expect(identical(first, runtime.prepare()), isTrue);
    expect(identical(first, reentrant), isTrue);
    expect(runtime.state, GlassRuntimeState.loading);
    loading.complete();
    await first;
    expect(runtime.state, GlassRuntimeState.ready);
    expect(calls, 1);
  });
  test('loading failure latches solid mode without retry loops', () async {
    var calls = 0;
    final runtime = GlassRuntime(
      shaderFiltersSupported: true,
      load: () async {
        calls++;
        throw StateError('missing shader');
      },
    );
    addTearDown(runtime.dispose);
    await runtime.prepare();
    await runtime.prepare();
    expect(runtime.state, GlassRuntimeState.failed);
    expect(calls, 1);
  });
  test('timeout remains failed even after late success', () async {
    final loading = Completer<void>();
    final runtime = GlassRuntime(
      shaderFiltersSupported: true,
      timeout: Duration.zero,
      load: () => loading.future,
    );
    addTearDown(runtime.dispose);
    await runtime.prepare();
    loading.complete();
    await Future<void>.delayed(Duration.zero);
    expect(runtime.state, GlassRuntimeState.failed);
  });
  test(
    'runtime failure during preparation cannot be overwritten by success',
    () async {
      final loading = Completer<void>();
      final runtime = GlassRuntime(
        shaderFiltersSupported: true,
        load: () => loading.future,
      );
      addTearDown(runtime.dispose);
      final pending = runtime.prepare();
      runtime.fail();
      loading.complete();
      await pending;
      expect(runtime.state, GlassRuntimeState.failed);
    },
  );
  test('dispose during loading never notifies after disposal', () async {
    final loading = Completer<void>();
    final runtime = GlassRuntime(
      shaderFiltersSupported: true,
      load: () => loading.future,
    );
    var changes = 0;
    runtime.addListener(() => changes++);
    final pending = runtime.prepare();
    runtime.dispose();
    loading.complete();
    await pending;
    expect(changes, 1);
  });
}
