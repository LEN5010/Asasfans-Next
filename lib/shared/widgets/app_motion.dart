import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import 'glass/app_glass_scope.dart';

/// A motion duration that becomes instant when the system disables animation.
Duration appMotion(BuildContext context, Duration duration) =>
    AppGlassScope.of(context).canAnimate ? duration : Duration.zero;

/// The app's three curves, after Material 3's: [standard] for things that
/// change in place, [enter] for things arriving (fast, then settling) and
/// [exit] for things leaving (accelerating away).
abstract final class AppCurves {
  static const standard = Cubic(.2, 0, 0, 1);
  static const enter = Cubic(.05, .7, .1, 1);
  static const exit = Cubic(.3, 0, .8, .15);
}

/// The branch [AsyncValue.when] shows: a refresh keeps its data phase, so
/// pulling to refresh does not fade the module out.
Object asyncPhase(AsyncValue<Object?> value) =>
    value.isLoading && !value.isRefreshing
    ? #loading
    : value.hasError
    ? #error
    : #data;

/// Cross-fades a module between its loading, error and loaded states.
class AppFadeSwitcher extends StatelessWidget {
  const AppFadeSwitcher({super.key, required this.phase, required this.child});
  final Object phase;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: appMotion(context, AppTokens.controlMotion),
    switchInCurve: AppCurves.standard,
    switchOutCurve: AppCurves.exit,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topCenter,
      children: [...previous, ?current],
    ),
    child: KeyedSubtree(key: ValueKey(phase), child: child),
  );
}

/// A block that arrives once: it fades in while rising [rise] px, [order]
/// steps after the first block of its page, so a page builds top to bottom
/// instead of appearing all at once. It plays when first mounted only;
/// rebuilds, refreshes and scrolling back never replay it. Instant when
/// animations are off.
class AppEntrance extends StatefulWidget {
  const AppEntrance({
    super.key,
    required this.child,
    this.order = 0,
    this.rise = 12,
  });
  final Widget child;
  final int order;
  final double rise;

  /// The pause between one block and the next.
  static const step = Duration(milliseconds: 60);

  @override
  State<AppEntrance> createState() => _AppEntranceState();
}

class _AppEntranceState extends State<AppEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late final CurvedAnimation _progress;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final delay = AppEntrance.step * widget.order;
    final total = delay + AppTokens.emphasisMotion;
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: AppCurves.enter,
      ),
    );
    if (!AppGlassScope.of(context).canAnimate) {
      _controller.value = 1;
      return;
    }
    _controller
      ..duration = total
      ..forward();
  }

  @override
  void dispose() {
    if (_started) _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  // The same two wrappers throughout, so finishing never remounts the child.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _progress.value,
      child: Transform.translate(
        offset: Offset(0, (1 - _progress.value) * widget.rise),
        child: child,
      ),
    ),
  );
}
