import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_motion.dart';

import '../../../shared/widgets/media_image_policy.dart';

/// Root-navigator artwork route: touch/trackpad zoom, keyboard paging and a
/// separate fit-width reading mode for very long images.
///
/// The picture has the whole screen. The controls float over it and a tap
/// hides or brings them back; a double tap zooms in where it lands, and a
/// strip of thumbnails moves through a set.
class FanartImageViewer extends StatefulWidget {
  const FanartImageViewer({
    required this.images,
    this.initial = 0,
    this.onOpenOriginal,
    super.key,
  });
  final List<Uri> images;
  final int initial;

  /// Opens a picture's own address outside the app, where it can be saved.
  final ValueChanged<Uri>? onOpenOriginal;
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
  bool _chrome = true;
  Size _viewport = Size.zero;
  Offset? _doubleTapAt;
  late List<GlobalKey> _thumbs = [for (final _ in widget.images) GlobalKey()];

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
    _thumbs = [for (final _ in widget.images) GlobalKey()];
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

  void _zoom(double factor, {Offset? focal}) {
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
    final center = focal ?? Offset(_viewport.width / 2, _viewport.height / 2);
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

  /// In to 2.5x where the finger landed, or back out when already in.
  void _doubleTap() {
    if (_zoomed) {
      _reset();
    } else {
      _zoom(2.5, focal: _doubleTapAt);
    }
  }

  void _onPage(int index) {
    setState(() => _index = index);
    _onTransform();
    final thumb = _thumbs[index].currentContext;
    if (thumb != null) {
      Scrollable.ensureVisible(
        thumb,
        alignment: .5,
        duration: appMotion(context, AppTokens.controlMotion),
        curve: AppCurves.standard,
      );
    }
  }

  void _show(int index) {
    if (!_controller.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(index);
    } else {
      _controller.animateToPage(
        index,
        duration: AppTokens.controlMotion,
        curve: AppCurves.standard,
      );
    }
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
    // Always the dark scheme: light-page colours vanish on black.
    child: Theme(
      data: AppTheme.dark,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: widget.images.isEmpty
              ? Stack(
                  children: [
                    const Center(
                      child: Text(
                        '没有图片',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    _topBar(context, wide: false),
                  ],
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    _viewport = constraints.biggest;
                    final wide = constraints.maxWidth >= 640;
                    return Stack(
                      children: [
                        PageView.builder(
                          controller: _controller,
                          itemCount: widget.images.length,
                          physics: _zoomed
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          onPageChanged: _onPage,
                          itemBuilder: (context, index) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _chrome = !_chrome),
                            onDoubleTapDown: _reading
                                ? null
                                : (details) =>
                                      _doubleTapAt = details.localPosition,
                            onDoubleTap: _reading ? null : _doubleTap,
                            child: _reading
                                ? SingleChildScrollView(
                                    key: PageStorageKey(
                                      'artwork-reading-$index',
                                    ),
                                    child: _image(index, fitWidth: true),
                                  )
                                : InteractiveViewer(
                                    key: ValueKey('artwork-zoom-$index'),
                                    transformationController:
                                        _transforms[index],
                                    minScale: 1,
                                    maxScale: 6,
                                    trackpadScrollCausesScale: true,
                                    child: Center(child: _image(index)),
                                  ),
                          ),
                        ),
                        _topBar(context, wide: wide),
                        if (widget.images.length > 1)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _overlay(_thumbStrip(context)),
                          ),
                        if (wide && widget.images.length > 1) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _overlay(
                              _RoundButton(
                                tooltip: '上一张',
                                icon: Icons.chevron_left,
                                onPressed: _index == 0 ? null : () => _page(-1),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _overlay(
                              _RoundButton(
                                tooltip: '下一张',
                                icon: Icons.chevron_right,
                                onPressed: _index == widget.images.length - 1
                                    ? null
                                    : () => _page(1),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
        ),
      ),
    ),
  );

  /// Fades the controls with the chrome; hidden ones take no taps.
  Widget _overlay(Widget child) => IgnorePointer(
    ignoring: !_chrome,
    child: AnimatedOpacity(
      opacity: _chrome ? 1 : 0,
      duration: appMotion(context, AppTokens.controlMotion),
      curve: AppCurves.standard,
      child: child,
    ),
  );

  Widget _topBar(BuildContext context, {required bool wide}) {
    final top = MediaQuery.paddingOf(context).top;
    final count = widget.images.length;
    final original = widget.onOpenOriginal;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: _overlay(
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Color(0x00000000)],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, top + 8, 8, 24),
            child: Row(
              children: [
                _RoundButton(
                  tooltip: '关闭',
                  icon: Icons.close,
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: const ShapeDecoration(
                    color: Color(0x66000000),
                    shape: StadiumBorder(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      count == 0 ? '图片' : '${_index + 1} / $count',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (count > 0) ...[
                  if (wide) ...[
                    _RoundButton(
                      tooltip: '缩小',
                      icon: Icons.remove,
                      onPressed: _zoomed ? () => _zoom(1 / 1.5) : null,
                    ),
                    _RoundButton(
                      tooltip: '放大',
                      icon: Icons.add,
                      onPressed: () => _zoom(1.5),
                    ),
                  ],
                  if (_zoomed)
                    _RoundButton(
                      tooltip: '重置缩放',
                      icon: Icons.fit_screen,
                      onPressed: _reset,
                    ),
                  _RoundButton(
                    tooltip: _reading ? '适应屏幕' : '长图阅读',
                    icon: _reading
                        ? Icons.photo_size_select_large
                        : Icons.swap_vert,
                    onPressed: () {
                      _reset();
                      setState(() => _reading = !_reading);
                    },
                  ),
                  if (original != null)
                    _RoundButton(
                      tooltip: '在浏览器打开原图',
                      icon: Icons.open_in_browser,
                      onPressed: () => original(widget.images[_index]),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The set as small squares, the current one outlined.
  Widget _thumbStrip(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    const side = 52.0;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0x99000000), Color(0x00000000)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: 24, bottom: bottom + 12),
        child: SizedBox(
          height: side + 4,
          child: Center(
            child: ListView.separated(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = index == _index;
                return Semantics(
                  key: _thumbs[index],
                  button: true,
                  selected: selected,
                  label: '第 ${index + 1} 张',
                  child: GestureDetector(
                    onTap: () => _show(index),
                    child: AnimatedOpacity(
                      opacity: selected ? 1 : .55,
                      duration: appMotion(context, AppTokens.pressMotion),
                      child: Container(
                        width: side + 4,
                        height: side + 4,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image(
                            image: MediaImagePolicy.preview(
                              widget.images[index],
                              logicalWidth: side,
                              logicalHeight: side,
                              devicePixelRatio: MediaQuery.devicePixelRatioOf(
                                context,
                              ),
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(color: Colors.white12),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // The original, decoded to the viewport width and a total-pixel budget, so
  // a very long image cannot allocate an unbounded texture.
  Widget _image(int index, {bool fitWidth = false}) => Image(
    image: MediaImagePolicy.original(
      widget.images[index],
      viewportWidth: _viewport.width,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    ),
    width: fitWidth ? _viewport.width : null,
    fit: fitWidth ? BoxFit.fitWidth : BoxFit.contain,
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

/// A control on the picture: a light glyph on a dark disc that reads over
/// any artwork.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(2),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0x52000000),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0x29000000),
        disabledForegroundColor: Colors.white38,
      ),
      icon: Icon(icon, size: 22),
    ),
  );
}
