import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/widgets.dart';

/// Keeps a feed's scroll offset across an unmount that its data survives.
///
/// Content channels unmount when they fall out of recent use, while their
/// controllers keep the loaded pages. The offset is written when the feed is
/// deactivated, while its scrollable is still attached, and read back as the
/// new controller's initial offset. Scrollable's own PageStorage save is not
/// used: it records the offset when a scroll ends, which a lazy masonry can
/// still correct afterwards, and it would then win over the real one.
mixin FeedOffsetMemory<T extends StatefulWidget> on State<T> {
  /// Unique per feed (and per variant of a feed) within the page.
  String get offsetStorageId;

  PageStorageBucket? _bucket;
  ScrollController? _controller;
  bool _settling = false;

  /// Stops re-applying the remembered offset, for a caller that is about to
  /// set the position itself (a return restore).
  void cancelOffsetSettle() => _settling = false;

  /// The controller to hand the feed's scroll view. Create it once, on first
  /// use in build, so the stored offset is already readable.
  ScrollController feedScrollController() {
    if (_controller case final controller?) return controller;
    final saved =
        _bucket?.readState(context, identifier: offsetStorageId) as double?;
    if (saved != null && saved > 0) {
      _settling = true;
      _settle(saved, 3);
    }
    return _controller = ScrollController(
      initialScrollOffset: saved ?? 0,
      keepScrollOffset: false,
    );
  }

  /// A lazy masonry first estimates its extent from the few children it has
  /// laid out, so the initial offset can be clamped short. Re-apply it once
  /// layout knows more, for a bounded number of frames.
  void _settle(double offset, int frames) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _controller;
      if (!_settling ||
          !mounted ||
          controller == null ||
          !controller.hasClients) {
        return;
      }
      final position = controller.position;
      // The user took over, or the offset is reached: stop.
      if (position.userScrollDirection != ScrollDirection.idle ||
          (position.pixels - offset).abs() < .5) {
        _settling = false;
        return;
      }
      controller.jumpTo(offset.clamp(0, position.maxScrollExtent));
      if (frames > 1) {
        _settle(offset, frames - 1);
      } else {
        _settling = false;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bucket = PageStorage.maybeOf(context);
  }

  @override
  void deactivate() {
    final controller = _controller;
    if (controller != null && controller.hasClients) {
      _bucket?.writeState(
        context,
        controller.offset,
        identifier: offsetStorageId,
      );
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
