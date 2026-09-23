import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:asasfans_next/shared/widgets/glass/app_glass_scope.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_surface.dart';
import 'package:asasfans_next/shared/widgets/glass/glass_policy.dart';
import 'package:asasfans_next/shared/widgets/glass/glass_runtime.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'refraction_comparison.dart';

/// Deliberately not a production route. All backgrounds are generated locally;
/// no business providers, native views, database, vault or external opens exist.
class GlassProbeApp extends StatefulWidget {
  const GlassProbeApp({super.key, required this.runtime});
  final GlassRuntime runtime;
  @override
  State<GlassProbeApp> createState() => _GlassProbeAppState();
}

class _GlassProbeAppState extends State<GlassProbeApp> {
  final sceneKey = GlobalKey<GlassProbeSceneState>();
  GlassMaterialMode mode = GlassMaterialMode.liquid;
  bool dark = false;
  bool reduceMotion = false;
  bool highContrast = false;
  bool reduceTransparency = false;
  bool nativeContent = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: const Color(0xFF8A3E59),
      scaffoldBackgroundColor: dark
          ? const Color(0xFF171719)
          : const Color(0xFFF7F7F9),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        highContrast: highContrast || MediaQuery.highContrastOf(context),
        disableAnimations:
            reduceMotion || MediaQuery.disableAnimationsOf(context),
      ),
      child: AppGlassScope(
        runtime: widget.runtime,
        mode: mode,
        transparencyOverride: reduceTransparency
            ? SystemTransparency.reduced
            : null,
        child: child!,
      ),
    ),
    home: GlassProbeScene(
      key: sceneKey,
      runtime: widget.runtime,
      mode: mode,
      nativeContent: nativeContent,
      onModeChanged: (value) => setState(() => mode = value),
      controls: Wrap(
        spacing: 4,
        children: [
          FilterChip(
            label: const Text('深色'),
            selected: dark,
            onSelected: (v) => setState(() => dark = v),
          ),
          FilterChip(
            label: const Text('减少动态'),
            selected: reduceMotion,
            onSelected: (v) => setState(() => reduceMotion = v),
          ),
          FilterChip(
            label: const Text('高对比'),
            selected: highContrast,
            onSelected: (v) => setState(() => highContrast = v),
          ),
          FilterChip(
            label: const Text('减少透明度'),
            selected: reduceTransparency,
            onSelected: (v) => setState(() => reduceTransparency = v),
          ),
          FilterChip(
            label: const Text('原生背景隔离'),
            selected: nativeContent,
            onSelected: (v) => setState(() => nativeContent = v),
          ),
        ],
      ),
    ),
  );
}

class GlassProbeScene extends StatefulWidget {
  const GlassProbeScene({
    super.key,
    required this.runtime,
    required this.mode,
    required this.onModeChanged,
    required this.controls,
    required this.nativeContent,
  });
  final GlassRuntime runtime;
  final GlassMaterialMode mode;
  final ValueChanged<GlassMaterialMode> onModeChanged;
  final Widget controls;
  final bool nativeContent;
  @override
  State<GlassProbeScene> createState() => GlassProbeSceneState();
}

class GlassProbeSceneState extends State<GlassProbeScene>
    with WidgetsBindingObserver {
  final scroll = ScrollController();
  final captureKey = GlobalKey();
  final toolsFocus = FocusNode(debugLabel: 'probe-tools');
  final frames = <ui.FrameTiming>[];
  final invalidReasons = <String>{};
  GlassMaterialMode? measuredMode;
  bool collecting = false;
  bool running = false;
  int selected = 0;
  int actions = 0;
  String status = '手动检查 / 不访问业务数据';
  late Directory output;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_timings);
    if (const bool.fromEnvironment('GLASS_BENCHMARK')) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(benchmark()),
      );
    }
  }

  void _timings(List<ui.FrameTiming> timings) {
    if (collecting) {
      _validateSample();
      frames.addAll(timings);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A paused engine may deliver no frames/dependency rebuild at all. Record
    // invalidation from the OS event itself, including brief background trips.
    if (collecting && state != AppLifecycleState.resumed) {
      invalidReasons.add('application_inactive');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (collecting) _validateSample();
  }

  void _validateSample() {
    final policy = AppGlassScope.of(context);
    if (!policy.active) invalidReasons.add('application_inactive');
    if (measuredMode != null && widget.mode != measuredMode) {
      invalidReasons.add('mode_changed_during_round');
    }
    if (measuredMode == GlassMaterialMode.liquid && !policy.usesLiquid) {
      invalidReasons.add('liquid_not_effective:${policy.fallback.name}');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    scroll.dispose();
    toolsFocus.dispose();
    super.dispose();
  }

  Future<void> _panel() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .10),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AppGlassSurface(
            nativeContent: widget.nativeContent,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('工具面板 · 离线原型')),
                      IconButton(
                        tooltip: '关闭面板',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  TextField(
                    decoration: InputDecoration(
                      labelText: '保留输入与焦点',
                      filled: true,
                      fillColor: AppGlassSurface.surfaceColor(
                        Theme.of(context).brightness,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('一块玻璃外壳，文字和输入控件不参加折射。'),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: AppGlassSurface.surfaceColor(
                        Theme.of(context).brightness,
                      ),
                    ),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) toolsFocus.requestFocus();
  }

  Future<void> _capture(String name) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final boundary =
        captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${output.path}/$name.png').writeAsBytes(
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  }

  Future<void> benchmark() async {
    if (running) return;
    setState(() {
      running = true;
      status = '准备 profile 基线';
    });
    output = await Directory.systemTemp.createTemp('asasfans-glass-probe-');
    try {
      await widget.runtime.prepare();
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final refresh = View.of(context).display.refreshRate;
      final budget = 1000 / (refresh > 0 ? refresh : 60);
      final rounds = <Map<String, Object?>>[];
      for (final mode in [GlassMaterialMode.clear, GlassMaterialMode.liquid]) {
        widget.onModeChanged(mode);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        scroll.jumpTo(0);
        await _capture('${mode.name}-start');
        await scroll.animateTo(
          280,
          duration: const Duration(seconds: 2),
          curve: Curves.linear,
        );
        await _capture('${mode.name}-scrolled');
        for (var round = 0; round < 3; round++) {
          setState(() => status = '${mode.name} 第 ${round + 1}/3 轮 · 30 秒');
          // Flush the previous timings batch before measuring this round.
          await Future<void>.delayed(const Duration(seconds: 1));
          frames.clear();
          invalidReasons.clear();
          measuredMode = mode;
          collecting = true;
          _validateSample();
          final timer = Stopwatch()..start();
          while (timer.elapsed < const Duration(seconds: 30) && mounted) {
            final target = scroll.offset < 400 ? 1200.0 : 0.0;
            await scroll.animateTo(
              target,
              duration: const Duration(seconds: 2),
              curve: Curves.linear,
            );
            if (mounted) setState(() => selected = selected == 0 ? 3 : 0);
          }
          await Future<void>.delayed(const Duration(seconds: 1));
          collecting = false;
          if (!mounted) return;
          rounds.add(_summary(mode, round + 1, budget));
        }
      }
      // No benchmark scroll/ticker remains during the idle observation.
      await Future<void>.delayed(const Duration(seconds: 2));
      frames.clear();
      collecting = true;
      await Future<void>.delayed(const Duration(seconds: 3));
      collecting = false;
      if (!mounted) return;
      final idleFrames = frames.length;
      final report = <String, Object?>{
        'buildMode': kProfileMode
            ? 'profile'
            : (kReleaseMode ? 'release' : 'debug'),
        'operatingSystem': Platform.operatingSystemVersion,
        'runtime': widget.runtime.state.name,
        'shaderFiltersSupported': ui.ImageFilter.isShaderFilterSupported,
        'refreshRate': refresh,
        'frameBudgetMs': budget,
        'windowLogicalSize': MediaQuery.sizeOf(context).toString(),
        'rssBytes': ProcessInfo.currentRss,
        'idleFramesIn3Seconds': idleFrames,
        'rounds': rounds,
        'limits': [
          'render captures, not OS screenshots',
          'not other-device acceptance',
          'not first-interactive or long-term memory acceptance',
        ],
      };
      await File(
        '${output.path}/report.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      debugPrint('GLASS_PROBE_OUTPUT=${output.path}');
      setState(() => status = '已完成：${output.path}');
    } catch (e, stack) {
      debugPrint('GLASS_PROBE_FAILED: $e\n$stack');
      if (mounted) setState(() => status = '检查失败：$e');
    } finally {
      collecting = false;
      if (mounted) setState(() => running = false);
    }
  }

  Map<String, Object?> _summary(
    GlassMaterialMode mode,
    int round,
    double budget,
  ) {
    double? percentile(List<double> values, double fraction) {
      if (values.isEmpty) return null;
      values.sort();
      return values[((values.length - 1) * fraction).ceil()];
    }

    final build = frames
        .map((f) => f.buildDuration.inMicroseconds / 1000)
        .toList();
    final raster = frames
        .map((f) => f.rasterDuration.inMicroseconds / 1000)
        .toList();
    return {
      'requestedMode': mode.name,
      'effective': AppGlassScope.of(context).fallback.name,
      'round': round,
      'invalidReasons': invalidReasons.toList(),
      'frames': frames.length,
      'buildP95Ms': percentile([...build], .95),
      'rasterP95Ms': percentile([...raster], .95),
      'buildMaxMs': build.isEmpty ? null : build.reduce(math.max),
      'rasterMaxMs': raster.isEmpty ? null : raster.reduce(math.max),
      'missedFrameFraction': frames.isEmpty
          ? null
          : frames
                    .where(
                      (f) =>
                          f.buildDuration.inMicroseconds / 1000 > budget ||
                          f.rasterDuration.inMicroseconds / 1000 > budget,
                    )
                    .length /
                frames.length,
      'rawBuildMs': build,
      'rawRasterMs': raster,
    };
  }

  @override
  Widget build(BuildContext context) {
    final policy = AppGlassScope.of(context);
    return RepaintBoundary(
      key: captureKey,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('U2 · 离线材质实验'),
                    ChoiceChip(
                      label: const Text('液态玻璃'),
                      selected: widget.mode == GlassMaterialMode.liquid,
                      onSelected: (_) =>
                          widget.onModeChanged(GlassMaterialMode.liquid),
                    ),
                    ChoiceChip(
                      label: const Text('清晰模式'),
                      selected: widget.mode == GlassMaterialMode.clear,
                      onSelected: (_) =>
                          widget.onModeChanged(GlassMaterialMode.clear),
                    ),
                    Text(
                      'runtime=${widget.runtime.state.name} / ${policy.fallback.name}',
                    ),
                    TextButton(
                      onPressed: running ? null : benchmark,
                      child: const Text('运行 3×30 秒对照'),
                    ),
                    TextButton(
                      onPressed: running
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              builder: (_) => const RefractionComparison(),
                            ),
                      child: const Text('折射 A/B 对照'),
                    ),
                  ],
                ),
              ),
              ExcludeFocus(
                excluding: running,
                child: IgnorePointer(ignoring: running, child: widget.controls),
              ),
              Text(status, maxLines: 1, overflow: TextOverflow.ellipsis),
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.only(bottom: 140),
                      itemCount: 36,
                      itemExtent: 120,
                      itemBuilder: (context, index) => CustomPaint(
                        painter: _Pattern(index),
                        child: Center(
                          child: Text(
                            '背景 ${index + 1} / Aa 枝江 0123456789',
                            style: TextStyle(
                              fontSize: 18,
                              color: index.isEven ? Colors.black : Colors.white,
                              backgroundColor: index.isEven
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      top: 16,
                      child: AppGlassSurface(
                        nativeContent: widget.nativeContent,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '刷新原型',
                              onPressed: () => setState(() => actions++),
                              icon: const Icon(Icons.refresh),
                            ),
                            IconButton(
                              tooltip: '筛选原型',
                              onPressed: _panel,
                              icon: const Icon(Icons.tune),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text('$actions'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: ProbeNavigation(
                            selected: selected,
                            nativeContent: widget.nativeContent,
                            toolsFocus: toolsFocus,
                            onSelect: (index) =>
                                setState(() => selected = index),
                            onTools: _panel,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Five-slot prototype, with Tools deliberately excluded from drag dispatch.
class ProbeNavigation extends StatefulWidget {
  const ProbeNavigation({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onTools,
    required this.toolsFocus,
    this.nativeContent = false,
  });
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onTools;
  final FocusNode toolsFocus;
  final bool nativeContent;
  @override
  State<ProbeNavigation> createState() => _ProbeNavigationState();
}

class _ProbeNavigationState extends State<ProbeNavigation>
    with SingleTickerProviderStateMixin {
  late final AnimationController press = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );
  int? dragIndex;
  bool reduceMotion = false;
  static const labels = ['今日', '内容', '工具', '日历', '我的'];
  static const icons = [
    Icons.home_outlined,
    Icons.grid_view_rounded,
    Icons.workspaces_outline,
    Icons.calendar_month_outlined,
    Icons.person_outline,
  ];

  void _press(bool down) {
    if (reduceMotion) {
      press.value = 0;
      return;
    }
    press.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 360, damping: 26),
        press.value,
        down ? 1 : 0,
        0,
      ),
    );
  }

  @override
  void dispose() {
    press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    reduceMotion = !AppGlassScope.of(context).canAnimate;
    if (reduceMotion && press.isAnimating) press.stop();
    return LayoutBuilder(
      builder: (context, constraints) {
        int indexAt(double x) =>
            (x / (constraints.maxWidth / 5)).floor().clamp(0, 4);
        return GestureDetector(
          onHorizontalDragStart: (d) {
            _press(true);
            setState(() => dragIndex = indexAt(d.localPosition.dx));
          },
          onHorizontalDragUpdate: (d) =>
              setState(() => dragIndex = indexAt(d.localPosition.dx)),
          onHorizontalDragEnd: (_) {
            final index = dragIndex;
            setState(() => dragIndex = null);
            _press(false);
            if (index != null && index != 2) widget.onSelect(index);
          },
          onHorizontalDragCancel: () {
            setState(() => dragIndex = null);
            _press(false);
          },
          child: AnimatedBuilder(
            animation: press,
            builder: (context, child) => AppGlassSurface(
              press: press.value,
              nativeContent: widget.nativeContent,
              child: child!,
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i != 2 && widget.selected == i,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            focusNode: i == 2 ? widget.toolsFocus : null,
                            borderRadius: BorderRadius.circular(18),
                            onHighlightChanged: _press,
                            onTap: () =>
                                i == 2 ? widget.onTools() : widget.onSelect(i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color:
                                          (dragIndex ?? widget.selected) == i &&
                                              i != 2
                                          ? const Color(0xFFF8E8EE)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      child: Icon(
                                        icons[i],
                                        size: 23,
                                        color:
                                            (dragIndex ?? widget.selected) ==
                                                    i &&
                                                i != 2
                                            ? const Color(0xFF8A3E59)
                                            : null,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    labels[i],
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Pattern extends CustomPainter {
  _Pattern(this.index);
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFE799B0),
      Color(0xFFFAFAFA),
      Color(0xFF202024),
      Color(0xFF7BD5D5),
    ];
    final paint = Paint();
    for (var y = 0.0; y < size.height; y += 20) {
      for (var x = 0.0; x < size.width; x += 20) {
        paint.color =
            colors[((x / 20).floor() + (y / 20).floor() + index) %
                colors.length];
        canvas.drawRect(Rect.fromLTWH(x, y, 20, 20), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Pattern oldDelegate) => oldDelegate.index != index;
}
