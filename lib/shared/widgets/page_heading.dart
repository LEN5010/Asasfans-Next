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
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    children: [
                      for (final part in title.split(' '))
                        Text(part, style: theme.textTheme.headlineSmall),
                    ],
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
    this.action,
    this.onAction,
    this.trailing = const [],
  });
  final String title;

  /// Short label for the link to the full list, e.g. "日历".
  final String? action;
  final VoidCallback? onAction;

  /// Extra controls before the link (a sort menu, paging arrows).
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleLarge),
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
                  Text(
                    action!,
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
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
