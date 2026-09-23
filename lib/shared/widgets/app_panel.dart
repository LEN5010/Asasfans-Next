import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A root-overlay panel: bottom sheet on compact windows, centered on desktop.
/// Its builder receives bounded, keyboard-aware space for a scrolling body.
Future<T?> showAppPanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 720,
  double heightFactor = .82,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 840;
  Widget content(BuildContext context) {
    final mq = MediaQuery.of(context);
    final available = math.max(
      0.0,
      mq.size.height - mq.viewInsets.bottom - mq.padding.vertical - 96,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: wide ? 0 : mq.viewInsets.bottom),
      child: SizedBox(
        width: maxWidth,
        height: math.min(mq.size.height * heightFactor, available),
        child: builder(context),
      ),
    );
  }

  if (wide) {
    return showDialog<T>(
      context: context,
      useRootNavigator: true,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: content(context),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: BoxConstraints(maxWidth: maxWidth),
    builder: content,
  );
}
