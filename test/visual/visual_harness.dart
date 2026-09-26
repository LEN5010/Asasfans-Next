import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:asasfans_next/app/asasfans_app.dart';
import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/app/router/app_router.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/core/time/shanghai_date_provider.dart';
import 'package:asasfans_next/features/calendar/application/calendar_providers.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/novels/application/novel_providers.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/library_fixture.dart';
import '../helpers/preferences_fixture.dart';
import 'visual_fixture.dart';

/// Real-widget screenshots, headless.
///
/// The suite always runs as a layout smoke test. It writes PNGs only when
/// `ASASFANS_VISUAL_OUT` names a directory and a CJK font was found, so a
/// machine without one never produces tofu screenshots that look like
/// evidence. What it renders is the software rasterizer of flutter_tester:
/// the Solid material, fonts from this machine, no GPU, no device.
abstract final class Visual {
  static String? _fonts;

  /// The fonts actually loaded, for the manifest; null when no CJK font.
  static String? get fontEnvironment => _fonts;

  static String? get outDir {
    final dir = Platform.environment['ASASFANS_VISUAL_OUT'];
    return dir == null || dir.isEmpty ? null : dir;
  }

  static bool get capturing => outDir != null && _fonts != null;

  static final _images = <String, Uint8List>{};

  /// Loads fonts and generates the fixture artwork. Call from setUpAll.
  static Future<void> setUp() async {
    _fonts = await _loadFonts();
    for (final entry in fixtureImages.entries) {
      _images[entry.key] = await _artwork(
        entry.key,
        entry.value.$1,
        entry.value.$2,
      );
    }
  }

  static const _cjkCandidates = [
    '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc',
    '/System/Library/Fonts/PingFang.ttc',
    r'C:\Windows\Fonts\msyh.ttc',
  ];

  /// One CJK face stands in for the platform's Roboto + CJK fallback, so
  /// Latin glyphs come from it too. Icons come from the SDK's own font.
  /// Nothing is copied into the repository or the app.
  static Future<String?> _loadFonts() async {
    final configured = Platform.environment['ASASFANS_CJK_FONT'];
    final cjk = [
      if (configured != null && configured.isNotEmpty) configured,
      ..._cjkCandidates,
    ].map(File.new).where((file) => file.existsSync()).firstOrNull;
    if (cjk == null) return null;
    final bytes = ByteData.sublistView(cjk.readAsBytesSync());
    // The theme's family, plus the generic names a device resolves itself.
    for (final family in ['Roboto', 'serif', 'sans-serif', 'monospace']) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    final icons = _sdkFile('material_fonts/MaterialIcons-Regular.otf');
    if (icons != null) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await loader.load();
    }
    return '${cjk.path} as Roboto/serif/monospace (Latin too)'
        '${icons == null ? '; no icon font' : '; MaterialIcons from SDK'}';
  }

  /// flutter_tester lives in `bin/cache/artifacts/engine/<host>/`.
  static File? _sdkFile(String relative) {
    final tester = File(Platform.resolvedExecutable);
    final artifacts = tester.parent.parent.parent;
    final file = File('${artifacts.path}/$relative');
    return file.existsSync() ? file : null;
  }

  /// Self-drawn artwork: a gradient, a horizon and a few shapes, seeded by
  /// name so each image differs and stays the same between runs.
  static Future<Uint8List> _artwork(String name, int width, int height) async {
    final seed = name.codeUnits.fold(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    final random = math.Random(seed);
    Color hue(double h, double s, double l) =>
        HSLColor.fromAHSL(1, h % 360, s, l).toColor();
    final base = random.nextDouble() * 360;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          hue(base, .55, .82),
          hue(base + 40, .45, .62),
        ]),
    );
    if (name.startsWith('diag-')) {
      _diagnostic(canvas, name, size);
    } else if (name.startsWith('avatar')) {
      canvas.drawCircle(
        size.center(Offset.zero),
        size.width * .28,
        Paint()..color = hue(base + 180, .4, .95),
      );
    } else {
      for (var i = 0; i < 5; i++) {
        canvas.drawCircle(
          Offset(
            random.nextDouble() * size.width,
            random.nextDouble() * size.height * .7,
          ),
          size.shortestSide * (.08 + random.nextDouble() * .18),
          Paint()..color = hue(base + 120 + i * 25, .5, .75).withAlpha(200),
        );
      }
      final hill = Path()..moveTo(0, size.height * .72);
      for (var x = 0.0; x <= size.width; x += size.width / 8) {
        hill.lineTo(x, size.height * (.64 + random.nextDouble() * .12));
      }
      hill
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(hill, Paint()..color = hue(base + 200, .35, .38));
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }

  static const edgeLeft = Color(0xFFE53935);
  static const edgeRight = Color(0xFF1E88E5);
  static const edgeTop = Color(0xFF43A047);
  static const edgeBottom = Color(0xFFFDD835);

  /// Diagnostic art: a flat ground with a coloured band and a label on each
  /// edge (red left, blue right, green top, yellow bottom) and a mark in the
  /// centre; a strip is six numbered panels. White and black are flat, for
  /// checking what is drawn over them.
  static void _diagnostic(ui.Canvas canvas, String name, Size size) {
    final white = name.endsWith('white');
    final black = name.endsWith('black');
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = white
            ? const Color(0xFFFFFFFF)
            : black
            ? const Color(0xFF000000)
            : const Color(0xFF9E9E9E),
    );
    void label(String text, Offset at, {Color color = Colors.black}) {
      final builder =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(
                textAlign: TextAlign.center,
                fontFamily: 'Roboto',
                fontSize: size.shortestSide * .06,
              ),
            )
            ..pushStyle(ui.TextStyle(color: color))
            ..addText(text);
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: size.shortestSide * .5));
      canvas.drawParagraph(
        paragraph,
        at - Offset(paragraph.width / 2, paragraph.height / 2),
      );
    }

    if (white || black) {
      label('明暗', size.center(Offset.zero), color: const Color(0xFF808080));
      return;
    }
    if (name.endsWith('strip')) {
      final panel = size.height / 6;
      for (var i = 0; i < 6; i++) {
        canvas.drawRect(
          Rect.fromLTWH(0, i * panel, size.width, panel),
          Paint()..color = HSLColor.fromAHSL(1, i * 50.0, .3, .7).toColor(),
        );
        canvas.drawRect(
          Rect.fromLTWH(0, i * panel, size.width, size.width * .01),
          Paint()..color = const Color(0xFF000000),
        );
        label('第 ${i + 1} 格', Offset(size.width / 2, (i + .5) * panel));
      }
    }
    final band = size.shortestSide * .06;
    canvas
      ..drawRect(
        Rect.fromLTWH(0, 0, band, size.height),
        Paint()..color = edgeLeft,
      )
      ..drawRect(
        Rect.fromLTWH(size.width - band, 0, band, size.height),
        Paint()..color = edgeRight,
      )
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width, band),
        Paint()..color = edgeTop,
      )
      ..drawRect(
        Rect.fromLTWH(0, size.height - band, size.width, band),
        Paint()..color = edgeBottom,
      )
      ..drawRect(
        Rect.fromCenter(
          center: size.center(Offset.zero),
          width: band * 2,
          height: band * 2,
        ),
        Paint()..color = const Color(0xFF000000),
      );
    label(
      '左边的字',
      Offset(band * 1.2 + size.shortestSide * .25, size.height / 2),
    );
    label(
      '右边的字',
      Offset(
        size.width - band * 1.2 - size.shortestSide * .25,
        size.height / 2,
      ),
    );
  }

  /// Serves fixture artwork for any `fixture.invalid` image; 404 otherwise,
  /// so a screenshot never depends on a real server.
  static HttpClient httpClient() => _FixtureHttpClient(_images);
}

/// One capture setting: logical size, pixel ratio, text scale, brightness.
class VisualView {
  const VisualView(
    this.name,
    this.size, {
    this.pixelRatio = 2,
    this.textScale = 1,
    this.brightness = Brightness.light,
    this.safeArea = EdgeInsets.zero,
    this.keyboard = 0,
  });
  final String name;
  final Size size;
  final double pixelRatio;
  final double textScale;
  final Brightness brightness;

  /// System bars (status bar, gesture area), in logical px.
  final EdgeInsets safeArea;

  /// Height of an open soft keyboard, in logical px.
  final double keyboard;

  /// A phone with a notch-height status bar and a gesture bar.
  VisualView get withSystemBars => VisualView(
    '$name-bars',
    size,
    pixelRatio: pixelRatio,
    textScale: textScale,
    brightness: brightness,
    safeArea: const EdgeInsets.only(top: 47, bottom: 34),
    keyboard: keyboard,
  );

  VisualView withKeyboard(double height) => VisualView(
    '$name-kb',
    size,
    pixelRatio: pixelRatio,
    textScale: textScale,
    brightness: brightness,
    safeArea: safeArea,
    keyboard: height,
  );

  VisualView get dark => VisualView(
    '$name-dark',
    size,
    pixelRatio: pixelRatio,
    textScale: textScale,
    brightness: Brightness.dark,
    safeArea: safeArea,
    keyboard: keyboard,
  );

  VisualView scaled(double scale) => VisualView(
    '$name-x$scale',
    size,
    pixelRatio: pixelRatio,
    textScale: scale,
    brightness: brightness,
    safeArea: safeArea,
    keyboard: keyboard,
  );

  static const phone = VisualView('390', Size(390, 844));
  static const narrow = VisualView('320', Size(320, 693));
  static const tablet = VisualView('840', Size(840, 1000), pixelRatio: 1);
  static const wide = VisualView('1280', Size(1280, 800), pixelRatio: 1);

  void apply(WidgetTester tester) {
    tester.view
      ..physicalSize = size * pixelRatio
      ..devicePixelRatio = pixelRatio
      ..padding = FakeViewPadding(
        top: safeArea.top * pixelRatio,
        bottom: safeArea.bottom * pixelRatio,
      )
      ..viewPadding = FakeViewPadding(
        top: safeArea.top * pixelRatio,
        bottom: safeArea.bottom * pixelRatio,
      )
      ..viewInsets = FakeViewPadding(bottom: keyboard * pixelRatio);
    tester.platformDispatcher
      ..textScaleFactorTestValue = textScale
      ..platformBrightnessTestValue = brightness;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }
}

final _root = GlobalKey();

/// The boundary [shoot] captures; wrap whatever is pumped in it.
Widget visualRoot(Widget child) => RepaintBoundary(key: _root, child: child);

/// A widget test with fixture images served. The image client is a painting
/// debug variable, which must be unset before the test body ends.
void testVisual(String description, WidgetTesterCallback body) =>
    testWidgets(description, (tester) async {
      // A load an earlier test left unfinished fails once its client is
      // gone; the shared cache would then serve that failure here.
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      debugNetworkImageHttpClientProvider = Visual.httpClient;
      try {
        await body(tester);
        // Unmount inside the body, so nothing loads an image afterwards.
        await tester.pumpWidget(const SizedBox());
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    });

class _Links implements ExternalLinkService {
  @override
  Future<bool> open(Uri uri) async => true;
}

/// Offline overrides for the whole app, backed by the fixture.
List<Override> visualOverrides({
  AppPreferences preferences = const AppPreferences(),
  List<Override> extra = const [],
}) => [
  ...offlineLibrary(),
  offlinePreferences(preferences),
  currentTimeProvider.overrideWithValue(() => fixtureNow),
  externalLinkServiceProvider.overrideWithValue(_Links()),
  fanartRepositoryProvider.overrideWithValue(FixtureFanart()),
  communityVideoRepositoryProvider.overrideWithValue(FixtureVideos()),
  dynamicRepositoryProvider.overrideWithValue(FixtureDynamics()),
  novelRepositoryProvider.overrideWithValue(FixtureNovels()),
  calendarRepositoryProvider.overrideWithValue(FixtureCalendar()),
  ...extra,
];

/// Pumps the real app at [location] and lets data and images arrive.
Future<ProviderContainer> pumpVisualApp(
  WidgetTester tester, {
  required VisualView view,
  String location = '/today',
  List<Override> overrides = const [],
}) async {
  view.apply(tester);
  await tester.pumpWidget(
    visualRoot(
      ProviderScope(
        overrides: overrides.isEmpty ? visualOverrides() : overrides,
        child: const AsasfansApp(),
      ),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(AsasfansApp)),
  );
  await settleVisual(tester);
  if (location != '/today') {
    container.read(appRouterProvider).go(location);
    await settleVisual(tester);
  }
  return container;
}

/// Lets futures, route transitions and image decoding finish. Fixed rounds
/// instead of pumpAndSettle, which a loading spinner would never let end.
Future<void> settleVisual(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 120));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pump(const Duration(seconds: 1));
}

/// Opens a route from inside the app, as a tap would.
Future<void> pushVisual(WidgetTester tester, Route<void> route) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  unawaited(navigator.push(route));
  await settleVisual(tester);
}

ProviderContainer visualContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AsasfansApp)));

GoRouter visualRouter(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(AsasfansApp)),
).read(appRouterProvider);

/// Top edge, in logical px from the window top, of the first on-screen
/// widget whose type is named [typeName] (private types included).
double? firstTop(WidgetTester tester, String typeName) {
  final tops = find
      .byWidgetPredicate((widget) => widget.runtimeType.toString() == typeName)
      .evaluate()
      .map(
        (element) =>
            tester.getTopLeft(find.byElementPredicate((e) => e == element)).dy,
      );
  return tops.isEmpty ? null : tops.reduce(math.min);
}

/// The pixels of the captured root, readable by logical position. Works in
/// ordinary test runs too, so a layout claim about what is visible can be
/// checked instead of only looked at.
class RenderedFrame {
  RenderedFrame._(this._rgba, this._width, this._ratio);
  final ByteData _rgba;
  final int _width;
  final double _ratio;

  Color at(Offset logical) {
    final x = (logical.dx * _ratio).floor();
    final y = (logical.dy * _ratio).floor();
    final offset = (y * _width + x) * 4;
    return Color.fromARGB(
      _rgba.getUint8(offset + 3),
      _rgba.getUint8(offset),
      _rgba.getUint8(offset + 1),
      _rgba.getUint8(offset + 2),
    );
  }

  /// True when the pixel at [logical] is within [tolerance] (0–255 per
  /// channel) of [expected].
  bool near(Offset logical, Color expected, {int tolerance = 40}) {
    final color = at(logical);
    int channel(double value) => (value * 255).round();
    return (channel(color.r) - channel(expected.r)).abs() <= tolerance &&
        (channel(color.g) - channel(expected.g)).abs() <= tolerance &&
        (channel(color.b) - channel(expected.b)).abs() <= tolerance;
  }
}

Future<RenderedFrame> grabFrame(WidgetTester tester, {double ratio = 1}) async {
  final boundary =
      _root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final frame = RenderedFrame._(data!, image.width, ratio);
    image.dispose();
    return frame;
  }))!;
}

/// Writes `<scenario>_<view>.png` and its manifest entry when capturing.
Future<void> shoot(
  WidgetTester tester,
  String scenario,
  VisualView view, {
  String provenance = 'actual-widget-render',
  String material = 'solid',
  String notes = '',
  Map<String, Object?> measurements = const {},
}) async {
  final dir = Visual.outDir;
  if (!Visual.capturing || dir == null) return;
  final file = '${scenario}_${view.name}.png';
  final boundary =
      _root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: view.pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  Directory(dir).createSync(recursive: true);
  File('$dir/$file').writeAsBytesSync(bytes!);
  final env = Platform.environment;
  File('$dir/$file.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'file': file,
      'commit': env['ASASFANS_VISUAL_COMMIT'] ?? 'unknown',
      'scenario': scenario,
      'fixture_revision': fixtureRevision,
      'viewport_logical': [view.size.width, view.size.height],
      if (view.safeArea != EdgeInsets.zero)
        'safe_area_logical': [view.safeArea.top, view.safeArea.bottom],
      if (view.keyboard > 0) 'keyboard_logical': view.keyboard,
      'device_pixel_ratio': view.pixelRatio,
      'text_scale': view.textScale,
      'brightness': view.brightness.name,
      'material': material,
      'renderer': 'headless-flutter-test (flutter_tester software raster)',
      'font_environment': Visual.fontEnvironment,
      'provenance': provenance,
      'reviewer': 'internal-review',
      if (measurements.isNotEmpty) 'measurements': measurements,
      'notes': [
        'not evidence of Impeller optics, GPU cost or real-device frame time',
        if (notes.isNotEmpty) notes,
      ].join('; '),
    }),
  );
}

class _FixtureHttpClient implements HttpClient {
  _FixtureHttpClient(this.images);
  final Map<String, Uint8List> images;

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final name = url.host == 'fixture.invalid'
        ? url.pathSegments.last.replaceAll('.png', '')
        : null;
    return _FixtureRequest(images[name]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixtureRequest implements HttpClientRequest {
  _FixtureRequest(this.bytes);
  final Uint8List? bytes;

  @override
  Future<HttpClientResponse> close() async => _FixtureResponse(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixtureResponse extends Stream<List<int>> implements HttpClientResponse {
  _FixtureResponse(this.bytes);
  final Uint8List? bytes;

  @override
  int get statusCode => bytes == null ? HttpStatus.notFound : HttpStatus.ok;

  @override
  int get contentLength => bytes?.length ?? 0;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable([
    ?bytes,
  ]).listen(onData, onError: onError, onDone: onDone, cancelOnError: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
