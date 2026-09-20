import 'package:flutter/material.dart';

/// Full-screen artwork viewer with pinch/scroll zoom and paging.
///
/// Uses `InteractiveViewer` rather than an extra dependency; long vertical
/// artwork stays readable because the image is contained, not cropped.
class FanartImageViewer extends StatefulWidget {
  const FanartImageViewer({required this.images, this.initial = 0, super.key});

  final List<Uri> images;
  final int initial;

  @override
  State<FanartImageViewer> createState() => _FanartImageViewerState();
}

class _FanartImageViewerState extends State<FanartImageViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initial,
  );
  late int _index = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: widget.images.length > 1
            ? Text('${_index + 1} / ${widget.images.length}')
            : null,
      ),
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.network(
              widget.images[index].toString(),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) =>
                  const Text('图片加载失败', style: TextStyle(color: Colors.white70)),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
