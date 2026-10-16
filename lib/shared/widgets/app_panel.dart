import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import 'app_controls.dart';

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

/// Every feed's filter panel, the same in a bottom sheet and inline on a wide
/// window: the title with 重置 and close, titled [sections] in one column,
/// then 取消 and 应用筛选. Inline ([embedded]) it is as tall as its content.
class AppFilterPanel extends StatelessWidget {
  const AppFilterPanel({
    super.key,
    required this.title,
    required this.sections,
    required this.onReset,
    required this.onApply,
    required this.onClose,
    this.embedded = false,
  });
  final String title;
  final List<Widget> sections;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final VoidCallback onClose;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final fields = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: sections,
      ),
    );
    return Column(
      mainAxisSize: embedded ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPanelHeader(
          title: title,
          closeLabel: '关闭筛选',
          onClose: onClose,
          actions: [AppButton(onPressed: onReset, child: const Text('重置'))],
        ),
        if (embedded)
          fields
        else
          Expanded(child: SingleChildScrollView(child: fields)),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                AppButton(onPressed: onClose, child: const Text('取消')),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    selected: true,
                    onPressed: onApply,
                    child: const Text('应用筛选'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One titled group of an [AppFilterPanel].
class AppFilterSection extends StatelessWidget {
  const AppFilterSection({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      child,
    ],
  );
}

/// Single-choice buttons that wrap, for a group with too many options to
/// sit side by side in [AppSegments].
class AppChoiceWrap<T> extends StatelessWidget {
  const AppChoiceWrap({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });
  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final value in values)
        AppChoice(
          selected: value == selected,
          onSelected: (_) => onChanged(value),
          label: Text(labelOf(value)),
        ),
    ],
  );
}

/// Fixed title row; the panel body below it owns scrolling. The panel is a
/// solid surface, so the header is plain rather than a glass layer on nothing.
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
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Padding(
      // Clear of the panel's large corners: the title and the close button
      // sit inside the curve, not under it.
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
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
          AppButton.icon(
            tooltip: closeLabel,
            onPressed: canClose
                ? (onClose ?? () => Navigator.pop(context))
                : null,
            icon: const Icon(AppIcons.close),
          ),
        ],
      ),
    ),
  );
}
