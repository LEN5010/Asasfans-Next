import 'package:flutter/material.dart';

import 'app_controls.dart';

/// A root page's own title, part of its content: it scrolls away with the
/// page instead of floating above it. Child pages keep [AppPageBar].
class RootHeading extends StatelessWidget {
  const RootHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });
  final String title;

  /// One line under the title; a widget, so a page can say what it holds
  /// ("今天 2 场安排") with emphasis of its own.
  final Object? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Space-separated parts ("9月26日 星期六") wrap between each
              // other at large sizes, never inside one. The title is already
              // display size, so it grows less than body text does (as large
              // titles do on the platforms); everything else scales fully.
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.4,
                child: Semantics(
                  header: true,
                  label: title,
                  excludeSemantics: true,
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      for (final (index, part) in title.split(' ').indexed)
                        Text(
                          part,
                          // The first part is the title; the rest qualify it.
                          style: index == 0
                              ? theme.textTheme.headlineSmall
                              : theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                        ),
                    ],
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                DefaultTextStyle.merge(
                  style: subtitleStyle,
                  child: subtitle is Widget
                      ? subtitle
                      : Text('$subtitle', style: subtitleStyle),
                ),
              ],
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// A section title with an optional way to see all of it.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.caption,
    this.action,
    this.onAction,
    this.trailing = const [],
  });
  final String title;

  /// A quiet fact after the title: how many, or since when.
  final String? caption;

  /// Short label for the link to the full list, e.g. "日历".
  final String? action;
  final VoidCallback? onAction;

  /// Extra controls before the link (a sort menu, paging arrows).
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = theme.textTheme.labelLarge?.copyWith(
      fontSize: 13.5,
      color: theme.colorScheme.primary,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text.rich(
                TextSpan(
                  text: title,
                  children: [
                    if (caption != null)
                      TextSpan(
                        text: '  $caption',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          ...trailing,
          // At very large text the link keeps its target but not its words,
          // so the section title is not squeezed into a column.
          if (action != null &&
              onAction != null &&
              MediaQuery.textScalerOf(context).scale(1) >= 1.6)
            AppButton.icon(
              tooltip: action,
              onPressed: onAction,
              icon: Icon(Icons.chevron_right, color: theme.colorScheme.primary),
            )
          else if (action != null && onAction != null)
            AppButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action!, style: link),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
