// Release-to-commit handling and the tab-bar-plus-action layout adapted from
// LoveIwara (MIT). See third_party/LoveIwara-LICENSE. Routes are our own.
import 'dart:async';

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../app/theme/app_theme.dart';
import '../../theme/app_icons.dart';
import 'app_glass_scope.dart';
import 'app_glass_style.dart';
import 'app_glass_surface.dart';

/// The four routes as one capsule, with Tools as a separate round action on
/// the same glass layer. Tools is never a tab, so the indicator cannot land
/// on it. Indices are shell branch indices.
class AppGlassNavigation extends StatefulWidget {
  const AppGlassNavigation({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onTools,
    this.nativeContent = false,
  }) : assert(selected >= 0 && selected < 4);

  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onTools;
  final bool nativeContent;

  /// 56 at 1x: a 48 tab (22 icon + 11 label) inside the 4 px indicator
  /// inset. Only the label line grows with the text scale.
  static double heightFor(TextScaler scaler) => 40 + scaler.scale(16);
  static const iconSize = 22.0;

  /// Shared with the desktop sidebar.
  static const labels = ['今日', '内容', '日历', '我的'];
  static const icons = [
    AppIcons.today,
    AppIcons.content,
    AppIcons.calendar,
    AppIcons.mine,
  ];
  static const activeIcons = [
    AppIcons.todaySelected,
    AppIcons.contentSelected,
    AppIcons.calendarSelected,
    AppIcons.mineSelected,
  ];
  static const toolsLabel = '工具';

  @override
  State<AppGlassNavigation> createState() => _AppGlassNavigationState();
}

class _AppGlassNavigationState extends State<AppGlassNavigation> {
  static const labels = AppGlassNavigation.labels;
  int? pointer;
  Offset down = Offset.zero;
  bool moved = false;
  bool cancelled = false;
  int? pending;
  bool pendingWhileDown = false;
  int? visual;
  bool scheduled = false;
  final focus = List.generate(5, (_) => FocusNode());

  @override
  void dispose() {
    for (final node in focus) {
      node.dispose();
    }
    super.dispose();
  }

  void _activate(int index) =>
      index == 4 ? widget.onTools() : widget.onSelect(index);

  // The package renders the tabs but offers no keyboard focus, so one
  // transparent slot per control owns focus, keys and semantics. The ring is
  // shown only while navigating by keyboard, never after a pointer tap.
  Widget _slot(int index) {
    final node = focus[index];
    final ring =
        node.hasFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Semantics(
      label: index == 4 ? AppGlassNavigation.toolsLabel : labels[index],
      button: true,
      focusable: true,
      focused: node.hasFocus,
      selected: index == 4 ? null : widget.selected == index,
      onTap: () => _activate(index),
      child: IgnorePointer(
        child: Focus(
          focusNode: node,
          includeSemantics: false,
          onFocusChange: (_) => setState(() {}),
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              _activate(index);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: ring
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(AppGlassNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) visual = null;
  }

  void _select(int index) {
    if (cancelled) return;
    pending = index;
    pendingWhileDown = pointer != null;
    setState(() => visual = index);
    if (pointer == null) _scheduleCommit();
  }

  void _scheduleCommit() {
    if (scheduled) return;
    scheduled = true;
    // Listener runs before the library's release recognizer. Let its final
    // selection replace a speculative tap-down before changing the route.
    scheduleMicrotask(() {
      scheduled = false;
      if (!mounted || pointer != null) return;
      final index = pending;
      final stalePress = moved && pendingWhileDown;
      final wasCancelled = cancelled;
      pending = null;
      moved = cancelled = pendingWhileDown = false;
      setState(() => visual = null);
      if (wasCancelled || index == null || stalePress) return;
      if (index != widget.selected) widget.onSelect(index);
    });
  }

  Widget _label(int i, bool selected, double width) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        selected
            ? AppGlassNavigation.activeIcons[i]
            : AppGlassNavigation.icons[i],
        size: AppGlassNavigation.iconSize,
      ),
      const SizedBox(height: 1.5),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Text(
          labels[i],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            height: 1.1,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Builder(
    builder: (context) => LayoutBuilder(
      builder: (context, constraints) {
        final policy = AppGlassScope.of(context);
        final colors = Theme.of(context).colorScheme;
        // Grow the bar for large type instead of clamping accessibility text.
        final height = AppGlassNavigation.heightFor(
          MediaQuery.textScalerOf(context),
        );
        final labelWidth = ((constraints.maxWidth - height - 12) / 4 - 8).clamp(
          24.0,
          double.infinity,
        );
        final Widget bar;
        if (!policy.usesLiquid || widget.nativeContent) {
          pointer = pending = visual = null;
          moved = cancelled = pendingWhileDown = false;
          bar = Row(
            children: [
              Expanded(
                child: AppGlassSurface(
                  nativeContent: widget.nativeContent,
                  radius: height / 2,
                  child: SizedBox(
                    height: height,
                    child: Row(
                      children: [
                        for (var i = 0; i < labels.length; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: TextButton(
                                onPressed: () => widget.onSelect(i),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: const StadiumBorder(),
                                  backgroundColor: widget.selected == i
                                      ? AppTheme.dianaPink
                                      : null,
                                  foregroundColor: widget.selected == i
                                      ? AppTheme.ink
                                      : AppGlassSurface.foregroundColor(
                                          colors.brightness,
                                        ),
                                  minimumSize: Size(48, height - 8),
                                ),
                                child: _label(
                                  i,
                                  widget.selected == i,
                                  labelWidth,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AppGlassSurface(
                nativeContent: widget.nativeContent,
                radius: height / 2,
                child: SizedBox.square(
                  dimension: height,
                  child: IconButton(
                    onPressed: widget.onTools,
                    icon: const Icon(
                      AppIcons.tools,
                      size: AppGlassNavigation.iconSize,
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          bar = Listener(
            onPointerDown: (event) {
              if (pointer != null) {
                cancelled = true;
                pending = null;
                return;
              }
              pointer = event.pointer;
              down = event.position;
              moved = cancelled = false;
            },
            onPointerMove: (event) {
              if (event.pointer == pointer &&
                  (event.position - down).distance > kTouchSlop) {
                moved = true;
              }
            },
            onPointerUp: (event) {
              if (event.pointer != pointer) return;
              pointer = null;
              _scheduleCommit();
            },
            onPointerCancel: (event) {
              if (event.pointer != pointer) return;
              pointer = null;
              cancelled = true;
              pending = null;
              _scheduleCommit();
            },
            child: GlassTabBar.bottom(
              tabs: [
                for (var i = 0; i < labels.length; i++)
                  GlassTab(
                    semanticLabel: labels[i],
                    icon: _label(i, false, labelWidth),
                    activeIcon: _label(i, true, labelWidth),
                  ),
              ],
              selectedIndex: visual ?? widget.selected,
              onTabSelected: _select,
              extraButton: GlassTabBarExtraButton(
                icon: const Icon(
                  AppIcons.tools,
                  size: AppGlassNavigation.iconSize,
                ),
                label: AppGlassNavigation.toolsLabel,
                onTap: widget.onTools,
                size: height,
                iconColor: colors.onSurface,
              ),
              spacing: 12,
              horizontalPadding: 0,
              verticalPadding: 0,
              barHeight: height,
              barBorderRadius: height / 2,
              settings: AppGlassStyle.settings(colors.brightness, shadow: true),
              quality: AppGlassStyle.quality,
              selectedIconColor: colors.primary,
              unselectedIconColor: colors.onSurfaceVariant,
              indicatorColor: AppTheme.dianaPink.withValues(alpha: .38),
              maskingQuality: MaskingQuality.high,
            ),
          );
        }
        return Stack(
          children: [
            ExcludeFocus(child: ExcludeSemantics(child: bar)),
            Positioned.fill(
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(child: _slot(i)),
                  const SizedBox(width: 12),
                  SizedBox(width: height, child: _slot(4)),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// The desktop navigation: a floating glass rail beside the content, the
/// vertical counterpart of the phone bar. Tools sits apart below the routes.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onTools,
  });
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onTools;

  static const width = 76.0;

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onPressed,
  }) {
    final foreground = AppGlassSurface.foregroundColor(
      Theme.of(context).brightness,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Semantics(
        selected: active,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 58),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: active ? AppTheme.dianaPink : null,
            foregroundColor: active ? AppTheme.ink : foreground,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppGlassSurface(
    radius: 30,
    child: SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/brand/asasfans_mark.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < AppGlassNavigation.labels.length; i++)
              _item(
                context,
                icon: selected == i
                    ? AppGlassNavigation.activeIcons[i]
                    : AppGlassNavigation.icons[i],
                label: AppGlassNavigation.labels[i],
                active: selected == i,
                onPressed: () => onSelect(i),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: 32,
                child: Divider(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            _item(
              context,
              icon: AppIcons.tools,
              label: AppGlassNavigation.toolsLabel,
              active: false,
              onPressed: onTools,
            ),
          ],
        ),
      ),
    ),
  );
}
