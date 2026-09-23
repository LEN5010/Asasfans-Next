import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/glass/app_glass_controls.dart';
import 'package:flutter/services.dart';

/// Root-navigator artwork route: touch/trackpad zoom, keyboard paging and a
/// separate fit-width reading mode for very long images.
class FanartImageViewer extends StatefulWidget {
  const FanartImageViewer({required this.images, this.initial = 0, super.key});
  final List<Uri> images;
  final int initial;
  @override
  State<FanartImageViewer> createState() => _FanartImageViewerState();
}

class _FanartImageViewerState extends State<FanartImageViewer> {
  late int _index = widget.images.isEmpty
      ? 0
      : widget.initial.clamp(0, widget.images.length - 1);
  late PageController _controller = PageController(
    initialPage: _index,
    keepPage: false,
  );
  late List<TransformationController> _transforms = List.generate(
    widget.images.length,
    (_) => TransformationController()..addListener(_onTransform),
  );
  bool _zoomed = false;
  bool _reading = false;
  Size _viewport = Size.zero;

  @override
  void didUpdateWidget(FanartImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (listEquals(widget.images, oldWidget.images) &&
        widget.initial == oldWidget.initial) {
      return;
    }
    _controller.dispose();
    for (final transform in _transforms) {
      transform.dispose();
    }
    _index = widget.images.isEmpty
        ? 0
        : widget.initial.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index, keepPage: false);
    _transforms = List.generate(
      widget.images.length,
      (_) => TransformationController()..addListener(_onTransform),
    );
    _zoomed = false;
    _reading = false;
  }

  void _onTransform() {
    if (!mounted || _transforms.isEmpty) return;
    final zoomed = _transforms[_index].value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _page(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.images.length || !_controller.hasClients) {
      return;
    }
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _zoom(double factor) {
    if (_transforms.isEmpty) return;
    if (_reading) setState(() => _reading = false);
    final transform = _transforms[_index];
    final scale = (transform.value.getMaxScaleOnAxis() * factor).clamp(
      1.0,
      6.0,
    );
    if (scale == 1) {
      _reset();
      return;
    }
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    final scene = transform.toScene(center);
    transform.value = Matrix4.identity()
      ..translateByDouble(
        center.dx - scene.dx * scale,
        center.dy - scene.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _reset() {
    if (_transforms.isNotEmpty) _transforms[_index].value = Matrix4.identity();
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final transform in _transforms) {
      transform.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _page(-1),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () => _page(1),
      const SingleActivator(LogicalKeyboardKey.pageUp): () => _page(-1),
      const SingleActivator(LogicalKeyboardKey.pageDown): () => _page(1),
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.maybePop(context),
      const SingleActivator(LogicalKeyboardKey.equal): () => _zoom(1.5),
      const SingleActivator(LogicalKeyboardKey.equal, shift: true): () =>
          _zoom(1.5),
      const SingleActivator(LogicalKeyboardKey.minus): () => _zoom(1 / 1.5),
      const SingleActivator(LogicalKeyboardKey.digit0): _reset,
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(
            widget.images.isEmpty
                ? '图片'
                : '${_index + 1} / ${widget.images.length}',
            maxLines: 1,
          ),
          actions: [
            AppGlassButton.icon(
              tooltip: '缩小',
              onPressed: _zoomed ? () => _zoom(1 / 1.5) : null,
              icon: const Icon(Icons.remove),
            ),
            AppGlassButton.icon(
              tooltip: '放大',
              onPressed: widget.images.isEmpty ? null : () => _zoom(1.5),
              icon: const Icon(Icons.add),
            ),
            AppGlassButton.icon(
              tooltip: '重置缩放',
              onPressed: _zoomed ? _reset : null,
              icon: const Icon(Icons.fit_screen),
            ),
            AppGlassButton.icon(
              tooltip: _reading ? '适应屏幕' : '长图阅读',
              onPressed: widget.images.isEmpty
                  ? null
                  : () {
                      _reset();
                      setState(() => _reading = !_reading);
                    },
              icon: Icon(
                _reading ? Icons.photo_size_select_large : Icons.swap_vert,
              ),
            ),
          ],
        ),
        body: widget.images.isEmpty
            ? const Center(
                child: Text('没有图片', style: TextStyle(color: Colors.white70)),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  _viewport = constraints.biggest;
                  return Stack(
                    children: [
                      PageView.builder(
                        controller: _controller,
                        itemCount: widget.images.length,
                        physics: _zoomed
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        onPageChanged: (index) {
                          setState(() => _index = index);
                          _onTransform();
                        },
                        itemBuilder: (context, index) => _reading
                            ? SingleChildScrollView(
                                key: PageStorageKey('artwork-reading-$index'),
                                child: _image(index, fitWidth: true),
                              )
                            : InteractiveViewer(
                                key: ValueKey('artwork-zoom-$index'),
                                transformationController: _transforms[index],
                                minScale: 1,
                                maxScale: 6,
                                trackpadScrollCausesScale: true,
                                child: Center(child: _image(index)),
                              ),
                      ),
                      if (constraints.maxWidth >= 640 &&
                          widget.images.length > 1) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppGlassButton.icon(
                            tooltip: '上一张',
                            onPressed: _index == 0 ? null : () => _page(-1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: AppGlassButton.icon(
                            tooltip: '下一张',
                            onPressed: _index == widget.images.length - 1
                                ? null
                                : () => _page(1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
      ),
    ),
  );

  Widget _image(int index, {bool fitWidth = false}) => Image.network(
    widget.images[index].toString(),
    width: fitWidth ? _viewport.width : null,
    fit: fitWidth ? BoxFit.fitWidth : BoxFit.contain,
    cacheWidth: (_viewport.width * MediaQuery.devicePixelRatioOf(context))
        .ceil()
        .clamp(640, 2560),
    errorBuilder: (_, _, _) => const Padding(
      padding: EdgeInsets.all(24),
      child: Text('图片加载失败', style: TextStyle(color: Colors.white70)),
    ),
    loadingBuilder: (_, child, progress) => progress == null
        ? child
        : const Center(
            child: SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            ),
          ),
  );
}
