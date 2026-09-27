import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:asasfans_next/app/asasfans_app.dart';
import 'package:asasfans_next/app/glass_providers.dart';
import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/app/router/app_router.dart';
import 'package:asasfans_next/core/config/app_environment.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/core/platform/return_entry_service.dart';
import 'package:asasfans_next/features/account/application/account_providers.dart';
import 'package:asasfans_next/core/time/shanghai_date_provider.dart';
import 'package:asasfans_next/features/calendar/application/calendar_providers.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_image_viewer.dart';
import 'package:asasfans_next/features/novels/application/novel_providers.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../test/helpers/account_fixture.dart';
import '../../test/helpers/library_fixture.dart';
import '../../test/helpers/preferences_fixture.dart';
import '../../test/visual/visual_fixture.dart';
import 'perf_fixture.dart';

/// Profile-mode run of one fixed scenario on the real app (see
/// tool/README.md). Offline and in memory: no personal database, no
/// network. Prints one `PERF_RESULT <json>` line and exits.
///
/// Every setting comes from --dart-define, so two builds differ only in
/// what the command line says:
///   ASASFANS_PERF_GLASS   smooth | auto | visual   (the 材质 preference)
///   ASASFANS_PERF_LABEL   name of the run
///   ASASFANS_PERF_COMMIT  the source commit being measured
///   ASASFANS_PERF_SCROLL_SECONDS  length of the scroll phase (default 60)
const _glass = String.fromEnvironment(
  'ASASFANS_PERF_GLASS',
  defaultValue: 'auto',
);
const _label = String.fromEnvironment(
  'ASASFANS_PERF_LABEL',
  defaultValue: 'run',
);
const _commit = String.fromEnvironment(
  'ASASFANS_PERF_COMMIT',
  defaultValue: 'unknown',
);
const _scrollSeconds = int.fromEnvironment(
  'ASASFANS_PERF_SCROLL_SECONDS',
  defaultValue: 60,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final generation = Stopwatch()..start();
  final images = await generatePerfImages();
  generation.stop();
  HttpOverrides.global = PerfHttpOverrides(images);
  final choice = GlassChoice.values.byName(_glass);
  runApp(
    ProviderScope(
      overrides: [
        // Personal state is a disposable in-memory database; no link,
        // credential or return entry reaches the platform.
        ...offlineLibrary(),
        biliVaultProvider.overrideWith((_) => MemoryAccountVault()),
        biliLoginCookiesProvider.overrideWith((_) => MemoryLoginCookies()),
        externalLinkServiceProvider.overrideWithValue(const _NoLinks()),
        returnEntryServiceProvider.overrideWithValue(
          const UnsupportedReturnEntryService(),
        ),
        appEnvironmentProvider.overrideWithValue(
          AppEnvironment(
            dynamicApiBaseUrl: Uri.parse('https://perf.invalid/api/'),
            calendarUrl: Uri.parse('https://perf.invalid/calendar.ics'),
          ),
        ),
        observeGlassRendererErrors(),
        offlinePreferences(const AppPreferences().withGlass(choice)),
        currentTimeProvider.overrideWithValue(() => fixtureNow),
        fanartRepositoryProvider.overrideWithValue(PerfFanart()),
        communityVideoRepositoryProvider.overrideWithValue(FixtureVideos()),
        dynamicRepositoryProvider.overrideWithValue(FixtureDynamics()),
        novelRepositoryProvider.overrideWithValue(FixtureNovels()),
        calendarRepositoryProvider.overrideWithValue(FixtureCalendar()),
      ],
      child: const AsasfansApp(),
    ),
  );
  final result = await _Run(generation.elapsedMilliseconds, images).run();
  final json = jsonEncode(result);
  // ignore: avoid_print
  print('PERF_RESULT $json');
  File(
    '${Directory.systemTemp.path}/asasfans_perf_$_label.json',
  ).writeAsStringSync(json);
  exit(0);
}

class _NoLinks implements ExternalLinkService {
  const _NoLinks();
  @override
  Future<bool> open(Uri uri) async => false;
}

class _Run with WidgetsBindingObserver {
  _Run(this.imageGenerationMs, this.images);
  final int imageGenerationMs;
  final Map<String, Uint8List> images;
  final _frames = <ui.FrameTiming>[];
  final _phases = <Map<String, Object?>>[];
  WidgetsBinding get _binding => WidgetsBinding.instance;
  static const _device = 7001;
  var _pointer = 0;

  /// Lifecycle states seen during the current phase. A window that is not
  /// frontmost and visible gets few or no frames, and its glass falls back
  /// to solid: such a phase is marked, never counted as a result.
  final _states = <String>{};

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _states.add(state.name);

  Future<Map<String, Object?>> run() async {
    _binding.addTimingsCallback(_frames.addAll);
    _binding.addObserver(this);
    // The glass runtime loads after the first usable frame; let it settle.
    await _until(() => _find<AppGlassScope>().isNotEmpty);
    // The script brings the window to the front; wait for it.
    await _until(() => _binding.lifecycleState == AppLifecycleState.resumed);
    await _wait(3000);
    final env = _environment();
    _binding.handlePointerEvent(
      const PointerAddedEvent(device: _device, kind: PointerDeviceKind.mouse),
    );
    for (final pass in ['cold', 'warm']) {
      await _pass(pass);
    }
    return {
      'label': _label,
      'commit': _commit,
      'fixture': perfFixtureRevision,
      'image_generation_ms': imageGenerationMs,
      'image_bytes': {
        for (final MapEntry(:key, :value) in images.entries) key: value.length,
      },
      'environment': env,
      'phases': _phases,
    };
  }

  Map<String, Object?> _environment() {
    final view = _binding.platformDispatcher.views.first;
    final context = _find<Scaffold>().first;
    final policy = AppGlassScope.of(context);
    return {
      'build_mode': kProfileMode
          ? 'profile'
          : kReleaseMode
          ? 'release'
          : 'debug',
      'os': Platform.operatingSystemVersion,
      'cpus': Platform.numberOfProcessors,
      'logical_size': [
        view.physicalSize.width / view.devicePixelRatio,
        view.physicalSize.height / view.devicePixelRatio,
      ],
      'device_pixel_ratio': view.devicePixelRatio,
      'refresh_rate': view.display.refreshRate,
      'platform_brightness':
          _binding.platformDispatcher.platformBrightness.name,
      'text_scale': _binding.platformDispatcher.textScaleFactor,
      // Shader image filters exist only on Impeller.
      'shader_filters_supported': ui.ImageFilter.isShaderFilterSupported,
      'glass_preference': _glass,
      'glass_tier_effective': policy.tier.name,
      'glass_fallback': policy.fallback.name,
      'image_cache_limits': {
        'entries': PaintingBinding.instance.imageCache.maximumSize,
        'bytes': PaintingBinding.instance.imageCache.maximumSizeBytes,
      },
    };
  }

  Future<void> _pass(String pass) async {
    final router = ProviderScope.containerOf(
      _find<AsasfansApp>().first,
    ).read(appRouterProvider);

    // 1. Enter 二创 from Today: until the first tile, then its first image.
    router.go('/today');
    await _wait(1500);
    await _phase('$pass/enter-fanart', () async {
      final clock = Stopwatch()..start();
      router.go('/content/fanart');
      await _until(() => _find<FanartCard>().isNotEmpty);
      final tile = clock.elapsedMilliseconds;
      await _until(() => _decoded(under: _find<FanartCard>()).isNotEmpty);
      return {
        'first_tile_ms': tile,
        'first_image_ms': clock.elapsedMilliseconds,
      };
    });

    // 2. Wheel scrolling: down, a little up, down again.
    final feedTop = _feedPosition()?.pixels ?? 0;
    await _phase('$pass/scroll', () async {
      final total = _scrollSeconds * 1000;
      await _scroll(14, (total * .65).round());
      await _scroll(-14, (total * .15).round());
      await _scroll(14, (total * .2).round());
      return {
        'scrolled_from': feedTop,
        'scrolled_to': _feedPosition()?.pixels,
        'tiles_built': _find<FanartCard>().length,
      };
    });
    double? beforeDetail, afterDetail;

    // 3. A long strip: tile → detail → whole strip → back twice.
    await _phase('$pass/long-image', () async {
      var strip = _longTile();
      for (var step = 0; strip == null && step < 40; step++) {
        await _scroll(14, 300);
        strip = _longTile();
      }
      if (strip == null) return {'error': 'no long strip on screen'};
      beforeDetail = _feedPosition()?.pixels;
      final clock = Stopwatch()..start();
      await _tapAt(strip);
      await _until(() => _find<FanartDetailPage>().isNotEmpty);
      await _until(() => _decoded(under: _find<FanartDetailPage>()).isNotEmpty);
      final detail = clock.elapsedMilliseconds;
      final detailImages = _decodedSizes(_find<FanartDetailPage>());
      await _wait(800);
      final whole = _text('看完整长图');
      int? viewer;
      List<Object?> viewerImages = const [];
      if (whole != null) {
        clock.reset();
        await _tapAt(_rect(whole)!.center);
        await _until(
          () => _decoded(under: _find<FanartImageViewer>()).isNotEmpty,
        );
        viewer = clock.elapsedMilliseconds;
        viewerImages = _decodedSizes(_find<FanartImageViewer>());
        await _wait(1500);
        await Navigator.of(_find<FanartImageViewer>().first).maybePop();
        await _wait(900);
      }
      await Navigator.of(_find<FanartDetailPage>().first).maybePop();
      await _wait(900);
      afterDetail = _feedPosition()?.pixels;
      return {
        'tap_to_detail_image_ms': detail,
        'detail_images': detailImages,
        'tap_to_viewer_image_ms': viewer,
        'viewer_images': viewerImages,
      };
    });

    // 4. Every channel, then every main tab, and back to 二创.
    await _phase('$pass/channels-and-tabs', () async {
      for (final location in [
        '/content/videos',
        '/content/dynamics',
        '/content/novels',
        '/content/fanart',
        '/today',
        '/calendar',
        '/mine',
        '/content/fanart',
      ]) {
        router.go(location);
        await _wait(1200);
      }
      return {
        'offset_before_detail': beforeDetail,
        'offset_after_detail': afterDetail,
        'offset_after_round_trip': _feedPosition()?.pixels,
      };
    });
    // The warm pass starts from the top of the same, already loaded feed.
    _feedPosition()?.jumpTo(0);
  }

  Future<void> _phase(
    String name,
    Future<Map<String, Object?>> Function() body,
  ) async {
    await _wait(500);
    _frames.clear();
    _states
      ..clear()
      ..add(_binding.lifecycleState?.name ?? 'unknown');
    final clock = Stopwatch()..start();
    final notes = await body();
    // Frames still in flight belong to this phase; timings arrive within
    // 100 ms in profile mode.
    await _wait(500);
    final frames = List.of(_frames);
    final context = _find<Scaffold>().firstOrNull;
    _phases.add({
      'name': name,
      'wall_ms': clock.elapsedMilliseconds,
      'lifecycle': _states.toList(),
      'valid': _states.length == 1 && _states.single == 'resumed',
      'glass_tier_effective': context == null
          ? null
          : AppGlassScope.of(context).tier.name,
      ...notes,
      'frames': _stats(frames),
      'memory': _memory(),
    });
  }

  Map<String, Object?> _stats(List<ui.FrameTiming> frames) {
    final refresh = _binding.platformDispatcher.views.first.display.refreshRate;
    final budget = 1000 / (refresh > 0 ? refresh : 60);
    double ms(Duration d) => d.inMicroseconds / 1000;
    Map<String, Object?> of(List<double> values) {
      if (values.isEmpty) return {};
      values.sort();
      double at(double q) =>
          values[math.min(values.length - 1, (values.length * q).floor())];
      return {
        'p50': at(.5),
        'p95': at(.95),
        'p99': at(.99),
        'max': values.last,
        'over_budget_ratio':
            values.where((v) => v > budget).length / values.length,
      };
    }

    return {
      'count': frames.length,
      'budget_ms': budget,
      'ui_build': of([for (final f in frames) ms(f.buildDuration)]),
      'raster': of([for (final f in frames) ms(f.rasterDuration)]),
      'total_span': of([for (final f in frames) ms(f.totalSpan)]),
    };
  }

  Map<String, Object?> _memory() {
    final cache = PaintingBinding.instance.imageCache;
    final shown = _decodedSizes(null);
    return {
      'rss_mb': ProcessInfo.currentRss / (1 << 20),
      'max_rss_mb': ProcessInfo.maxRss / (1 << 20),
      'image_cache_entries': cache.currentSize,
      'image_cache_mb': cache.currentSizeBytes / (1 << 20),
      'live_images': cache.liveImageCount,
      'pending_images': cache.pendingImageCount,
      'painted_images': shown.length,
      'painted_decoded_mpx':
          shown.fold<int>(0, (sum, s) => sum + (s['px'] as int)) / 1e6,
    };
  }

  // ---- finding things in the running app ----

  Iterable<Element> _all() sync* {
    final root = _binding.rootElement;
    if (root == null) return;
    final stack = <Element>[root];
    while (stack.isNotEmpty) {
      final element = stack.removeLast();
      yield element;
      element.visitChildren(stack.add);
    }
  }

  List<Element> _find<T extends Widget>() => [
    for (final element in _all())
      if (element.widget is T && _onstage(element)) element,
  ];

  bool _onstage(Element element) {
    var onstage = true;
    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      if (widget is Offstage && widget.offstage) onstage = false;
      return onstage;
    });
    return onstage;
  }

  Element? _text(String value) =>
      _find<Text>().where((e) => (e.widget as Text).data == value).firstOrNull;

  /// A long strip's tile whose cover top is in the clear part of the
  /// window, and the point on its cover to tap.
  Offset? _longTile() {
    final view = _binding.platformDispatcher.views.first;
    final height = view.physicalSize.height / view.devicePixelRatio;
    for (final element in _find<FanartCard>()) {
      final card = element.widget as FanartCard;
      if (!card.item.images.any((uri) => uri.path.contains('/long/'))) {
        continue;
      }
      final rect = _rect(element);
      if (rect != null && rect.top > 60 && rect.top < height - 200) {
        return Offset(rect.center.dx, rect.top + 40);
      }
    }
    return null;
  }

  Rect? _rect(Element element) {
    final box = element.renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  ScrollPosition? _feedPosition() {
    for (final element in _find<Scrollable>()) {
      if ((element as StatefulElement).state case final ScrollableState state
          when state.widget.axisDirection == AxisDirection.down &&
              _ancestorKey(element, const PageStorageKey('fanart-feed'))) {
        return state.position;
      }
    }
    return null;
  }

  bool _ancestorKey(Element element, Key key) {
    var found = false;
    element.visitAncestorElements((ancestor) {
      found = ancestor.widget.key == key;
      return !found;
    });
    return found;
  }

  /// Images drawn right now (under [roots], or anywhere): their decoded
  /// pixel size and the logical box they are drawn in.
  List<RenderImage> _decoded({List<Element>? under}) {
    final out = <RenderImage>[];
    void visit(RenderObject object) {
      if (object is RenderImage && object.image != null) out.add(object);
      object.visitChildren(visit);
    }

    for (final root in under ?? [_binding.rootElement!]) {
      final object = root.renderObject;
      if (object != null) visit(object);
    }
    return out;
  }

  List<Map<String, Object?>> _decodedSizes(List<Element>? under) => [
    for (final image in _decoded(under: under))
      {
        'decoded': [image.image!.width, image.image!.height],
        'px': image.image!.width * image.image!.height,
        'box': image.hasSize
            ? [image.size.width.round(), image.size.height.round()]
            : null,
      },
  ];

  // ---- input and time ----

  Future<void> _tapAt(Offset at) async {
    final pointer = ++_pointer;
    _binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        device: _device,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
        position: at,
      ),
    );
    await _wait(60);
    _binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        device: _device,
        kind: PointerDeviceKind.mouse,
        position: at,
      ),
    );
  }

  /// One wheel step per 16 ms at the middle of the window.
  Future<void> _scroll(double step, int milliseconds) async {
    final view = _binding.platformDispatcher.views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    final at = Offset(size.width * .55, size.height * .6);
    final clock = Stopwatch()..start();
    while (clock.elapsedMilliseconds < milliseconds) {
      _binding.handlePointerEvent(
        PointerScrollEvent(
          device: _device,
          kind: PointerDeviceKind.mouse,
          position: at,
          scrollDelta: Offset(0, step),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _wait(int milliseconds) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));

  /// Polls once a frame for [test], for at most 20 s.
  Future<void> _until(bool Function() test) async {
    final clock = Stopwatch()..start();
    while (!test()) {
      if (clock.elapsed > const Duration(seconds: 20)) {
        throw TimeoutException('perf run: condition not met');
      }
      _binding.scheduleFrame();
      await _binding.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 4));
    }
  }
}
