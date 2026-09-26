import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';

/// Content channels as text tabs: the selected one is bold with a short
/// accent underline. They read as "which kind of content", distinct from the
/// filled controls that change a query below them, and they double as the
/// page's title.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppTokens.controlMotion;
    // Large text may need more than the width; the tabs then scroll rather
    // than shrink or clip.
    return SizedBox(
      height: heightFor(MediaQuery.textScalerOf(context)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in values)
              Semantics(
                selected: value == selected,
                button: true,
                inMutuallyExclusiveGroup: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  // The selected tab stays a focus stop; activating it again
                  // changes nothing.
                  onTap: () {
                    if (value != selected) onChanged(value);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: duration,
                          style: theme.textTheme.titleMedium!.copyWith(
                            fontSize: 18,
                            height: 1.3,
                            fontWeight: value == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: value == selected
                                ? colors.onSurface
                                : colors.onSurfaceVariant,
                          ),
                          child: Text(labelOf(value)),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: duration,
                          width: value == selected ? 18 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: colors.secondary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
