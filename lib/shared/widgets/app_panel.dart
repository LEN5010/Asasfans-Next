import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'glass/app_glass_surface.dart';

/// A root-overlay panel: bottom sheet on compact windows, centered on desktop.
/// Its builder receives bounded, keyboard-aware space for a scrolling body.
Future<T?> showAppPanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 680,
  double heightFactor = .80,
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

/// Fixed control header; the panel body owns scrolling and stays opaque.
class AppPanelHeader extends StatelessWidget {
  const AppPanelHeader({
    super.key,
    required this.title,
    this.closeLabel = '关闭',
    this.actions = const [],
    this.onClose,
    this.canClose = true,
  });
  final String title;
  final String closeLabel;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final bool canClose;

  @override
  Widget build(BuildContext context) => AppGlassSurface(
    radius: 22,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...actions,
          IconButton(
            tooltip: closeLabel,
            onPressed: canClose
                ? (onClose ?? () => Navigator.pop(context))
                : null,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );
}
