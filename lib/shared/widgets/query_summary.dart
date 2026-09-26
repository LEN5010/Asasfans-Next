import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'app_controls.dart';
import 'app_motion.dart';

/// One applied condition and how to take it away.
typedef AppliedCondition = ({String label, VoidCallback remove});

/// What a channel's query applies beyond its defaults, in words. Each
/// condition can be removed on its own; the clear button removes what the
/// line shows, and [clearLabel]/[clearTooltip] say so when that is not the
/// whole query. An optional [status] (a result count) leads the line.
/// Nothing is drawn while there is neither a status nor an applied
/// condition, so defaults take no space.
///
/// Every channel uses this one line, built from the conditions its own
/// repository really accepts; the channels share the presentation, not a
/// pretend common query.
class QuerySummary extends StatefulWidget {
  const QuerySummary({
    super.key,
    required this.applied,
    required this.onClear,
    this.status,
    this.clearLabel = '清空',
    this.clearTooltip = '重置筛选',
    this.padding = const EdgeInsets.fromLTRB(16, 2, 8, 0),
  });
  final List<AppliedCondition> applied;
  final VoidCallback onClear;
  final String? status;
  final String clearLabel;
  final String clearTooltip;
  final EdgeInsets padding;

  /// Beyond this many conditions the line shows the first two and a count.
  static const foldAfter = 3;

  @override
  State<QuerySummary> createState() => _QuerySummaryState();
}

class _QuerySummaryState extends State<QuerySummary> {
  bool _expanded = false;

  /// Labels shown on the previous build, so a condition that just arrived
  /// (applied from the panel) can be marked as new for a moment: the panel
  /// closes, and the eye finds what it changed in the line it left.
  Set<String> _previous = const {};
  Set<String> _fresh = const {};

  @override
  void initState() {
    super.initState();
    _previous = {for (final condition in widget.applied) condition.label};
  }

  @override
  void didUpdateWidget(QuerySummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    final now = {for (final condition in widget.applied) condition.label};
    _fresh = now.difference(_previous);
    _previous = now;
  }

  /// The line grows and folds with the conditions rather than jumping the
  /// feed below it; reduced motion makes it immediate.
  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: appMotion(context, AppTokens.controlMotion),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: widget.applied.isEmpty && widget.status == null
        ? const SizedBox(width: double.infinity)
        : _line(context),
  );

  Widget _line(BuildContext context) {
    final theme = Theme.of(context);
    final applied = widget.applied;
    final folds = applied.length > QuerySummary.foldAfter;
    final shown = folds && !_expanded ? applied.take(2) : applied;
    final quiet = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: widget.padding,
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.status != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      widget.status!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                for (final condition in shown)
                  _Arrival(
                    key: ValueKey(condition.label),
                    fresh: _fresh.contains(condition.label),
                    child: AppButton(
                      tooltip: '移除“${condition.label}”',
                      onPressed: condition.remove,
                      // A keyword can be any length: the chip never outgrows
                      // the line, and the whole value stays in its tooltip.
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              condition.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.close,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (folds)
                  AppButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? '收起' : '另 ${applied.length - 2} 项',
                      style: quiet,
                    ),
                  ),
              ],
            ),
          ),
          if (applied.isNotEmpty)
            AppButton(
              tooltip: widget.clearTooltip,
              onPressed: widget.onClear,
              child: Text(
                widget.clearLabel,
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}

/// A condition that just arrived starts tinted and settles to the plain
/// line; one that was already there is drawn plain. The tint runs once from
/// the moment the chip arrives, whatever rebuilds the feed makes meanwhile,
/// and the chip's widget structure never changes (a focused chip keeps its
/// focus). Reduced motion shows it plain at once, since the words say the
/// same.
class _Arrival extends StatefulWidget {
  const _Arrival({required this.fresh, required this.child, super.key});
  final bool fresh;
  final Widget child;

  static const duration = Duration(milliseconds: 900);

  @override
  State<_Arrival> createState() => _ArrivalState();
}

class _ArrivalState extends State<_Arrival>
    with SingleTickerProviderStateMixin {
  late final _tint = AnimationController(
    vsync: this,
    duration: _Arrival.duration,
    value: 0,
  );
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _pending = widget.fresh;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pending) {
      _pending = false;
      if (!MediaQuery.disableAnimationsOf(context)) _tint.reverse(from: 1);
    }
  }

  @override
  void didUpdateWidget(_Arrival oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a new arrival starts it again; a rebuild that no longer calls
    // the chip fresh lets a running tint finish.
    if (widget.fresh &&
        !oldWidget.fresh &&
        !MediaQuery.disableAnimationsOf(context)) {
      _tint.reverse(from: 1);
    }
  }

  @override
  void dispose() {
    _tint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = Theme.of(context).colorScheme.primaryContainer;
    return AnimatedBuilder(
      animation: _tint,
      child: widget.child,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: tint.withValues(
            alpha: Curves.easeOut.transform(_tint.value) * .9,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }
}
