import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/domain/content_identity.dart';
import '../domain/return_context.dart';

enum AnchorRestore {
  /// The anchored item is on screen.
  exact,

  /// The item is not in the list; the stored offset was used instead.
  offsetOnly,

  /// Nothing to restore, or the list went away.
  none,
}

/// Brings a return anchor into view, identity first.
///
/// Having the item in the loaded data does not put it on screen: lazy lists
/// only build what is near the viewport. This walks toward the item until its
/// card is built, then scrolls it into view. The stored offset is only a
/// starting guess, since it belonged to another layout.
///
/// [order] is the list as displayed. Items are found by their
/// `ValueKey<ContentIdentity>`, which every feed card already carries.
Future<AnchorRestore> restoreAnchor({
  required BuildContext scope,
  required ScrollController controller,
  required ReturnAnchor anchor,
  required List<ContentIdentity> order,
  int maxSteps = 40,
}) async {
  if (!controller.hasClients) return AnchorRestore.none;
  final identity = anchor.identity;
  final target = identity == null ? -1 : order.indexOf(identity);
  final offset = anchor.offset;
  if (target < 0) {
    if (offset == null) return AnchorRestore.none;
    final position = controller.position;
    controller.jumpTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    return AnchorRestore.offsetOnly;
  }
  if (offset != null) {
    final position = controller.position;
    controller.jumpTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    await WidgetsBinding.instance.endOfFrame;
  }
  final indexOf = {for (final (i, id) in order.indexed) id: i};
  for (var step = 0; step < maxSteps; step++) {
    if (!scope.mounted || !controller.hasClients) return AnchorRestore.none;
    final found = _find(scope, identity!, indexOf);
    if (found.element case final element?) {
      // Below the floating bars rather than flush with the top edge.
      await Scrollable.ensureVisible(element, alignment: .25);
      return AnchorRestore.exact;
    }
    final position = controller.position;
    final forward = found.built.isEmpty
        // Nothing built at all: aim by the item's share of the extent.
        ? target / order.length * position.maxScrollExtent > position.pixels
        : found.built.reduce((a, b) => a > b ? a : b) < target;
    final next =
        (position.pixels + (forward ? 1 : -1) * position.viewportDimension * .8)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (next == position.pixels) break;
    controller.jumpTo(next);
    await WidgetsBinding.instance.endOfFrame;
  }
  return AnchorRestore.none;
}

({Element? element, List<int> built}) _find(
  BuildContext scope,
  ContentIdentity identity,
  Map<ContentIdentity, int> indexOf,
) {
  Element? match;
  final built = <int>[];
  void visit(Element element) {
    if (match != null) return;
    final key = element.widget.key;
    if (key is ValueKey<ContentIdentity>) {
      if (key.value == identity) {
        match = element;
        return;
      }
      if (indexOf[key.value] case final index?) built.add(index);
    }
    element.visitChildren(visit);
  }

  scope.visitChildElements(visit);
  return (element: match, built: built);
}

/// The item the reader is on in [controller]'s viewport, and how far its
/// top sits below the viewport's top: what a width change should keep in
/// place. That is the item across a reading line 40% down the part below
/// [clearTop] (the leftmost, when columns share the line), or else the one
/// nearest to it. The top edge is a poor choice: a work mostly scrolled
/// away up there keeps its place while the one being read moves off.
/// Read from the current layout, so call it before the new width is laid
/// out, and outside a build.
({ContentIdentity identity, double top})? visibleAnchor(
  BuildContext scope,
  ScrollController controller, {
  double clearTop = 0,
}) {
  if (!controller.hasClients || controller.offset <= 0) return null;
  final viewport = _viewportRect(controller);
  if (viewport == null) return null;
  final floor = viewport.top + clearTop;
  final line = floor + (viewport.bottom - floor) * .4;
  ({ContentIdentity identity, double top})? best;
  var bestScore = (double.infinity, double.infinity);
  void visit(Element element) {
    final key = element.widget.key;
    if (key is ValueKey<ContentIdentity>) {
      final box = element.renderObject;
      if (box is RenderBox && box.attached && box.hasSize) {
        final origin = box.localToGlobal(Offset.zero);
        final bottom = origin.dy + box.size.height;
        if (bottom > floor && origin.dy < viewport.bottom) {
          final distance = origin.dy > line
              ? origin.dy - line
              : bottom < line
              ? line - bottom
              : 0.0;
          final score = (distance, origin.dx);
          if (score.$1 < bestScore.$1 ||
              (score.$1 == bestScore.$1 && score.$2 < bestScore.$2)) {
            bestScore = score;
            best = (identity: key.value, top: origin.dy - viewport.top);
          }
        }
      }
      return;
    }
    element.visitChildren(visit);
  }

  scope.visitChildElements(visit);
  return best;
}

/// Puts [anchor]'s item back at the same distance from the viewport's top
/// after a relayout, walking to it first if it is no longer built.
Future<void> keepVisibleAnchor({
  required BuildContext scope,
  required ScrollController controller,
  required ({ContentIdentity identity, double top}) anchor,
  required List<ContentIdentity> order,
}) async {
  await WidgetsBinding.instance.endOfFrame;
  for (var walked = false; ; walked = true) {
    if (!scope.mounted || !controller.hasClients) return;
    final viewport = _viewportRect(controller);
    final found = _find(scope, anchor.identity, const {}).element;
    final box = found?.renderObject;
    if (viewport != null && box is RenderBox && box.attached) {
      final top = box.localToGlobal(Offset.zero).dy - viewport.top;
      final position = controller.position;
      controller.jumpTo(
        (position.pixels + top - anchor.top).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      return;
    }
    if (walked) return;
    final restored = await restoreAnchor(
      scope: scope,
      controller: controller,
      anchor: ReturnAnchor(identity: anchor.identity),
      order: order,
    );
    if (restored != AnchorRestore.exact) return;
    await WidgetsBinding.instance.endOfFrame;
  }
}

Rect? _viewportRect(ScrollController controller) {
  final box = controller.position.context.notificationContext
      ?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// How many further pages a cold return may fetch to reach its anchor.
const restorePageBudget = 3;

/// Completes once [loading] turns false, or after a bound: a restore never
/// waits on the network indefinitely. Used for the first page and for an
/// append already in flight.
Future<void> waitForFirstPage(Listenable feed, bool Function() loading) async {
  if (!loading()) return;
  final done = Completer<void>();
  void listener() {
    if (!loading() && !done.isCompleted) done.complete();
  }

  feed.addListener(listener);
  try {
    await done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
  } finally {
    feed.removeListener(listener);
  }
}

/// A return that could not find its item says so instead of silently
/// landing somewhere else.
void showAnchorFallbackNotice(BuildContext context) =>
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('原位置已不在列表中，已回到相近位置')));
