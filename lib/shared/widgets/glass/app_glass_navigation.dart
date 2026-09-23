// Release-to-commit handling adapted from LoveIwara (MIT).
// See third_party/LoveIwara-LICENSE. Product routes and Tools remain our own.
import 'dart:async';

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../theme/app_icons.dart';
import 'app_glass_chrome.dart';
import 'app_glass_scope.dart';
import 'app_glass_style.dart';
import 'app_glass_surface.dart';

/// The library owns optical/jelly effects. We only translate completed gestures
/// into routes: the middle slot is an action, never a drag destination.
class AppGlassNavigation extends StatefulWidget {
  const AppGlassNavigation({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onTools,
    required this.toolsFocus,
    this.nativeContent = false,
  }) : assert(selected >= 0 && selected < 5 && selected != 2);

  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onTools;
  final FocusNode toolsFocus;
  final bool nativeContent;

  static double heightFor(TextScaler scaler) => 52 + scaler.scale(16);

  /// Shared with the desktop sidebar; index 2 is the Tools action.
  static const labels = ['今日', '内容', '工具', '日历', '我的'];
  static const icons = [
    AppIcons.today,
    AppIcons.content,
    AppIcons.tools,
    AppIcons.calendar,
    AppIcons.mine,
  ];
  static const activeIcons = [
    AppIcons.todaySelected,
    AppIcons.contentSelected,
    AppIcons.tools,
    AppIcons.calendarSelected,
    AppIcons.mineSelected,
  ];

  @override
  State<AppGlassNavigation> createState() => _AppGlassNavigationState();
}

class _AppGlassNavigationState extends State<AppGlassNavigation> {
  static const labels = AppGlassNavigation.labels;
  static const icons = AppGlassNavigation.icons;
  static const activeIcons = AppGlassNavigation.activeIcons;
  int? pointer;
  Offset down = Offset.zero;
  bool moved = false;
  bool cancelled = false;
  int? pending;
  bool pendingWhileDown = false;
  int? visual;
  bool scheduled = false;
  final routeFocus = List.generate(5, (_) => FocusNode());

  FocusNode _focus(int index) =>
      index == 2 ? widget.toolsFocus : routeFocus[index];

  @override
  void dispose() {
    for (final node in routeFocus) {
      node.dispose();
    }
    super.dispose();
  }

  void _activate(int index) {
    if (index == 2) {
      widget.onTools();
    } else {
      widget.onSelect(index);
    }
  }

  // The package assumes every slot is a persistent tab, and can suppress a
  // repeated activation of its internally selected slot. Own the semantics and
  // keyboard actions so Tools remains repeatable without becoming a route.
  Widget _accessibleSlot(int index) {
    final node = _focus(index);
    Widget target = Focus(
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
            border: node.hasFocus
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    target = index == 2
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: () => _activate(index),
            child: target,
          )
        : IgnorePointer(child: target);
    return Expanded(
      child: Semantics(
        label: labels[index],
        button: true,
        focusable: true,
        focused: node.hasFocus,
        selected: index == 2 ? null : widget.selected == index,
        onTap: () => _activate(index),
        child: target,
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
    // Tools never steals the selected route, even while the finger crosses it.
    setState(() => visual = index == 2 ? null : index);
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
      final wasMoved = moved;
      final wasCancelled = cancelled;
      pending = null;
      moved = cancelled = pendingWhileDown = false;
      setState(() => visual = null);
      if (wasCancelled || index == null || stalePress) return;
      if (index == 2) {
        if (!wasMoved) widget.onTools();
      } else if (index != widget.selected) {
        widget.onSelect(index);
      }
    });
  }

  Widget _label(int i, bool selected, double width) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(selected ? activeIcons[i] : icons[i], size: 24),
      const SizedBox(height: 2),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Text(
          labels[i],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AppGlassChrome(
    nativeContent: widget.nativeContent,
    builder: (context) => LayoutBuilder(
      builder: (context, constraints) {
        final policy = AppGlassScope.of(context);
        final colors = Theme.of(context).colorScheme;
        // Grow the bar for large type instead of clamping accessibility text.
        final height = AppGlassNavigation.heightFor(
          MediaQuery.textScalerOf(context),
        );
        final labelWidth = (constraints.maxWidth / 5 - 8).clamp(
          24.0,
          double.infinity,
        );
        if (!policy.usesLiquid || widget.nativeContent) {
          pointer = pending = visual = null;
          moved = cancelled = pendingWhileDown = false;
          return AppGlassSurface(
            nativeContent: widget.nativeContent,
            radius: height / 2,
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: i != 2 && widget.selected == i,
                        child: TextButton(
                          focusNode: _focus(i),
                          onPressed: () =>
                              i == 2 ? widget.onTools() : widget.onSelect(i),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: widget.selected == i
                                ? colors.primary
                                : AppGlassSurface.foregroundColor(
                                    colors.brightness,
                                  ),
                            minimumSize: Size(48, height),
                          ),
                          child: _label(i, widget.selected == i, labelWidth),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }
        return Stack(
          children: [
            ExcludeFocus(
              child: ExcludeSemantics(
                child: Listener(
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
                          activeIcon: _label(i, i != 2, labelWidth),
                        ),
                    ],
                    selectedIndex: visual ?? widget.selected,
                    onTabSelected: _select,
                    horizontalPadding: 0,
                    verticalPadding: 0,
                    barHeight: height,
                    barBorderRadius: height / 2,
                    settings: AppGlassStyle.settings(
                      colors.brightness,
                      shadow: true,
                    ),
                    quality: AppGlassStyle.quality,
                    selectedIconColor: colors.primary,
                    unselectedIconColor: colors.onSurfaceVariant,
                    indicatorColor: Colors.transparent,
                    maskingQuality: MaskingQuality.high,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++) _accessibleSlot(i),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
