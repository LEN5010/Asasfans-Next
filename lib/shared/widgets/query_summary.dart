import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'app_controls.dart';
import 'app_motion.dart';

/// One applied condition and how to take it away.
typedef AppliedCondition = ({String label, VoidCallback remove});

/// What a channel's query applies beyond its defaults, in words. Each
/// condition can be removed on its own; 清空 removes them all. An optional
/// [status] (a result count) leads the line. Nothing is drawn while there is
/// neither a status nor an applied condition, so defaults take no space.
///
/// Every channel uses this one line, built from the conditions its own
/// repository really accepts; the channels share the presentation, not a
/// pretend common query.
class QuerySummary extends StatelessWidget {
  const QuerySummary({
    super.key,
    required this.applied,
    required this.onClear,
    this.status,
    this.clearTooltip = '重置筛选',
    this.padding = const EdgeInsets.fromLTRB(16, 2, 8, 0),
  });
  final List<AppliedCondition> applied;
  final VoidCallback onClear;
  final String? status;
  final String clearTooltip;
  final EdgeInsets padding;

  /// The line grows and folds with the conditions rather than jumping the
  /// feed below it; reduced motion makes it immediate.
  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: appMotion(context, AppTokens.controlMotion),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: applied.isEmpty && status == null
        ? const SizedBox(width: double.infinity)
        : _line(context),
  );

  Widget _line(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (status != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(status!, style: theme.textTheme.bodySmall),
                  ),
                for (final condition in applied)
                  AppButton(
                    tooltip: '移除“${condition.label}”',
                    onPressed: condition.remove,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(condition.label),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.close,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (applied.isNotEmpty)
            AppButton(
              tooltip: clearTooltip,
              onPressed: onClear,
              child: Text(
                '清空',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}
