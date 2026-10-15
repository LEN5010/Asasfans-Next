import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_motion.dart';

/// Content channels as text tabs: the selected one is bold, and one short
/// accent underline slides to it. They read as "which kind of content",
/// distinct from the filled controls that change a query below them, and
/// they double as the page's title.
class ChannelTabs<T> extends StatelessWidget {
  const ChannelTabs({
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

  /// 48 at 1x; the label line grows with the text scale.
  static double heightFor(TextScaler scaler) =>
      (scaler.scale(18) * 1.3).ceilToDouble() + 25;

  static const _padding = 10.0;
  static const _indicator = 18.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final duration = appMotion(context, AppTokens.emphasisMotion);
    final bold = theme.textTheme.titleMedium!.copyWith(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w700,
    );
    // Every tab is as wide as its bold label, so selecting one never
    // shifts its neighbours, and the underline knows where to go.
    final widths = [
      for (final value in values)
        () {
          final painter = TextPainter(
            text: TextSpan(text: labelOf(value), style: bold),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width.ceilToDouble() + _padding * 2;
          painter.dispose();
          return width;
        }(),
    ];
    final index = values.indexOf(selected);
    var start = 0.0;
    for (var i = 0; i < index; i++) {
      start += widths[i];
    }
    final center = start + (index < 0 ? 0 : widths[index] / 2);
    final height = heightFor(scaler);
    // Large text may need more than the width; the tabs then scroll rather
    // than shrink or clip.
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: widths.fold<double>(0, (sum, width) => sum + width),
          child: Stack(
            children: [
              Row(
                children: [
                  for (final (i, value) in values.indexed)
                    Semantics(
                      selected: value == selected,
                      button: true,
                      inMutuallyExclusiveGroup: true,
                      // The selected channel is the page's title.
                      header: value == selected,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        // The selected tab stays a focus stop; activating it
                        // again changes nothing.
                        onTap: () {
                          if (value != selected) onChanged(value);
                        },
                        child: SizedBox(
                          width: widths[i],
                          height: height,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: appMotion(
                                  context,
                                  AppTokens.controlMotion,
                                ),
                                curve: AppCurves.standard,
                                style: bold.copyWith(
                                  fontWeight: value == selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: value == selected
                                      ? colors.onSurface
                                      : colors.onSurfaceVariant,
                                ),
                                child: Text(labelOf(value), maxLines: 1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (index >= 0)
                AnimatedPositioned(
                  duration: duration,
                  curve: AppCurves.enter,
                  left: center - _indicator / 2,
                  bottom: 6,
                  width: _indicator,
                  height: 3,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.secondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
