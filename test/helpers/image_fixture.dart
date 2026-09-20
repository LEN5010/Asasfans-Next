import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real deterministic raster content, seeded at the exact ImageProvider key.
/// The widget exercises real raster dimensions/layout without network I/O.
Future<void> cacheImageFixture(
  WidgetTester tester,
  Uri uri, {
  int width = 320,
  int height = 200,
  int? cacheWidth,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFE799B0),
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(0, height * .7, width.toDouble(), height * .3),
    ui.Paint()..color = const ui.Color(0xFF8A3E59),
  );
  final picture = recorder.endRecording();
  final image = await tester.runAsync(() => picture.toImage(width, height));
  picture.dispose();
  final provider = ResizeImage.resizeIfNeeded(
    cacheWidth,
    null,
    NetworkImage(uri.toString()),
  );
  final key = await provider.obtainKey(const ImageConfiguration());
  PaintingBinding.instance.imageCache.putIfAbsent(
    key,
    () => OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: image!)),
    ),
  );
  addTearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
}
