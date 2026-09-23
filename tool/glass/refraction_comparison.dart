import 'dart:io';
import 'dart:ui' as ui;

import 'package:asasfans_next/shared/widgets/glass/app_glass_scope.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Same local grid, shape, blur, light, tint and size; only the optical index
/// differs. This is evidence tooling, never part of production preferences.
class RefractionComparison extends StatefulWidget {
  const RefractionComparison({super.key});
  @override
  State<RefractionComparison> createState() => _RefractionComparisonState();
}

class _RefractionComparisonState extends State<RefractionComparison> {
  final boundaryKey = GlobalKey();
  String status = '';

  Future<void> _save() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final policy = AppGlassScope.of(context);
    if (!policy.usesLiquid) {
      setState(() => status = '当前是清晰回退，不能作为折射证据。');
      return;
    }
    try {
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = await Directory.systemTemp.createTemp(
          'asasfans-refraction-',
        );
        await File('${directory.path}/comparison.png').writeAsBytes(
          bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        debugPrint('GLASS_REFRACTION_OUTPUT=${directory.path}');
        if (mounted) setState(() => status = directory.path);
      } finally {
        image.dispose();
      }
    } catch (error) {
      if (mounted) setState(() => status = '保存失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: Text('折射 A/B · 只改变光学折射率')),
                IconButton(
                  tooltip: '关闭对照',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text('实际路径：${AppGlassScope.of(context).fallback.name}'),
            RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: Colors.white,
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final index in [1.0, 1.22])
                      SizedBox(
                        width: 256,
                        child: Column(
                          children: [
                            Text(
                              'n = $index',
                              style: const TextStyle(color: Colors.black),
                            ),
                            SizedBox(
                              width: 256,
                              height: 180,
                              child: Stack(
                                children: [
                                  const Positioned.fill(
                                    child: CustomPaint(
                                      painter: RefractionGridPainter(),
                                    ),
                                  ),
                                  Positioned(
                                    left: 20,
                                    right: 20,
                                    top: 35,
                                    bottom: 35,
                                    child: AppGlassSurface(
                                      refractiveIndex: index,
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Text('比较网格穿过镜片边缘的位置；相同模糊不能解释边界位移。'),
            TextButton(onPressed: _save, child: const Text('保存渲染对照')),
            Text(status, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ),
  );
}

class RefractionGridPainter extends CustomPainter {
  const RefractionGridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    // CustomPaint does not clip the canvas to size. drawColor would cover the
    // other comparison tile and dialog controls, invalidating the A/B scene.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE799B0),
    );
    final paint = Paint()
      ..color = const Color(0xFF222225)
      ..strokeWidth = 2;
    for (var x = 8.0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 8.0; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(RefractionGridPainter oldDelegate) => false;
}
