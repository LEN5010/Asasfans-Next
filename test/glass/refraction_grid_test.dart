import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/glass/refraction_comparison.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'comparison grid paints only its own tile, not the other pane or dialog',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 200, 200),
        ui.Paint()..color = const ui.Color(0xFF00FF00),
      );
      canvas.save();
      canvas.translate(50, 50);
      const RefractionGridPainter().paint(canvas, const ui.Size(100, 100));
      canvas.restore();
      final picture = recorder.endRecording();
      final image = await picture.toImage(200, 200);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final rgba = data!.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        List<int> pixel(int x, int y) =>
            rgba.sublist((y * 200 + x) * 4, (y * 200 + x) * 4 + 4);
        expect(pixel(10, 10), [0, 255, 0, 255]);
        expect(pixel(190, 190), [0, 255, 0, 255]);
        expect(pixel(51, 51), [231, 153, 176, 255]);
      } finally {
        image.dispose();
        picture.dispose();
      }
    },
  );
}
