import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Runs [onVisibleResume] when the app returns to the foreground, but only
/// while this page is the one on screen.
///
/// Shell branches stay mounted offstage, so `mounted` cannot tell a hidden
/// page from a visible one; the branch's TickerMode can. A resume that happens
/// while the page is hidden is remembered and runs once when it is shown, so
/// switching back to a stale page still refreshes it, without every hidden
/// branch refreshing on every resume.
mixin ResumeWhenVisible<T extends StatefulWidget> on State<T> {
  late final AppLifecycleListener _lifecycle;
  ValueListenable<TickerModeData>? _ticker;
  bool _resumedWhileHidden = false;

  /// Called on a foreground return while visible, or on becoming visible
  /// after a return that happened while hidden.
  void onVisibleResume();

  bool get pageVisible => _ticker?.value.enabled ?? true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _resumed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ticker = TickerMode.getValuesNotifier(context);
    if (identical(ticker, _ticker)) return;
    _ticker?.removeListener(_visibilityChanged);
    _ticker = ticker..addListener(_visibilityChanged);
  }

  void _resumed() {
    if (!mounted) return;
    if (pageVisible) {
      onVisibleResume();
    } else {
      _resumedWhileHidden = true;
    }
  }

  void _visibilityChanged() {
    if (!mounted || !pageVisible || !_resumedWhileHidden) return;
    _resumedWhileHidden = false;
    onVisibleResume();
  }

  @override
  void dispose() {
    _ticker?.removeListener(_visibilityChanged);
    _lifecycle.dispose();
    super.dispose();
  }
}
