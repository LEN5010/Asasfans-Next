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

/// How many further pages a cold return may fetch to reach its anchor.
const restorePageBudget = 3;

/// Completes once [loading] turns false, or after a bound: a restore never
/// waits on the network indefinitely.
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
