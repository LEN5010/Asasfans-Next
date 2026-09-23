import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../app/theme/app_tokens.dart';
import 'app_glass_scope.dart';
import 'app_glass_style.dart';

/// Material policy for the existing package controls. Each control owns its
/// surface; callers must not wrap it in another glass container.
class AppGlassButton extends StatelessWidget {
  const AppGlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.selected = false,
    this.radius = 100,
    this.tooltip,
    this.leading,
  }) : iconOnly = false;

  const AppGlassButton.icon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required this.tooltip,
    this.selected = false,
    this.radius = 100,
  }) : child = icon,
       leading = null,
       iconOnly = true;

  const AppGlassButton.withIcon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.selected = false,
    this.radius = 100,
    this.tooltip,
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

  @override
  Widget build(BuildContext context) {
    final policy = AppGlassScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onSecondaryContainer
        : colors.onSurface;
    final content = IconTheme.merge(
      data: IconThemeData(size: 22, color: foreground),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: foreground,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: iconOnly ? 10 : 16,
            vertical: 10,
          ),
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
      ),
    );
    final button = policy.usesLiquid
        ? GlassButton.custom(
            onTap: () => onPressed?.call(),
            enabled: onPressed != null,
            label: tooltip ?? '',
            useOwnLayer: true,
            quality: GlassQuality.standard,
            settings: AppGlassStyle.settings(Theme.of(context).brightness)
                .copyWith(
                  glassColor: selected
                      ? colors.secondary.withValues(alpha: .65)
                      : null,
                ),
            shape: LiquidRoundedRectangle(borderRadius: radius),
            stretch: policy.canAnimate ? .12 : 0,
            interactionScale: policy.canAnimate ? .96 : 1,
            anchorStretch: policy.canAnimate,
            persistPressOnDrag: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppTokens.controlHeight,
                minWidth: AppTokens.controlHeight,
              ),
              child: content,
            ),
          )
        : TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              minimumSize: const Size(
                AppTokens.controlHeight,
                AppTokens.controlHeight,
              ),
              padding: EdgeInsets.zero,
              foregroundColor: foreground,
              backgroundColor: selected
                  ? colors.secondaryContainer
                  : colors.surfaceContainerHigh,
              disabledForegroundColor: colors.onSurface.withValues(alpha: .38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Opacity(
              opacity: onPressed == null ? .45 : 1,
              child: content,
            ),
          );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Selection chips use the same material/press path as other controls.
class AppGlassChoice extends StatelessWidget {
  const AppGlassChoice({
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
    child: AppGlassButton(
      selected: selected,
      leading: avatar,
      onPressed: onSelected == null ? null : () => onSelected!(!selected),
      child: label,
    ),
  );
}

class AppGlassSegments<T> extends StatelessWidget {
  const AppGlassSegments({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });
  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T>? onChanged;

  static double heightFor(BuildContext context) => math.max(
    AppTokens.controlHeight,
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
        return AppGlassButton(
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
                            child: AppGlassButton(
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
    final height = heightFor(context);
    final selectedIndex = values.indexOf(selected);
    final selectedStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: colors.onSecondaryContainer,
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
    final control = policy.usesLiquid && policy.canAnimate
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
                borderRadius: BorderRadius.circular(height / 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Stack(
                  children: [
                    AnimatedAlign(
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
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(
                              (height - 8) / 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
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
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: const StadiumBorder(),
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

class AppGlassSwitch extends StatelessWidget {
  const AppGlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final policy = AppGlassScope.of(context);
    final enabled = onChanged != null;
    final control = policy.usesLiquid && policy.canAnimate
        ? TextButton(
            onPressed: enabled ? () => onChanged!(!value) : null,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(60, 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const StadiumBorder(),
            ),
            child: ExcludeFocus(
              child: IgnorePointer(
                child: GlassSwitch(
                  value: value,
                  onChanged: (_) {},
                  semanticLabel: label,
                  activeColor: colors.secondary,
                  inactiveColor: colors.surfaceContainerHighest,
                  height: 30,
                  width: 60,
                  useOwnLayer: true,
                  quality: GlassQuality.standard,
                  settings: AppGlassStyle.settings(
                    Theme.of(context).brightness,
                  ),
                  enableHaptics: false,
                ),
              ),
            ),
          )
        : TextButton(
            onPressed: enabled ? () => onChanged!(!value) : null,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(60, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const StadiumBorder(),
            ),
            child: AnimatedContainer(
              width: 60,
              height: 30,
              duration: policy.canAnimate
                  ? AppTokens.controlMotion
                  : Duration.zero,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value
                    ? colors.secondary
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(15),
              ),
              child: AnimatedAlign(
                alignment: value
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                duration: policy.canAnimate
                    ? AppTokens.controlMotion
                    : Duration.zero,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          );
    return Semantics(
      label: label,
      toggled: value,
      enabled: enabled,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: ExcludeSemantics(
        child: ExcludeFocus(
          excluding: !enabled,
          child: IgnorePointer(
            ignoring: !enabled,
            child: Opacity(
              opacity: enabled ? 1 : .5,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: enabled ? () => onChanged!(!value) : null,
                child: SizedBox(
                  width: 60,
                  height: 48,
                  child: Center(child: control),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
