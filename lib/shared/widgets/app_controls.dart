import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/theme/app_tokens.dart';
import 'glass/app_glass_scope.dart';
import 'glass/app_glass_style.dart';

/// Ordinary page actions. Material and geometry are independent: repeated
/// controls never allocate glass layers, even when navigation uses glass.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.selected = false,
    this.radius = 10,
    this.tooltip,
    this.leading,
    this.filled = false,
  }) : iconOnly = false;

  const AppButton.icon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required this.tooltip,
    this.selected = false,
    this.radius = 10,
    this.filled = false,
  }) : child = icon,
       leading = null,
       iconOnly = true;

  const AppButton.withIcon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.selected = false,
    this.radius = 10,
    this.tooltip,
    this.filled = false,
  }) : child = label,
       leading = icon,
       iconOnly = false;

  final Widget? leading;
  final VoidCallback? onPressed;
  final Widget child;
  final bool selected;
  final double radius;
  final String? tooltip;
  final bool iconOnly;

  /// Sits beside a search field: the field's fill, height and corners.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final target = filled
        ? AppSegments.heightFor(context)
        : AppTokens.controlTarget(context);
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(target, target),
        padding: EdgeInsets.symmetric(
          horizontal: iconOnly ? 8 : 12,
          vertical: 6,
        ),
        foregroundColor: selected
            ? colors.onPrimaryContainer
            : colors.onSurface,
        backgroundColor: selected
            ? colors.primaryContainer
            : filled
            ? Theme.of(context).inputDecorationTheme.fillColor
            : Colors.transparent,
        disabledForegroundColor: colors.onSurface.withValues(alpha: .38),
        textStyle: const TextStyle(
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            filled ? AppTokens.inputRadius : radius,
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        animationDuration: AppGlassScope.of(context).canAnimate
            ? AppTokens.pressMotion
            : Duration.zero,
      ),
      child: IconTheme.merge(
        data: const IconThemeData(size: 20),
        child: leading == null
            ? child
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  leading!,
                  const SizedBox(width: 8),
                  Flexible(child: child),
                ],
              ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Selection choices share the ordinary action geometry, with explicit state.
class AppChoice extends StatelessWidget {
  const AppChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.avatar,
  });
  final Widget label;
  final Widget? avatar;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: AppButton(
      selected: selected,
      leading: avatar ?? (selected ? const Icon(Icons.check, size: 16) : null),
      onPressed: onSelected == null ? null : () => onSelected!(!selected),
      child: label,
    ),
  );
}

class AppSegments<T> extends StatelessWidget {
  const AppSegments({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.navigation = false,
  });
  final bool navigation;
  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T>? onChanged;

  static double heightFor(BuildContext context) => math.max(
    math.max(AppTokens.controlHeight, AppTokens.controlTarget(context)),
    MediaQuery.textScalerOf(context).scale(14) * 1.3 + 16,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const style = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
      var labelWidth = 0.0;
      for (final value in values) {
        final painter = TextPainter(
          text: TextSpan(text: labelOf(value), style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        labelWidth = math.max(labelWidth, painter.width);
        painter.dispose();
      }
      if (constraints.maxWidth < (labelWidth + 16) * values.length + 8) {
        return AppButton(
          onPressed: onChanged == null
              ? null
              : () async {
                  final choice = await showDialog<T>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      children: [
                        for (final value in values)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: AppButton(
                              selected: value == selected,
                              onPressed: () => Navigator.pop(context, value),
                              child: Text(labelOf(value)),
                            ),
                          ),
                      ],
                    ),
                  );
                  if (choice != null && context.mounted) {
                    onChanged?.call(choice);
                  }
                },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(labelOf(selected)),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more),
            ],
          ),
        );
      }
      return _segments(context);
    },
  );

  Widget _segments(BuildContext context) {
    final policy = AppGlassScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final height = navigation
        ? heightFor(context)
        : math.max(
            AppTokens.controlTarget(context),
            MediaQuery.textScalerOf(context).scale(14) * 1.3 + 16,
          );
    final selectedIndex = values.indexOf(selected);
    final selectedStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: colors.onPrimaryContainer,
    );
    final normalStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: colors.onSurface,
    );
    final duration = policy.canAnimate
        ? AppTokens.controlMotion
        : Duration.zero;
    // The package's segmented spring does not consult reduceMotion; use the
    // same geometry without that spring when accessibility disables motion.
    final control = navigation && policy.usesLiquid && policy.canAnimate
        ? GlassSegmentedControl(
            segments: [
              for (final value in values)
                GlassSegment(label: labelOf(value), enabled: onChanged != null),
            ],
            selectedIndex: selectedIndex,
            onSegmentSelected: (index) => onChanged?.call(values[index]),
            height: height,
            padding: const EdgeInsets.all(4),
            borderRadius: height / 2,
            indicatorBorderRadius: (height - 8) / 2,
            backgroundColor: AppGlassStyle.tint(Theme.of(context).brightness),
            indicatorColor: colors.secondary.withValues(alpha: .70),
            indicatorExpansion: const EdgeInsets.all(3),
            selectedTextStyle: selectedStyle,
            unselectedTextStyle: normalStyle,
            useOwnLayer: true,
            quality: AppGlassStyle.quality,
            settings: AppGlassStyle.settings(Theme.of(context).brightness),
          )
        : SizedBox(
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(
                  navigation ? height / 2 : 12,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: AnimatedAlign(
                      alignment: AlignmentDirectional(
                        -1 + 2 * selectedIndex / (values.length - 1),
                        0,
                      ),
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      child: FractionallySizedBox(
                        widthFactor: 1 / values.length,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(
                              navigation ? (height - 8) / 2 : 8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final value in values)
                        Expanded(
                          child: Semantics(
                            selected: value == selected,
                            child: TextButton(
                              onPressed: onChanged == null
                                  ? null
                                  : () => onChanged!(value),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                labelOf(value),
                                style: value == selected
                                    ? selectedStyle
                                    : normalStyle,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
    // Also blocks drag selection: the package's drag handler ignores the
    // individual segment enabled flags. Keep disabled selection commit-owned.
    return ExcludeFocus(
      excluding: onChanged == null,
      child: IgnorePointer(
        ignoring: onChanged == null,
        child: Opacity(opacity: onChanged == null ? .5 : 1, child: control),
      ),
    );
  }
}

/// Flutter's switch is value-controlled; persistence remains with the caller.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Switch(value: value, onChanged: onChanged),
  );
}
